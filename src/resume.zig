//! Resume Download Support
//!
//! Provides functionality for resuming interrupted downloads using
//! HTTP Range requests. Tracks partial download state and validates
//! server support for range requests.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Information about a partial download for resumption.
pub const ResumeInfo = struct {
    /// Existing file size (bytes already downloaded).
    existing_size: u64,
    /// Expected total file size (from previous attempt).
    expected_total: ?u64,
    /// ETag from previous download (for validation).
    etag: ?[]const u8,
    /// Last-Modified from previous download (for validation).
    last_modified: ?[]const u8,
    /// Path to the partial file.
    file_path: []const u8,

    /// Check if resume is possible (file has content).
    pub fn canResume(self: ResumeInfo) bool {
        return self.existing_size > 0;
    }

    /// Get the Range header value for resuming.
    pub fn rangeHeader(self: ResumeInfo, allocator: Allocator) !?[]u8 {
        if (self.existing_size == 0) return null;
        return try std.fmt.allocPrint(allocator, "bytes={d}-", .{self.existing_size});
    }

    /// Format range for display.
    pub fn formatRange(self: ResumeInfo) RangeFormat {
        return .{
            .start = self.existing_size,
            .end = self.expected_total,
        };
    }
};

/// Range format helper.
pub const RangeFormat = struct {
    start: u64,
    end: ?u64,

    pub fn format(
        self: RangeFormat,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("bytes={d}-", .{self.start});
        if (self.end) |e| {
            try writer.print("{d}", .{e - 1});
        }
    }
};

/// Get resume information for a file.
pub fn getResumeInfo(allocator: Allocator, file_path: []const u8) !?ResumeInfo {
    _ = allocator;

    const file = std.fs.cwd().openFile(file_path, .{}) catch {
        // File doesn't exist, can't resume
        return null;
    };
    defer file.close();

    const stat = file.stat() catch {
        return null;
    };

    if (stat.size == 0) {
        return null;
    }

    return ResumeInfo{
        .existing_size = stat.size,
        .expected_total = null,
        .etag = null,
        .last_modified = null,
        .file_path = file_path,
    };
}

/// Check if server supports range requests.
pub fn supportsRangeRequests(accept_ranges: ?[]const u8) bool {
    if (accept_ranges) |ar| {
        return std.mem.eql(u8, ar, "bytes");
    }
    return false;
}

/// Validate that a partial file matches the server's current version.
pub fn validateResume(
    existing_etag: ?[]const u8,
    server_etag: ?[]const u8,
    existing_last_modified: ?[]const u8,
    server_last_modified: ?[]const u8,
) bool {
    // If server provides ETag, it must match
    if (server_etag) |s_etag| {
        if (existing_etag) |e_etag| {
            if (!std.mem.eql(u8, s_etag, e_etag)) {
                return false;
            }
        }
    }

    // If server provides Last-Modified, it should match
    if (server_last_modified) |s_lm| {
        if (existing_last_modified) |e_lm| {
            if (!std.mem.eql(u8, s_lm, e_lm)) {
                return false;
            }
        }
    }

    return true;
}

/// State for managing resume across multiple download attempts.
pub const ResumeState = struct {
    allocator: Allocator,
    file_path: []const u8,
    start_offset: u64,
    etag: ?[]const u8,
    last_modified: ?[]const u8,
    total_size: ?u64,
    validated: bool,

    /// Initialize resume state from existing file.
    pub fn init(allocator: Allocator, file_path: []const u8) !ResumeState {
        var state = ResumeState{
            .allocator = allocator,
            .file_path = file_path,
            .start_offset = 0,
            .etag = null,
            .last_modified = null,
            .total_size = null,
            .validated = false,
        };

        // Check for existing partial file
        if (try getResumeInfo(allocator, file_path)) |info| {
            state.start_offset = info.existing_size;
            state.etag = info.etag;
            state.last_modified = info.last_modified;
            state.total_size = info.expected_total;
        }

        return state;
    }

    /// Update state after receiving response headers.
    pub fn updateFromResponse(
        self: *ResumeState,
        content_length: ?u64,
        content_range: ?[]const u8,
        etag: ?[]const u8,
        last_modified: ?[]const u8,
    ) void {
        _ = content_range;

        if (content_length) |cl| {
            self.total_size = self.start_offset + cl;
        }

        if (etag) |e| {
            self.etag = e;
        }

        if (last_modified) |lm| {
            self.last_modified = lm;
        }

        self.validated = true;
    }

    /// Check if we should resume.
    pub fn shouldResume(self: *const ResumeState) bool {
        return self.start_offset > 0;
    }

    /// Get bytes already downloaded.
    pub fn bytesDownloaded(self: *const ResumeState) u64 {
        return self.start_offset;
    }

    /// Release any allocated resources.
    pub fn deinit(self: *ResumeState) void {
        self.* = undefined;
    }
};

/// Resume metadata stored alongside partial downloads.
pub const ResumeMetadata = struct {
    url: []const u8,
    etag: ?[]const u8,
    last_modified: ?[]const u8,
    total_size: ?u64,
    downloaded_size: u64,
    timestamp: i64,

    /// Serialize metadata to JSON.
    pub fn toJson(self: ResumeMetadata, allocator: Allocator) ![]u8 {
        return try std.json.stringifyAlloc(allocator, self, .{});
    }

    /// Load metadata from JSON.
    pub fn fromJson(allocator: Allocator, json: []const u8) !?ResumeMetadata {
        const parsed = try std.json.parseFromSlice(ResumeMetadata, allocator, json, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        // We need to dupe the strings because parsed.deinit() will free them
        return ResumeMetadata{
            .url = try allocator.dupe(u8, parsed.value.url),
            .etag = if (parsed.value.etag) |e| try allocator.dupe(u8, e) else null,
            .last_modified = if (parsed.value.last_modified) |lm| try allocator.dupe(u8, lm) else null,
            .total_size = parsed.value.total_size,
            .downloaded_size = parsed.value.downloaded_size,
            .timestamp = parsed.value.timestamp,
        };
    }

    /// Free memory allocated by fromJson.
    pub fn deinit(self: *ResumeMetadata, allocator: Allocator) void {
        allocator.free(self.url);
        if (self.etag) |e| allocator.free(e);
        if (self.last_modified) |lm| allocator.free(lm);
    }
};

// Tests
test "resume info" {
    const info = ResumeInfo{
        .existing_size = 1000,
        .expected_total = 5000,
        .etag = null,
        .last_modified = null,
        .file_path = "test.bin",
    };

    try std.testing.expect(info.canResume());
}

test "resume info cannot resume empty" {
    const info = ResumeInfo{
        .existing_size = 0,
        .expected_total = 5000,
        .etag = null,
        .last_modified = null,
        .file_path = "test.bin",
    };

    try std.testing.expect(!info.canResume());
}

test "supports range requests" {
    try std.testing.expect(supportsRangeRequests("bytes"));
    try std.testing.expect(!supportsRangeRequests("none"));
    try std.testing.expect(!supportsRangeRequests(null));
}

test "validate resume matching etag" {
    try std.testing.expect(validateResume(
        "abc123",
        "abc123",
        null,
        null,
    ));
}

test "validate resume mismatched etag" {
    try std.testing.expect(!validateResume(
        "abc123",
        "xyz789",
        null,
        null,
    ));
}
