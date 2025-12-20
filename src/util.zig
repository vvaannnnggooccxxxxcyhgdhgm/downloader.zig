//! Internal Utilities
//!
//! Helper functions for URL parsing, file operations, timing,
//! and other common operations used throughout the library.

const std = @import("std");

/// Parse a URL string into a URI.
///
/// Returns null if the URL is malformed.
pub fn parseUrl(url: []const u8) ?std.Uri {
    return std.Uri.parse(url) catch return null;
}

/// Check if a URL scheme is supported.
///
/// Only http and https are supported.
pub fn isSupportedScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "https");
}

/// Check if an HTTP status code indicates success (2xx).
pub fn isSuccessStatus(status: u16) bool {
    return status >= 200 and status < 300;
}

/// Check if an HTTP status code indicates partial content (206).
pub fn isPartialContent(status: u16) bool {
    return status == 206;
}

/// Check if an HTTP status code indicates a redirect (3xx).
pub fn isRedirect(status: u16) bool {
    return status >= 300 and status < 400;
}

/// Check if an error is transient and worth retrying.
pub fn isRetryableError(err: anyerror) bool {
    return switch (err) {
        error.ConnectionTimeout,
        error.ConnectionFailed,
        error.DownloadInterrupted,
        error.ConnectionResetByPeer,
        error.BrokenPipe,
        error.NetworkUnreachable,
        error.HostUnreachable,
        error.ConnectionRefused,
        => true,
        else => false,
    };
}

/// Sleep for the specified number of milliseconds.
pub fn sleepMs(ms: u64) void {
    std.Thread.sleep(ms * std.time.ns_per_ms);
}

/// Get the file size, or null if the file doesn't exist.
pub fn getFileSize(path: []const u8) ?u64 {
    const file = std.fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();
    const stat = file.stat() catch return null;
    return stat.size;
}

/// Extract filename from a URL path.
///
/// Returns "download" if no filename can be determined.
pub fn filenameFromUrl(url: []const u8) []const u8 {
    const uri = parseUrl(url) orelse return "download";
    const path = uri.path.percent_encoded;
    if (path.len == 0) return "download";

    var last_slash: usize = 0;
    for (path, 0..) |c, i| {
        if (c == '/') last_slash = i + 1;
    }

    const filename = path[last_slash..];
    if (filename.len == 0) return "download";

    for (filename, 0..) |c, i| {
        if (c == '?') return filename[0..i];
    }

    return filename;
}

/// Generate a unique filename by appending (1), (2), etc.
///
/// Follows the naming convention used by Windows, Linux, and macOS
/// file managers when a file already exists.
pub fn getUniqueFilename(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (std.fs.cwd().access(path, .{})) |_| {
        // File exists
    } else |_| {
        return try allocator.dupe(u8, path);
    }

    // Find extension separator
    var ext_start: usize = path.len;
    var name_end: usize = path.len;
    var i: usize = path.len;
    while (i > 0) {
        i -= 1;
        if (path[i] == '.') {
            ext_start = i;
            name_end = i;
            break;
        }
        if (path[i] == '/' or path[i] == '\\') {
            break;
        }
    }

    const base_name = path[0..name_end];
    const extension = path[ext_start..];

    var counter: u32 = 1;
    while (counter < 10000) : (counter += 1) {
        const new_path = try std.fmt.allocPrint(allocator, "{s} ({d}){s}", .{ base_name, counter, extension });

        if (std.fs.cwd().access(new_path, .{})) |_| {
            allocator.free(new_path);
        } else |_| {
            return new_path;
        }
    }

    return try std.fmt.allocPrint(allocator, "{s} (9999){s}", .{ base_name, extension });
}

/// Truncate a file to the specified size.
pub fn truncateFile(path: []const u8, size: u64) !void {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    defer file.close();
    try file.setEndPos(size);
}

/// Calculate exponential backoff delay with jitter.
pub fn calculateBackoff(
    base_delay_ms: u64,
    max_delay_ms: u64,
    attempt: u32,
    use_exponential: bool,
) u64 {
    if (!use_exponential) return base_delay_ms;

    const multiplier: u64 = @as(u64, 1) << @min(attempt, 20);
    const delay = @min(base_delay_ms *| multiplier, max_delay_ms);

    // Add jitter (±25%)
    const jitter_range = delay / 4;
    if (jitter_range == 0) return delay;

    const jitter = @as(u64, @intCast(attempt)) * 17 % (jitter_range * 2);
    return delay -| jitter_range +| jitter;
}

/// Validate that a path is safe for writing.
pub fn validateOutputPath(path: []const u8) bool {
    if (path.len == 0) return false;

    if (std.mem.startsWith(u8, path, "http://") or
        std.mem.startsWith(u8, path, "https://"))
    {
        return false;
    }

    return true;
}

test "URL parsing" {
    const uri = parseUrl("https://example.com/file.zip");
    try std.testing.expect(uri != null);
    try std.testing.expectEqualStrings("https", uri.?.scheme);
}

test "scheme validation" {
    try std.testing.expect(isSupportedScheme("http"));
    try std.testing.expect(isSupportedScheme("https"));
    try std.testing.expect(!isSupportedScheme("ftp"));
}

test "status code classification" {
    try std.testing.expect(isSuccessStatus(200));
    try std.testing.expect(isSuccessStatus(206));
    try std.testing.expect(!isSuccessStatus(404));
    try std.testing.expect(!isSuccessStatus(500));
}

test "filename extraction" {
    try std.testing.expectEqualStrings("file.zip", filenameFromUrl("https://example.com/path/file.zip"));
    try std.testing.expectEqualStrings("download", filenameFromUrl("https://example.com/"));
}

test "exponential backoff" {
    const delay0 = calculateBackoff(1000, 30000, 0, true);
    const delay1 = calculateBackoff(1000, 30000, 1, true);
    const delay2 = calculateBackoff(1000, 30000, 2, true);

    try std.testing.expect(delay0 <= 1250);
    try std.testing.expect(delay1 <= delay2 or delay1 >= 1000);
}

test "output path validation" {
    try std.testing.expect(validateOutputPath("file.zip"));
    try std.testing.expect(validateOutputPath("./downloads/file.zip"));
    try std.testing.expect(!validateOutputPath(""));
    try std.testing.expect(!validateOutputPath("https://example.com"));
}
