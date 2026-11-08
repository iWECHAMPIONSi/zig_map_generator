const std = @import("std");
const Random = std.Random;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const StdErr = @import("std_err.zig").StdErr;
const AutoHashMap = std.hash_map.AutoHashMapUnmanaged;
const print = std.debug.print;

pub var change_list: ArrayList(Tile) = ArrayList(Tile).empty;
pub var sync_list: ArrayList(Tile) = ArrayList(Tile).empty;

pub const screen_width: i32 = 1100;
pub const screen_height: i32 = 700;

pub const map_width: i32 = 130;
pub const map_height: i32 = 130;

pub const mountain_seeds: i32 = map_width / 24;

fn printCoords(func: []const u8, i: i32, o: i32) void {
    print("[{s}] i: {}, o: {}\n", .{ func, i, o });
}

pub const TileBiome: type = enum(i8) {};

pub const TileHeight: type = enum(i8) {
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

    pub fn lowerHeight(self: TileHeight) TileHeight {
        assert(@backingInt(self) > @backingInt(TileHeight.deep_valley));
        return @fromBackingInt(@backingInt(self) - 1);
    }

    pub fn raiseHeight(self: TileHeight) TileHeight {
        assert(@backingInt(self) > @backingInt(TileHeight.shallow_water));
        assert(@backingInt(self) < @backingInt(TileHeight.mountain));
        return @fromBackingInt(@backingInt(self) + 1);
    }

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
        return @backingInt(a) == @backingInt(b);
    }

    pub fn lt(a: TileHeight, b: TileHeight) bool {
        return @backingInt(a) < @backingInt(b);
    }

    pub fn lte(a: TileHeight, b: TileHeight) bool {
        return @backingInt(a) <= @backingInt(b);
    }

    pub fn gte(a: TileHeight, b: TileHeight) bool {
        return @backingInt(a) >= @backingInt(b);
    }

    pub fn gt(a: TileHeight, b: TileHeight) bool {
        return @backingInt(a) > @backingInt(b);
    }

    pub fn neq(a: TileHeight, b: TileHeight) bool {
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
    deep_water: AutoHashMap(usize, *Tile),
    shallow_water: AutoHashMap(usize, *Tile),
    deep_valley: AutoHashMap(usize, *Tile),
    shallow_valley: AutoHashMap(usize, *Tile),
    decline: AutoHashMap(usize, *Tile),
    base: AutoHashMap(usize, *Tile),
    incline: AutoHashMap(usize, *Tile),
    low_hill: AutoHashMap(usize, *Tile),
    tall_hill: AutoHashMap(usize, *Tile),
    mountain: AutoHashMap(usize, *Tile),

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator, map: *[map_height * map_width]Tile) StdErr!Self {
        var base = AutoHashMap(usize, *Tile).empty;
        base.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer base.deinit(allocator);

        for (0..map.len) |index| {
            base.putAssumeCapacityNoClobber(index, &map[index]);
        }

        var deep_water = AutoHashMap(usize, *Tile).empty;
        deep_water.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer deep_water.deinit(allocator);

        var shallow_water = AutoHashMap(usize, *Tile).empty;
        shallow_water.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer shallow_water.deinit(allocator);

        var deep_valley = AutoHashMap(usize, *Tile).empty;
        deep_valley.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer deep_valley.deinit(allocator);

        var shallow_valley = AutoHashMap(usize, *Tile).empty;
        shallow_valley.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer shallow_valley.deinit(allocator);

        var decline = AutoHashMap(usize, *Tile).empty;
        decline.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer decline.deinit(allocator);

        var incline = AutoHashMap(usize, *Tile).empty;
        incline.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer incline.deinit(allocator);

        var low_hill = AutoHashMap(usize, *Tile).empty;
        low_hill.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer low_hill.deinit(allocator);

        var tall_hill = AutoHashMap(usize, *Tile).empty;
        tall_hill.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer tall_hill.deinit(allocator);

        var mountain = AutoHashMap(usize, *Tile).empty;
        mountain.ensureTotalCapacity(allocator, map_height * map_width) catch {
            return StdErr.MemoryAllocation;
        };
        errdefer mountain.deinit(allocator);

        return .{
            .deep_water = deep_water,
            .shallow_water = shallow_water,
            .deep_valley = deep_valley,
            .shallow_valley = shallow_valley,
            .decline = decline,
            .base = base,
            .incline = incline,
            .low_hill = low_hill,
            .tall_hill = tall_hill,
            .mountain = mountain,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
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

    pub fn getMap(self: *Self, val: TileHeight) *AutoHashMap(usize, *Tile) {
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
        }
    }

    pub fn swap(self: *Self, allocator: std.mem.Allocator, map_b_tile: *Tile, new_val: TileHeight) StdErr!void {
        try self.internalSwap(map_b_tile, new_val);
        // printCoords("swap", map_b_tile.i, map_b_tile.o);
        sync_list.append(allocator, .{ .i = map_b_tile.i, .o = map_b_tile.o, .val = new_val }) catch {
            return StdErr.MemoryAllocation;
        };
    }

    pub fn syncSwap(self: *Self, map_b_tile: *Tile, new_val: TileHeight) StdErr!void {
        try self.internalSwap(map_b_tile, new_val);
        // printCoords("syncSwap", map_b_tile.i, map_b_tile.o);
    }

    fn internalSwap(self: *Self, map_b_tile: *Tile, new_val: TileHeight) StdErr!void {
        assert(map_b_tile.val != new_val);
        const key: usize = @intCast(map_b_tile.o + map_b_tile.i * map_width);
        const origin_list = self.getMap(map_b_tile.val);
        assert(origin_list.contains(key));
        const destination = self.getMap(new_val);
        assert(!destination.contains(key));
        destination.putAssumeCapacityNoClobber(key, map_b_tile);
        _ = origin_list.remove(key);
        map_b_tile.val = new_val;
    }

    pub fn getList(self: *Self, val: TileHeight) Iterator {
        return .{ .iter = self.getMap(val).valueIterator() };
    }
};

pub const Iterator = struct {
    iter: AutoHashMap(usize, *Tile).ValueIterator,

    const Self = @This();
    pub fn next(self: *Self) ?*Tile {
        const tile: ?**Tile = self.iter.next();
        if (tile) |t| return t.*;
        return null;
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

    pub fn deltaTiles(self: *const Self, allocator: std.mem.Allocator, comp: *const fn (TileHeight, TileHeight) bool, comp_height: TileHeight, delta_tiles: *ArrayList(*Tile)) StdErr!void {
        for (self.section, 0..) |tile, index| {
            if (index == 4) continue;
            if (tile) |t| {
                if (comp(t.val, comp_height)) {
                    delta_tiles.append(allocator, t) catch {
                        return StdErr.MemoryAllocation;
                    };
                }
            }
        }
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
        assert(i < map_height);
        assert(o < map_width);
        return &self.map[@intCast(o + i * map_width)];
    }

    fn safeGet(self: *Self, i: i32, o: i32) ?*Tile {
        if (i >= map_height or i < 0 or o >= map_width or o < 0) {
            return null;
        }
        return self.get(i, o);
    }

    pub fn getSection(self: *Self, i: i32, o: i32) MapSection {
        assert(i < map_height);
        assert(o < map_width);
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

    pub fn changeTile(allocator: std.mem.Allocator, i: i32, o: i32, verified: *ArrayList(*Tile), comp: *const fn (usize, usize) bool, comp_val: usize, new_val: TileHeight, dict_a: *HeightDict, map_b: *Self) StdErr!bool {
        assert(i < map_height);
        assert(o < map_width);
        var changed = false;
        defer verified.*.clearRetainingCapacity();
        if (map_b.get(i, o).val == new_val) return changed;
        if (comp(verified.items.len, comp_val)) {
            changed = true;
            try dict_a.swap(allocator, map_b.get(i, o), new_val);
        }
        return changed;
    }

    pub fn changeDeltaTiles(allocator: std.mem.Allocator, delta_tiles: *ArrayList(*Tile), new_val: TileHeight, dict_a: *HeightDict, map_b: *Self) StdErr!bool {
        var changed: bool = false;
        defer delta_tiles.*.clearRetainingCapacity();
        for (delta_tiles.*.items) |tile| {
            const edited_tile: *Tile = map_b.get(tile.i, tile.o);
            if (new_val == edited_tile.val) continue;
            changed = true;
            try dict_a.swap(allocator, edited_tile, new_val);
        }
        return changed;
    }
};
