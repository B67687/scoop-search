const std = @import("std");
const mvzr = @import("mvzr");
const utils = @import("utils.zig");

/// Pre-computed index for fast searching
pub const Index = struct {
    entries: std.ArrayList(IndexEntry),
    allocator: std.mem.Allocator,

    pub const IndexEntry = struct {
        bucket: []const u8,
        name: []const u8,
        version: []const u8,
        bins: std.ArrayList([]const u8),
    };

    pub fn load(allocator: std.mem.Allocator, cache_path: []const u8) !?Index {
        const file = std.fs.openFileAbsolute(cache_path, .{}) catch return null;
        defer file.close();
        
        const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(content);
        
        var entries = std.ArrayList(IndexEntry).init(allocator);
        var line_iter = std.mem.tokenize(u8, content, "\n");
        
        while (line_iter.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;
            
            var parts = std.mem.tokenize(u8, line, "|");
            const bucket = parts.next() orelse continue;
            const name = parts.next() orelse continue;
            const version = parts.next() orelse "";
            const bin_str = parts.next() orelse "";
            
            var bins = std.ArrayList([]const u8).init(allocator);
            if (bin_str.len > 0) {
                var bin_iter = std.mem.tokenize(u8, bin_str, ",");
                while (bin_iter.next()) |bin| {
                    try bins.append(try allocator.dupe(u8, bin));
                }
            }
            
            try entries.append(.{
                .bucket = try allocator.dupe(u8, bucket),
                .name = try allocator.dupe(u8, name),
                .version = try allocator.dupe(u8, version),
                .bins = bins,
            });
        }
        
        return Index{ .entries = entries, .allocator = allocator };
    }

    pub fn search(self: *Index, query: mvzr.Regex) std.ArrayList(IndexEntry) {
        var results = std.ArrayList(IndexEntry).init(self.allocator);
        
        for (self.entries.items) |entry| {
            const lower_name = std.ascii.toLowerAlloc(self.allocator, entry.name) catch continue;
            defer self.allocator.free(lower_name);
            
            var matched = false;
            if (query.isMatch(lower_name)) {
                matched = true;
            } else {
                for (entry.bins.items) |bin| {
                    const lower_bin = std.ascii.toLowerAlloc(self.allocator, bin) catch continue;
                    defer self.allocator.free(lower_bin);
                    if (query.isMatch(lower_bin)) {
                        matched = true;
                        break;
                    }
                }
            }
            
            if (matched) {
                results.append(entry) catch continue;
            }
        }
        
        return results;
    }

    pub fn deinit(self: *Index) void {
        for (self.entries.items) |*e| {
            self.allocator.free(e.bucket);
            self.allocator.free(e.name);
            self.allocator.free(e.version);
            for (e.bins.items) |b| self.allocator.free(b);
            e.bins.deinit();
        }
        self.entries.deinit();
    }
};