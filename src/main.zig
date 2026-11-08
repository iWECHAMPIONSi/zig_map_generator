const std = @import("std");
const Io = std.Io;
const root = @import("zig_map_generator");
const comptime_vals = root.comptime_vals;
const HeightMap = comptime_vals.HeightMap;
const HeightDict = comptime_vals.HeightDict;
const Tile = comptime_vals.Tile;
const TileHeight = comptime_vals.TileHeight;
const StdErr = root.StdErr;
const ArrayList = std.ArrayList;
const map_height: i32 = comptime_vals.map_height;
const map_width: i32 = comptime_vals.map_width;
const print = std.debug.print;
const assert = std.debug.assert;

const zig_map_generator = @import("zig_map_generator");
const iterations = 1000;

pub fn main(init: std.process.Init) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const io = init.io;

    const dir = Io.Dir.cwd();

    const file = try dir.createFile(io, "maps.json", .{});
    defer file.close(io);

    var file_writer = file.writer(io, &.{});
    const writer = &file_writer.interface;

    const allocator: std.mem.Allocator = arena.allocator();
    const seed: u64 = 0;

    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();
    try writer.print("{{\n", .{});

    var total: i96 = 0;
    var shortest_generation_time: i96 = 99999999999;
    var shortest_generation: usize = undefined;
    var longest_generation_time: i96 = -1;
    var longest_generation: usize = undefined;

    for (0..iterations) |m| {
        print("iteration {}\n", .{m});
        {
            const start = std.Io.Clock.now(.awake, io);
            defer {
                const end: i96 = start.durationTo(std.Io.Clock.now(.awake, io)).toNanoseconds();
                total += end;
                if (shortest_generation_time > end) {
                    shortest_generation = m;
                    shortest_generation_time = end;
                }

                if (longest_generation_time < end) {
                    longest_generation = m;
                    longest_generation_time = end;
                }
            }

            defer _ = arena.reset(.retain_capacity);

            var map1: HeightMap = HeightMap.init();
            var map2: HeightMap = HeightMap.init();
            var dict1: HeightDict = try HeightDict.init(allocator, &map2.map);
            defer dict1.deinit(allocator);
            var dict2: HeightDict = try HeightDict.init(allocator, &map1.map);
            defer dict2.deinit(allocator);

            defer {
                comptime_vals.change_list.deinit(allocator);
                comptime_vals.sync_list.deinit(allocator);
                comptime_vals.change_list = .empty;
                comptime_vals.sync_list = .empty;
            }

            map_a_ptr = &map1;
            dict_a_ptr = &dict1;
            map_b_ptr = &map2;
            dict_b_ptr = &dict2;
            try root.generateHeightMap(allocator, rand, &map_a_ptr, &map_b_ptr, &dict_a_ptr, &dict_b_ptr);
        }

        try writer.print("    \"height_map{}\": [\n", .{m});
        for (0..map_height) |h| {
            const i: i32 = @intCast(h);
            try writer.print("        [", .{});
            for (0..map_width) |w| {
                const o: i32 = @intCast(w);
                const tile: *Tile = map_a_ptr.get(i, o);
                if (@backingInt(tile.val) >= 0) {
                    try writer.print(" ", .{});
                }
                try writer.print("{}", .{@backingInt(tile.val)});
                if (o < map_width - 1) {
                    try writer.print(",", .{});
                }
            }
            try writer.print("]", .{});
            if (i < map_height - 1) {
                try writer.print(",", .{});
            }
            try writer.print("\n", .{});
        }
        try writer.print("    ]", .{});
        if (m < iterations - 1) {
            try writer.print(",", .{});
        }
        try writer.print("\n", .{});
    }
    try writer.print("}}\n", .{});
    const end = total;
    print(
        "map: {}x{} ({} tiles)\ntotal time: {}s\naverage per gen: {}s\nshortest iteration: {}\n    {}s\nlongest iteration: {}\n    {}s\n",
        .{
            comptime_vals.map_width,
            comptime_vals.map_height,
            comptime_vals.map_width * comptime_vals.map_height,
            @as(f128, end) / 1e9,
            @as(f128, end) / 1e9 / @as(f128, iterations),
            shortest_generation,
            @as(f128, shortest_generation_time) / 1e9,
            longest_generation,
            @as(f128, longest_generation_time) / 1e9,
        },
    );
}
var map_a_ptr: *HeightMap = undefined;
var dict_a_ptr: *HeightDict = undefined;
var map_b_ptr: *HeightMap = undefined;
var dict_b_ptr: *HeightDict = undefined;

// fn printCoords(func: []const u8, i: i32, o: i32) void {
// print("[{s}] i: {}, o: {}\n", .{ func, i, o });
// }

// fn printTile(map_ptr: *HeightMap, i: i32, o: i32) void {
// if (map_ptr == map_a_ptr) {
// print("map_a_ptr [0x{x}]: i = {}, o = {}\n", .{ @intFromPtr(map_ptr), i, o });
// } else {
// print("map_b_ptr [0x{x}]: i = {}, o = {}\n", .{ @intFromPtr(map_ptr), i, o });
// }
// const tile: *Tile = map_ptr.get(i, o);
// print("    tile [0x{x}]: ", .{@intFromPtr(tile)});
// print(".i = {}, ", .{tile.i});
// print(".o = {}, ", .{tile.o});
// print(".val = .{s}\n", .{@tagName(tile.val)});
// }
