const std = @import("std");
const Io = std.Io;
const comptime_vals = @import("comptime_vals.zig");
const HeightMap = comptime_vals.HeightMap;
const HeightDict = comptime_vals.HeightDict;
const Tile = comptime_vals.Tile;
const TileHeight = comptime_vals.TileHeight;
const StdErr = @import("std_err.zig").StdErr;
const ArrayList = std.ArrayList;
const map_height: i32 = comptime_vals.map_height;
const map_width: i32 = comptime_vals.map_width;

const zig_map_generator = @import("zig_map_generator");

pub fn main(init: std.process.Init) !void {
    var safe: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});
    const allocator: std.mem.Allocator = safe.allocator();
    defer std.debug.assert(safe.deinit() == 0);
    var set = std.AutoHashMap(i32, void).init(allocator);
    var map1: HeightMap = HeightMap.init();
    var map2: HeightMap = HeightMap.init();
    var dict1: HeightDict = try HeightDict.init(allocator, &map2.map);
    defer dict1.deinit(allocator);
    var dict2: HeightDict = try HeightDict.init(allocator, &map1.map);
    defer dict2.deinit(allocator);
    var delta_tiles: ArrayList(*Tile) = .empty;
    var selection: comptime_vals.MapSection = undefined;
    defer {
        set.deinit();
        comptime_vals.change_list.deinit(allocator);
        comptime_vals.sync_list.deinit(allocator);
    }
    map_a_ptr = &map1;
    dict_a_ptr = &dict1;
    map_b_ptr = &map2;
    dict_b_ptr = &dict2;
    _ = init;
    const seed: u64 = 0;
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    for (0..comptime_vals.mountain_seeds) |_| {
        const i: i32 = rand.intRangeLessThan(i32, 1, map_height - 1);
        const o: i32 = rand.intRangeLessThan(i32, 1, map_width - 1);
        selection = map_b_ptr.getSection(i, o);
        delta_tiles = try selection.deltaTiles(allocator, comptime_vals.TileHeight.eq, .base);
        try checkDeltaArray(allocator, &delta_tiles, &set);
        try dict_a_ptr.swap(allocator, map_b_ptr.get(i, o), .mountain);
        try HeightMap.changeDeltaTiles(allocator, i, o, &delta_tiles, .mountain, dict_a_ptr, map_b_ptr);
    }
}

var map_a_ptr: *HeightMap = undefined;
var dict_a_ptr: *HeightDict = undefined;
var map_b_ptr: *HeightMap = undefined;
var dict_b_ptr: *HeightDict = undefined;

fn swapPtr(allocator: std.mem.Allocator, set: *std.AutoHashMap(i32, void)) StdErr!void {
    set.clearRetainingCapacity();
    const tmp_map: *HeightMap = map_a_ptr;
    const tmp_dict: *HeightDict = dict_a_ptr;
    map_a_ptr = map_b_ptr;
    dict_a_ptr = dict_b_ptr;
    map_b_ptr = tmp_map;
    dict_b_ptr = tmp_dict;
    for (comptime_vals.sync_list.items) |tile| {
        try dict_a_ptr.swap(allocator, map_b_ptr.get(tile.i, tile.o), tile.val);
    }
    comptime_vals.change_list.appendSlice(allocator, comptime_vals.sync_list.items) catch {
        return StdErr.MemoryAllocation;
    };
    comptime_vals.sync_list.clearRetainingCapacity();
}

fn checkDeltaTile(allocator: std.mem.Allocator, delta_tile: *Tile, set: *std.AutoHashMap(i32, void)) StdErr!*Tile {
    if (set.contains(delta_tile.o + delta_tile.i * comptime_vals.map_width)) {
        try swapPtr(allocator, set);
        return map_b_ptr.get(delta_tile.i, delta_tile.o);
    }
    set.put(delta_tile.o + delta_tile.i * comptime_vals.map_width, .{}) catch {
        return StdErr.MemoryAllocation;
    };
    return delta_tile;
}

fn checkDeltaArray(allocator: std.mem.Allocator, delta_tiles: *ArrayList(*Tile), set: *std.AutoHashMap(i32, void)) StdErr!void {
    for (delta_tiles.*.items) |tile| {
        if (set.contains(tile.o + tile.i * comptime_vals.map_width)) {
            try swapPtr(allocator, set);
            for (0..delta_tiles.items.len, delta_tiles.items) |index, t| {
                set.put(t.o + t.i * comptime_vals.map_width, undefined) catch {
                    return StdErr.MemoryAllocation;
                };
                delta_tiles.items[index] = map_b_ptr.get(t.i, t.o);
            }
            break;
        }
        set.put(tile.o + tile.i * comptime_vals.map_width, undefined) catch {
            return StdErr.MemoryAllocation;
        };
    }
}
