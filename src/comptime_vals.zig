const std = @import("std");
const Random = std.Random;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const StdErr = @import("std_err.zig").StdErr;

pub var change_list: ArrayList(Tile) = ArrayList(Tile).empty;
pub var sync_list: ArrayList(Tile) = ArrayList(Tile).empty;

pub const screen_width: i32 = 1100;
pub const screen_height: i32 = 700;

pub const map_width: i32 = 64;
pub const map_height: i32 = 64;

pub const mountain_seeds: i32 = map_width / 24;

pub const TileHeight: type = enum(i8) {
    nil = -128,
    deep_water = -5,
    shallow_water = -4,

    deep_valley = -3,
    shallow_valley = -2,
    decline = -1,
    base = 0,
    incline = 1,
    low_hill = 2,
    tall_hill = 3,
    mountain = 4,

    pub fn randHeights(rand: Random, lowest: TileHeight, highest: TileHeight, low_bias: ?i8, high_bias: ?i8) TileHeight {
        assert(@backingInt(lowest) >= @backingInt(TileHeight.deep_valley));
        assert(@backingInt(lowest) <= @backingInt(highest));
        const low: i8 = blk: {
            var tmp: i8 = @backingInt(lowest);
            if (low_bias) |b| {
                assert(b <= 0);
                assert(b >= -128 - @backingInt(TileHeight.deep_valley));
                assert(@backingInt(lowest) == @backingInt(highest) - 1);

                tmp += b;
            }

            break :blk tmp;
        };
        const high: i8 = blk: {
            var tmp: i8 = @backingInt(highest);
            if (high_bias) |b| {
                assert(b >= 0);
                assert(b <= 127 - @backingInt(TileHeight.mountain));
                assert(@backingInt(lowest) == @backingInt(highest) - 1);
                tmp += b;
            }

            break :blk tmp;
        };
        return @fromBackingInt(std.math.clamp(rand.intRangeAtMost(i8, low, high), @backingInt(lowest), @backingInt(highest)));
    }

    pub fn eq(a: TileHeight, b: TileHeight) bool {
        assert(a != .nil);
        assert(b != .nil);
        return @backingInt(a) == @backingInt(b);
    }

    pub fn lt(a: TileHeight, b: TileHeight) bool {
        assert(a != .nil);
        assert(b != .nil);
        return @backingInt(a) < @backingInt(b);
    }

    pub fn lte(a: TileHeight, b: TileHeight) bool {
        assert(a != .nil);
        assert(b != .nil);
        return @backingInt(a) <= @backingInt(b);
    }

    pub fn gte(a: TileHeight, b: TileHeight) bool {
        assert(a != .nil);
        assert(b != .nil);
        return @backingInt(a) >= @backingInt(b);
    }

    pub fn gt(a: TileHeight, b: TileHeight) bool {
        assert(a != .nil);
        assert(b != .nil);
        return @backingInt(a) > @backingInt(b);
    }

    pub fn neq(a: TileHeight, b: TileHeight) bool {
        assert(a != .nil);
        assert(b != .nil);
        return @backingInt(a) != @backingInt(b);
    }
};

pub fn eq(a: usize, b: usize) bool {
    return a == b;
}

pub fn lt(a: usize, b: usize) bool {
    return a < b;
}

pub fn lte(a: usize, b: usize) bool {
    return a <= b;
}

pub fn gte(a: usize, b: usize) bool {
    return a >= b;
}

pub fn gt(a: usize, b: usize) bool {
    return a > b;
}

pub fn neq(a: usize, b: usize) bool {
    return a != b;
}

pub const Tile: type = struct {
    i: i32,
    o: i32,
    val: TileHeight,
};

pub const HeightDict: type = struct {
    deep_water: ArrayList(*Tile),
    shallow_water: ArrayList(*Tile),
    deep_valley: ArrayList(*Tile),
    shallow_valley: ArrayList(*Tile),
    decline: ArrayList(*Tile),
    base: ArrayList(*Tile),
    incline: ArrayList(*Tile),
    low_hill: ArrayList(*Tile),
    tall_hill: ArrayList(*Tile),
    mountain: ArrayList(*Tile),

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator, map: *[map_height * map_width]Tile) StdErr!Self {
        var base: ArrayList(*Tile) = ArrayList(*Tile).initCapacity(allocator, map.len) catch {
            return StdErr.MemoryAllocation;
        };
        for (0..map.len) |index| {
            base.appendAssumeCapacity(&map[index]);
        }
        return .{
            .deep_water = .empty,
            .shallow_water = .empty,
            .deep_valley = .empty,
            .shallow_valley = .empty,
            .decline = .empty,
            .base = base,
            .incline = .empty,
            .low_hill = .empty,
            .tall_hill = .empty,
            .mountain = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.base.clearAndFree(allocator);
        self.deep_water.deinit(allocator);
        self.shallow_water.deinit(allocator);
        self.deep_valley.deinit(allocator);
        self.shallow_valley.deinit(allocator);
        self.decline.deinit(allocator);
        self.base.deinit(allocator);
        self.incline.deinit(allocator);
        self.low_hill.deinit(allocator);
        self.tall_hill.deinit(allocator);
        self.mountain.deinit(allocator);
    }

    fn getList(self: *Self, val: TileHeight) *ArrayList(*Tile) {
        switch (val) {
            .deep_water => {
                return &self.deep_water;
            },
            .shallow_water => {
                return &self.shallow_water;
            },
            .deep_valley => {
                return &self.deep_valley;
            },
            .shallow_valley => {
                return &self.shallow_valley;
            },
            .decline => {
                return &self.decline;
            },
            .base => {
                return &self.base;
            },
            .incline => {
                return &self.incline;
            },
            .low_hill => {
                return &self.low_hill;
            },
            .tall_hill => {
                return &self.tall_hill;
            },
            .mountain => {
                return &self.mountain;
            },
            .nil => {
                unreachable;
            },
        }
    }

    fn search(list: *const ArrayList(*Tile), tile: *Tile) ?usize {
        for (0..list.items.len, list.items) |i, t| {
            if (t == tile) {
                return i;
            }
        }
        return null;
    }

    pub fn swap(self: *Self, allocator: std.mem.Allocator, map_b_tile: *Tile, new_val: TileHeight) StdErr!void {
        assert(map_b_tile.val != new_val);
        assert(map_b_tile.val != .nil);
        assert(new_val != .nil);
        const origin_list: *ArrayList(*Tile) = self.getList(map_b_tile.val);
        if (search(origin_list, map_b_tile)) |_| {} else {
            unreachable;
        }
        const index: usize = search(origin_list, map_b_tile) orelse unreachable;
        const destination: *ArrayList(*Tile) = self.getList(new_val);
        assert(search(destination, map_b_tile) == null);
        destination.append(allocator, map_b_tile) catch {
            return StdErr.MemoryAllocation;
        };
        _ = origin_list.swapRemove(index);
        map_b_tile.val = new_val;
        sync_list.append(allocator, .{ .i = map_b_tile.i, .o = map_b_tile.o, .val = new_val }) catch {
            return StdErr.MemoryAllocation;
        };
    }
};

pub const MapSection: type = struct {
    section: [9]?*Tile,
    const Self: type = @This();
    pub fn init(
        p00: ?*Tile,
        p01: ?*Tile,
        p02: ?*Tile,
        p10: ?*Tile,
        p11: *Tile,
        p12: ?*Tile,
        p20: ?*Tile,
        p21: ?*Tile,
        p22: ?*Tile,
    ) Self {
        return .{
            .section = [9]?*Tile{
                p00,
                p01,
                p02,
                p10,
                p11,
                p12,
                p20,
                p21,
                p22,
            },
        };
    }

    pub fn deltaTiles(self: *const Self, allocator: std.mem.Allocator, comp: *const fn (TileHeight, TileHeight) bool, comp_height: TileHeight) StdErr!ArrayList(*Tile) {
        var changes: ArrayList(*Tile) = ArrayList(*Tile).empty;

        for (self.section, 0..) |tile, index| {
            if (index == 4) continue;
            if (tile) |t| {
                if (comp(t.val, comp_height)) {
                    changes.append(allocator, t) catch {
                        return StdErr.MemoryAllocation;
                    };
                }
            }
        }

        return changes;
    }
};

pub const HeightMap: type = struct {
    map: [map_width * map_height]Tile,

    const Self: type = @This();

    pub fn init() Self {
        var map: [map_width * map_height]Tile = undefined;
        for (0..map_height) |i| {
            for (0..map_width) |o| {
                map[o + i * map_width] = .{
                    .i = @intCast(i),
                    .o = @intCast(o),
                    .val = .base,
                };
            }
        }

        return .{
            .map = map,
        };
    }

    pub fn get(self: *Self, i: i32, o: i32) *Tile {
        assert(i < map_height and o < map_width);
        return &self.map[@intCast(o + i * map_width)];
    }

    pub fn set(self: *Self, i: i32, o: i32, val: TileHeight) void {
        assert(i < map_height and o < map_width);
        self.map[@intCast(o + i * map_width)].val = val;
    }

    fn safeGet(self: *Self, i: i32, o: i32) ?*Tile {
        if (i >= map_height or i < 0 or o >= map_width or o < 0) {
            return null;
        }
        return self.get(i, o);
    }

    pub fn getSection(self: *Self, i: i32, o: i32) MapSection {
        assert(i < map_height and o < map_width);
        return MapSection.init(
            self.safeGet(i - 1, o - 1),
            self.safeGet(i - 1, o),
            self.safeGet(i - 1, o + 1),
            self.safeGet(i, o - 1),
            self.get(i, o), // redundant checking
            self.safeGet(i, o + 1),
            self.safeGet(i + 1, o - 1),
            self.safeGet(i + 1, o),
            self.safeGet(i + 1, o + 1),
        );
    }

    pub fn changeTile(allocator: std.mem.Allocator, i: i32, o: i32, verified: *ArrayList(*Tile), comp: *const fn (usize, usize) bool, comp_val: usize, new_val: TileHeight, dict_a: *HeightDict, map_b: *Self) StdErr!void {
        assert(i < map_height and o < map_width);
        if (map_b.get(i, o).val == new_val) return;
        defer verified.*.deinit(allocator);
        if (comp(verified.items.len, comp_val)) {
            try dict_a.swap(allocator, map_b.get(i, o), new_val);
        }
    }

    pub fn changeDeltaTiles(allocator: std.mem.Allocator, i: i32, o: i32, delta_tiles: *ArrayList(*Tile), new_val: TileHeight, dict_a: *HeightDict, map_b: *Self) StdErr!void {
        assert(i < map_height and o < map_width);
        defer delta_tiles.*.deinit(allocator);
        for (delta_tiles.*.items) |tile| {
            const edited_tile: *Tile = map_b.get(tile.i, tile.o);
            if (new_val == edited_tile.val) continue;
            try dict_a.swap(allocator, edited_tile, new_val);
        }
    }
};
