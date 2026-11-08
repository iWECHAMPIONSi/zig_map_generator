const std = @import("std");
const Io = std.Io;
pub const comptime_vals = @import("comptime_vals.zig");
const HeightMap = comptime_vals.HeightMap;
const HeightDict = comptime_vals.HeightDict;
const Tile = comptime_vals.Tile;
const TileHeight = comptime_vals.TileHeight;
pub const StdErr = @import("std_err.zig").StdErr;
const ArrayList = std.ArrayList;
const map_height: i32 = comptime_vals.map_height;
const map_width: i32 = comptime_vals.map_width;
const print = std.debug.print;
const assert = std.debug.assert;

var map_a_ptr: *HeightMap = undefined;
var map_b_ptr: *HeightMap = undefined;
var dict_a_ptr: *HeightDict = undefined;
var dict_b_ptr: *HeightDict = undefined;
pub fn generateHeightMap(
    allocator: std.mem.Allocator,
    rand: std.Random,
    map_a: **HeightMap,
    map_b: **HeightMap,
    dict_a: **HeightDict,
    dict_b: **HeightDict,
) StdErr!void {
    map_a_ptr = map_a.*;
    map_b_ptr = map_b.*;
    dict_a_ptr = dict_a.*;
    dict_b_ptr = dict_b.*;
    var delta_tiles: ArrayList(*Tile) = .empty;
    defer {
        map_a.* = map_a_ptr;
        map_b.* = map_b_ptr;
        dict_a.* = dict_a_ptr;
        dict_b.* = dict_b_ptr;
        map_a_ptr = undefined;
        map_b_ptr = undefined;
        dict_a_ptr = undefined;
        dict_b_ptr = undefined;
        delta_tiles.deinit(allocator);
    }

    // place 3x3 .mountain [mountain_seeds] at random points on the heightmap
    var selection: comptime_vals.MapSection = undefined;
    for (0..comptime_vals.mountain_seeds) |_| {
        const i: i32 = rand.intRangeLessThan(i32, 1, map_height - 1);
        const o: i32 = rand.intRangeLessThan(i32, 1, map_width - 1);

        // printCoords("main", i, o);

        selection = map_a_ptr.getSection(i, o);
        try selection.deltaTiles(allocator, comptime_vals.TileHeight.eq, .base, &delta_tiles);
        if (map_b_ptr.get(i, o).val != .mountain) {
            try dict_a_ptr.swap(allocator, map_b_ptr.get(i, o), .mountain);
        }
        _ = try HeightMap.changeDeltaTiles(allocator, &delta_tiles, .mountain, dict_a_ptr, map_b_ptr);
        try swapPtr(allocator);
    }
    try swapPtr(allocator);

    // Expand hills
    var change: bool = undefined;
    var base_targets: ArrayList(*Tile) = .empty;
    defer base_targets.deinit(allocator);

    {
        var max_height: TileHeight = .mountain;
        while (TileHeight.gt(max_height, .incline)) : (max_height = TileHeight.lowerHeight(max_height)) {
            change = true;
            while (change) {
                change = false;

                var mountain_first_iter = dict_b_ptr.getList(max_height);
                while (mountain_first_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                    for (delta_tiles.items) |base_tile| {
                        try exclusiveAppend(allocator, &base_targets, base_tile);
                    }
                    delta_tiles.clearRetainingCapacity();
                }

                var new_val: TileHeight = undefined;
                for (base_targets.items) |tile| {
                    new_val = TileHeight.randHeights(rand, TileHeight.lowerHeight(max_height), max_height, -1, 5);
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, max_height, &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 3, new_val, dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
                try swapPtr(allocator);
                base_targets.clearRetainingCapacity();
            }

            change = true;

            while (change) {
                change = false;

                var mountain_second_iter = dict_b_ptr.getList(max_height);
                while (mountain_second_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                    for (delta_tiles.items) |base_tile| {
                        try exclusiveAppend(allocator, &base_targets, base_tile);
                    }
                    delta_tiles.clearRetainingCapacity();
                }

                var new_val: TileHeight = undefined;
                for (base_targets.items) |tile| {
                    new_val = TileHeight.randHeights(rand, TileHeight.lowerHeight(max_height), max_height, -2, null);
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, max_height, &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 2, new_val, dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
                try swapPtr(allocator);
                base_targets.clearRetainingCapacity();
            }

            var mountain_lower_iter = dict_b_ptr.getList(max_height);
            while (mountain_lower_iter.next()) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                for (delta_tiles.items) |base_tile| {
                    try exclusiveAppend(allocator, &base_targets, base_tile);
                }
                delta_tiles.clearRetainingCapacity();
            }

            for (base_targets.items) |tile| {
                try dict_a_ptr.swap(allocator, map_b_ptr.get(tile.i, tile.o), TileHeight.lowerHeight(max_height));
            }
            base_targets.clearRetainingCapacity();
            try swapPtr(allocator);
        }

        for (0..2) |_| {
            var incline_iter = dict_b_ptr.getList(.incline);
            while (incline_iter.next()) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                for (delta_tiles.items) |base_tile| {
                    try exclusiveAppend(allocator, &base_targets, base_tile);
                }
                delta_tiles.clearRetainingCapacity();
            }

            for (base_targets.items) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.eq, .incline, &delta_tiles);
                _ = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 4, .incline, dict_a_ptr, map_b_ptr);
            }
            base_targets.clearRetainingCapacity();
            try swapPtr(allocator);
        }
    }

    // smoothing terrain

    change = true;
    {
        var height: TileHeight = .base;
        while (change) {
            change = false;
            while (TileHeight.lt(height, .mountain)) : (height = TileHeight.raiseHeight(height)) {
                var up_smoothing_iter = dict_b_ptr.getList(height);
                while (up_smoothing_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, TileHeight.raiseHeight(height), &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, rand.uintAtMost(usize, 1) + 5, TileHeight.raiseHeight(height), dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
                try swapPtr(allocator);
            }

            height = .mountain;

            while (TileHeight.gt(height, .base)) : (height = TileHeight.lowerHeight(height)) {
                var down_smoothing_iter = dict_b_ptr.getList(height);
                while (down_smoothing_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, TileHeight.lowerHeight(height), &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, rand.uintAtMost(usize, 1) + 5, TileHeight.lowerHeight(height), dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
                try swapPtr(allocator);
            }
        }
    }

    // adding river

    for (0..((map_width + 36) / 72)) |_| {
        var direction: i8 = undefined;
        var river_height: i32 = rand.intRangeAtMost(i32, 5, map_height - 5);

        for (0..map_width) |progress| {
            var tile: *Tile = map_b_ptr.get(@intCast(progress), river_height);
            _ = &tile;
            direction = blk: {
                var dir: i8 = undefined;
                if (river_height >= map_height - 3) {
                    dir = rand.intRangeAtMost(i8, -1, 0);
                } else if (river_height <= 3) {
                    dir = rand.intRangeAtMost(i8, 0, 1);
                } else {
                    dir = rand.intRangeAtMost(i8, -1, 1);
                }

                break :blk dir;
            };
            river_height += direction;
            if (tile.val == .deep_water) continue;
            try dict_a_ptr.swap(allocator, tile, .deep_water);
        }

        try swapPtr(allocator);

        // assert(dict_a_ptr.deep_valley.items.len == 0);
        // assert(dict_a_ptr.shallow_valley.items.len == 0);
        // assert(dict_a_ptr.decline.items.len == 0);

        change = true;
        while (change) {
            change = false;

            var deep_water_iter = dict_b_ptr.getList(.deep_water);
            while (deep_water_iter.next()) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.gte, .base, &delta_tiles);
                const change_occured: bool = try HeightMap.changeDeltaTiles(allocator, &delta_tiles, .shallow_water, dict_a_ptr, map_b_ptr);
                change = change or change_occured;
            }

            try swapPtr(allocator);

            var base_water_iter = dict_b_ptr.getList(.base);
            while (base_water_iter.next()) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.eq, .shallow_water, &delta_tiles);
                const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 5, .shallow_water, dict_a_ptr, map_b_ptr);
                change = change or change_occured;
            }

            try swapPtr(allocator);

            var shallow_water_iter = dict_b_ptr.getList(.shallow_water);
            while (shallow_water_iter.next()) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.gte, .base, &delta_tiles);
                const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.eq, 0, .deep_water, dict_a_ptr, map_b_ptr);
                change = change or change_occured;
            }

            try swapPtr(allocator);
        }
    }

    // adding valleys

    for (0..comptime_vals.mountain_seeds) |_| {
        var longest_distance: i32 = -1;
        var delta_distance: i32 = undefined;
        var target_tile: *Tile = undefined;
        var i: i32 = undefined;
        var o: i32 = undefined;
        var delta_pos_i: i32 = undefined;
        var delta_pos_o: i32 = undefined;
        var delta_neg_i: i32 = undefined;
        var delta_neg_o: i32 = undefined;

        var base_valley_iter = dict_a_ptr.getList(.base);
        while (base_valley_iter.next()) |tile| {
            delta_distance = 1;
            i = tile.i;
            o = tile.o;
            const clamp = std.math.clamp;

            while (i + delta_distance < map_height + 10 and i - delta_distance > -10 and o + delta_distance < map_width + 10 and o - delta_distance > -10) : (delta_distance += 1) {
                delta_pos_i = clamp(i + delta_distance, i, map_height - 1);
                delta_pos_o = clamp(o + delta_distance, o, map_width - 1);
                delta_neg_i = clamp(i - delta_distance, 0, i);
                delta_neg_o = clamp(o - delta_distance, 0, o);

                if (map_b_ptr.get(delta_pos_i, delta_pos_o).val != .base) break;
                if (map_b_ptr.get(delta_neg_i, delta_pos_o).val != .base) break;
                if (map_b_ptr.get(delta_pos_i, delta_neg_o).val != .base) break;
                if (map_b_ptr.get(delta_neg_i, delta_neg_o).val != .base) break;

                if (map_b_ptr.get(delta_pos_i, o).val != .base) break;
                if (map_b_ptr.get(delta_neg_i, o).val != .base) break;
                if (map_b_ptr.get(i, delta_pos_o).val != .base) break;
                if (map_b_ptr.get(i, delta_neg_o).val != .base) break;
            }

            if (delta_distance >= longest_distance) {
                target_tile = tile;
                longest_distance = delta_distance;
            }
        }

        // assert(dict_a_ptr.base.items.len > 0);

        selection = map_a_ptr.getSection(target_tile.i, target_tile.o);
        try selection.deltaTiles(allocator, comptime_vals.TileHeight.neq, .deep_valley, &delta_tiles);
        try dict_a_ptr.swap(allocator, map_b_ptr.get(target_tile.i, target_tile.o), .deep_valley);
        _ = try HeightMap.changeDeltaTiles(allocator, &delta_tiles, .deep_valley, dict_a_ptr, map_b_ptr);
        try swapPtr(allocator);
        var min_height: TileHeight = .deep_valley;

        while (TileHeight.lt(min_height, .decline)) : (min_height = TileHeight.raiseHeight(min_height)) {
            change = true;
            while (change) {
                change = false;

                var valley_first_iter = dict_b_ptr.getList(min_height);
                while (valley_first_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                    for (delta_tiles.items) |base_tile| {
                        try exclusiveAppend(allocator, &base_targets, base_tile);
                    }
                    delta_tiles.clearRetainingCapacity();
                }

                var new_val: TileHeight = undefined;
                for (base_targets.items) |tile| {
                    new_val = TileHeight.randHeights(rand, min_height, TileHeight.raiseHeight(min_height), -6, 1);
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, min_height, &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 3, new_val, dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
                try swapPtr(allocator);
                base_targets.clearRetainingCapacity();
            }

            change = true;

            while (change) {
                change = false;

                var valley_second_iter = dict_b_ptr.getList(min_height);
                while (valley_second_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                    for (delta_tiles.items) |base_tile| {
                        try exclusiveAppend(allocator, &base_targets, base_tile);
                    }
                    delta_tiles.clearRetainingCapacity();
                }

                var new_val: TileHeight = undefined;
                for (base_targets.items) |tile| {
                    new_val = TileHeight.randHeights(rand, min_height, TileHeight.raiseHeight(min_height), null, 2);
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, min_height, &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 2, new_val, dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
                try swapPtr(allocator);
                base_targets.clearRetainingCapacity();
            }

            var valley_raise_iter = dict_b_ptr.getList(min_height);
            while (valley_raise_iter.next()) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                for (delta_tiles.items) |base_tile| {
                    try exclusiveAppend(allocator, &base_targets, base_tile);
                }
                delta_tiles.clearRetainingCapacity();
            }

            for (base_targets.items) |tile| {
                try dict_a_ptr.swap(allocator, map_b_ptr.get(tile.i, tile.o), TileHeight.raiseHeight(min_height));
            }
            base_targets.clearRetainingCapacity();
            try swapPtr(allocator);
        }

        for (0..2) |_| {
            var decline_iter = dict_b_ptr.getList(.decline);
            while (decline_iter.next()) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.eq, .base, &delta_tiles);
                for (delta_tiles.items) |base_tile| {
                    try exclusiveAppend(allocator, &base_targets, base_tile);
                }
                delta_tiles.clearRetainingCapacity();
            }

            for (base_targets.items) |tile| {
                selection = map_a_ptr.getSection(tile.i, tile.o);
                try selection.deltaTiles(allocator, TileHeight.eq, .decline, &delta_tiles);
                _ = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 3, TileHeight.randHeights(rand, .decline, .base, null, null), dict_a_ptr, map_b_ptr);
            }
            base_targets.clearRetainingCapacity();
            try swapPtr(allocator);
        }
    }

    {
        var west_tile: *Tile = undefined;
        var east_tile: *Tile = undefined;
        for (1..(map_height - 1)) |index| {
            const i: i32 = @intCast(index);
            west_tile = map_a_ptr.get(i, 0);
            east_tile = map_a_ptr.get(i, map_width - 1);

            if (TileHeight.gt(west_tile.val, .shallow_water)) {
                const top: *Tile = map_a_ptr.get(i - 1, 1);
                const middle: *Tile = map_a_ptr.get(i, 1);
                const bottom: *Tile = map_a_ptr.get(i + 1, 1);
                if (west_tile.val != top.val and west_tile.val != bottom.val and west_tile.val != middle.val) {
                    try dict_a_ptr.swap(allocator, map_b_ptr.get(west_tile.i, west_tile.o), middle.val);
                }
            }
            if (TileHeight.gt(east_tile.val, .shallow_water)) {
                const top: *Tile = map_a_ptr.get(i - 1, map_width - 2);
                const middle: *Tile = map_a_ptr.get(i, map_width - 2);
                const bottom: *Tile = map_a_ptr.get(i + 1, map_width - 2);
                if (east_tile.val != top.val and east_tile.val != bottom.val and east_tile.val != middle.val) {
                    try dict_a_ptr.swap(allocator, map_b_ptr.get(east_tile.i, east_tile.o), middle.val);
                }
            }
        }
    }

    {
        var north_tile: *Tile = undefined;
        var south_tile: *Tile = undefined;
        for (1..(map_width - 1)) |index| {
            const o: i32 = @intCast(index);
            north_tile = map_a_ptr.get(0, o);
            south_tile = map_a_ptr.get(map_height - 1, o);

            if (TileHeight.gt(north_tile.val, .shallow_water)) {
                const top: *Tile = map_a_ptr.get(1, o - 1);
                const middle: *Tile = map_a_ptr.get(1, o);
                const bottom: *Tile = map_a_ptr.get(1, o + 1);
                if (north_tile.val != top.val and north_tile.val != bottom.val and north_tile.val != middle.val) {
                    try dict_a_ptr.swap(allocator, map_b_ptr.get(north_tile.i, north_tile.o), middle.val);
                }
            }
            if (TileHeight.gt(south_tile.val, .shallow_water)) {
                const top: *Tile = map_a_ptr.get(map_height - 2, o - 1);
                const middle: *Tile = map_a_ptr.get(map_height - 2, o);
                const bottom: *Tile = map_a_ptr.get(map_height - 2, o + 1);
                if (south_tile.val != top.val and south_tile.val != bottom.val and south_tile.val != middle.val) {
                    try dict_a_ptr.swap(allocator, map_b_ptr.get(south_tile.i, south_tile.o), middle.val);
                }
            }
        }
    }

    try swapPtr(allocator);

    var base_shore_iter = dict_b_ptr.getList(.base);
    while (base_shore_iter.next()) |tile| {
        selection = map_a_ptr.getSection(tile.i, tile.o);
        try selection.deltaTiles(allocator, TileHeight.eq, .shallow_water, &delta_tiles);
        _ = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 5, .shallow_water, dict_a_ptr, map_b_ptr);
    }

    try swapPtr(allocator);

    {
        change = true;
        var height: TileHeight = .base;
        while (change) {
            change = false;
            while (TileHeight.gt(height, .deep_valley)) : (height = TileHeight.lowerHeight(height)) {
                var down_valley_smooth_iter = dict_b_ptr.getList(height);
                while (down_valley_smooth_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, TileHeight.lowerHeight(height), &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, rand.uintAtMost(usize, 1) + 5, TileHeight.lowerHeight(height), dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
            }

            try swapPtr(allocator);

            height = .deep_valley;
            while (TileHeight.lt(height, .base)) : (height = TileHeight.raiseHeight(height)) {
                var up_valley_smooth_iter = dict_b_ptr.getList(height);
                while (up_valley_smooth_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.eq, TileHeight.raiseHeight(height), &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, rand.uintAtMost(usize, 1) + 5, TileHeight.raiseHeight(height), dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
            }

            try swapPtr(allocator);
        }
    }

    try swapPtr(allocator);

    var shore_water_iter = dict_b_ptr.getList(.shallow_water);
    while (shore_water_iter.next()) |tile| {
        selection = map_a_ptr.getSection(tile.i, tile.o);
        try selection.deltaTiles(allocator, TileHeight.gt, .shallow_water, &delta_tiles);
        _ = try HeightMap.changeDeltaTiles(allocator, &delta_tiles, .base, dict_a_ptr, map_b_ptr);
    }

    try swapPtr(allocator);

    {
        change = true;
        var height: TileHeight = undefined;
        while (change) {
            change = false;
            height = .mountain;
            while (TileHeight.gt(height, .base)) : (height = TileHeight.lowerHeight(height)) {
                var peak_slope_iter = dict_b_ptr.getList(height);
                while (peak_slope_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.lte, TileHeight.lowerHeight(TileHeight.lowerHeight(height)), &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 1, TileHeight.lowerHeight(height), dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
            }

            height = .deep_valley;

            while (TileHeight.lt(height, .base)) : (height = TileHeight.raiseHeight(height)) {
                var valley_slope_iter = dict_b_ptr.getList(height);
                while (valley_slope_iter.next()) |tile| {
                    selection = map_a_ptr.getSection(tile.i, tile.o);
                    try selection.deltaTiles(allocator, TileHeight.gte, TileHeight.raiseHeight(TileHeight.raiseHeight(height)), &delta_tiles);
                    const change_occured: bool = try HeightMap.changeTile(allocator, tile.i, tile.o, &delta_tiles, comptime_vals.gte, 1, TileHeight.raiseHeight(height), dict_a_ptr, map_b_ptr);
                    change = change or change_occured;
                }
            }

            try swapPtr(allocator);
        }
    }

    for (0..map_height) |height_index| {
        const i: i32 = @intCast(height_index);
        for (0..map_width) |width_index| {
            const o: i32 = @intCast(width_index);
            const tile: *Tile = map_a_ptr.get(i, o);
            if (TileHeight.lt(tile.val, .deep_valley)) continue;
            selection = map_a_ptr.getSection(i, o);
            try selection.deltaTiles(allocator, TileHeight.eq, tile.val, &delta_tiles);
            if (delta_tiles.items.len == 0) {
                delta_tiles.clearRetainingCapacity();
                try selection.deltaTiles(allocator, TileHeight.neq, tile.val, &delta_tiles);
                assert(delta_tiles.items.len > 0);
                const new_val: TileHeight = blk: {
                    var total: i8 = 0;
                    for (delta_tiles.items) |t| {
                        total += @backingInt(t.val);
                    }
                    break :blk @fromBackingInt(@divTrunc(total, @as(i8, @intCast(delta_tiles.items.len))));
                };
                if (tile.val != new_val) {
                    try dict_a_ptr.swap(allocator, map_b_ptr.get(i, o), new_val);
                }
            }

            delta_tiles.clearRetainingCapacity();
        }
    }

    try swapPtr(allocator);

    {
        for (0..2) |height_index| {
            const i: i32 = if (height_index == 0) 0 else map_height - 1;
            const inner_i: i32 = if (height_index == 0) 1 else map_height - 2;
            for (0..2) |width_index| {
                const o: i32 = if (width_index == 0) 0 else map_width - 1;
                const inner_o: i32 = if (width_index == 0) 1 else map_width - 2;
                const tile: *Tile = map_a_ptr.get(i, o);
                selection = map_a_ptr.getSection(i, o);
                try selection.deltaTiles(allocator, TileHeight.eq, tile.val, &delta_tiles);
                if (delta_tiles.items.len == 0) {
                    try dict_a_ptr.swap(allocator, map_b_ptr.get(i, o), map_a_ptr.get(inner_i, inner_o).val);
                }
                delta_tiles.clearRetainingCapacity();
            }
        }
    }
    try swapPtr(allocator);
}

fn exclusiveAppend(allocator: std.mem.Allocator, arr: *ArrayList(*Tile), tile: *Tile) StdErr!void {
    for (arr.*.items) |t| {
        if (t == tile) {
            return;
        }
    }
    arr.append(allocator, tile) catch {
        return StdErr.MemoryAllocation;
    };
}

fn swapPtr(allocator: std.mem.Allocator) StdErr!void {
    const tmp_map: *HeightMap = map_a_ptr;
    const tmp_dict: *HeightDict = dict_a_ptr;
    map_a_ptr = map_b_ptr;
    dict_a_ptr = dict_b_ptr;
    map_b_ptr = tmp_map;
    dict_b_ptr = tmp_dict;
    for (comptime_vals.sync_list.items) |tile| {
        // printTile(map_a_ptr, tile.i, tile.o);
        // printTile(map_b_ptr, tile.i, tile.o);
        try dict_a_ptr.syncSwap(map_b_ptr.get(tile.i, tile.o), tile.val);
    }
    comptime_vals.change_list.appendSlice(allocator, comptime_vals.sync_list.items) catch {
        return StdErr.MemoryAllocation;
    };
    comptime_vals.sync_list.clearRetainingCapacity();
}
