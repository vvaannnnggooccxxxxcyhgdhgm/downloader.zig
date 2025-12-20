//! Utility Functions
//!
//! Provides helper functions for URL parsing, filename extraction,
//! Content-Disposition parsing, and file path manipulation.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Generate a unique filename by appending a number suffix.
///
/// Similar to Windows behavior: file (1).pdf, file (2).pdf, etc.
pub fn getUniqueFilename(
    allocator: Allocator,
    base_path: []const u8,
    max_attempts: u32,
) ![]u8 {
    // First check if base path exists
    std.fs.cwd().access(base_path, .{}) catch {
        // File doesn't exist, use base path
        return allocator.dupe(u8, base_path);
    };

    // Find extension
    var ext_start: usize = base_path.len;
    var name_end: usize = base_path.len;
    for (base_path, 0..) |c, i| {
        if (c == '.') {
            ext_start = i;
            name_end = i;
        } else if (c == '/' or c == '\\') {
            ext_start = base_path.len;
            name_end = base_path.len;
        }
    }

    const name = base_path[0..name_end];
    const ext = base_path[ext_start..];

    // Try numbered suffixes
    var i: u32 = 1;
    while (i <= max_attempts) : (i += 1) {
        const new_path = try std.fmt.allocPrint(allocator, "{s} ({d}){s}", .{ name, i, ext });
        errdefer allocator.free(new_path);

        std.fs.cwd().access(new_path, .{}) catch {
            // File doesn't exist, use this path
            return new_path;
        };

        allocator.free(new_path);
    }

    return error.OutOfMemory;
}

/// Extract filename from a URL path.
pub fn filenameFromUrl(url: []const u8) []const u8 {
    // Find the path part (after scheme://host)
    var path_start: usize = 0;
    var slash_count: u8 = 0;

    for (url, 0..) |c, i| {
        if (c == '/') {
            slash_count += 1;
            if (slash_count >= 3) {
                path_start = i + 1;
                break;
            }
        }
    }

    // Find last slash in path
    var last_slash: usize = path_start;
    for (url[path_start..], path_start..) |c, i| {
        if (c == '/') last_slash = i + 1;
    }

    const filename_with_query = url[last_slash..];
    if (filename_with_query.len == 0) return "download";

    // Remove query string
    for (filename_with_query, 0..) |c, i| {
        if (c == '?' or c == '#') {
            if (i == 0) return "download";
            return filename_with_query[0..i];
        }
    }

    return filename_with_query;
}

/// Parse Content-Disposition header to extract filename.
///
/// Supports both:
/// - Content-Disposition: attachment; filename="example.pdf"
/// - Content-Disposition: attachment; filename=example.pdf
/// - Content-Disposition: attachment; filename*=UTF-8''example.pdf
pub fn parseContentDisposition(header: []const u8) ?[]const u8 {
    // Look for filename= or filename*=
    const filename_key = "filename=";
    const filename_star_key = "filename*=";

    // Try filename* first (RFC 5987 extended notation)
    if (std.mem.indexOf(u8, header, filename_star_key)) |star_pos| {
        const value_start = star_pos + filename_star_key.len;
        if (value_start < header.len) {
            // Skip encoding prefix like UTF-8''
            const value = header[value_start..];
            if (std.mem.indexOf(u8, value, "''")) |quote_pos| {
                const name_start = quote_pos + 2;
                if (name_start < value.len) {
                    return extractValue(value[name_start..]);
                }
            }
        }
    }

    // Fall back to regular filename=
    if (std.mem.indexOf(u8, header, filename_key)) |pos| {
        const value_start = pos + filename_key.len;
        if (value_start < header.len) {
            return extractValue(header[value_start..]);
        }
    }

    return null;
}

/// Extract a value, handling quoted strings.
fn extractValue(input: []const u8) []const u8 {
    if (input.len == 0) return input;

    var start: usize = 0;
    var end: usize = input.len;

    // Handle quoted string
    if (input[0] == '"') {
        start = 1;
        for (input[1..], 1..) |c, i| {
            if (c == '"') {
                end = i;
                break;
            }
        }
    } else {
        // Unquoted - find end (semicolon or whitespace)
        for (input, 0..) |c, i| {
            if (c == ';' or c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                end = i;
                break;
            }
        }
    }

    return input[start..end];
}

/// Sanitize a filename by removing/replacing invalid characters.
pub fn sanitizeFilename(allocator: Allocator, filename: []const u8) ![]u8 {
    const invalid_chars = "<>:\"/\\|?*";
    var result = try allocator.alloc(u8, filename.len);
    errdefer allocator.free(result);

    var len: usize = 0;
    for (filename) |c| {
        // Skip invalid characters
        var is_invalid = false;
        for (invalid_chars) |invalid| {
            if (c == invalid) {
                is_invalid = true;
                break;
            }
        }

        // Skip control characters
        if (c < 32) continue;

        if (!is_invalid) {
            result[len] = c;
            len += 1;
        }
    }

    // Trim trailing spaces and dots
    while (len > 0 and (result[len - 1] == ' ' or result[len - 1] == '.')) {
        len -= 1;
    }

    if (len == 0) {
        allocator.free(result);
        return allocator.dupe(u8, "download");
    }

    return allocator.realloc(result, len);
}

/// Get file extension from filename.
pub fn getExtension(filename: []const u8) ?[]const u8 {
    var last_dot: ?usize = null;
    var last_sep: usize = 0;

    for (filename, 0..) |c, i| {
        if (c == '/' or c == '\\') {
            last_sep = i;
            last_dot = null;
        } else if (c == '.') {
            last_dot = i;
        }
    }

    if (last_dot) |dot| {
        if (dot > last_sep and dot + 1 < filename.len) {
            return filename[dot + 1 ..];
        }
    }

    return null;
}

/// Join path components.
pub fn joinPath(allocator: Allocator, dir: []const u8, filename: []const u8) ![]u8 {
    if (dir.len == 0) {
        return allocator.dupe(u8, filename);
    }

    const sep: u8 = if (std.mem.indexOf(u8, dir, "\\") != null) '\\' else '/';
    const has_trailing_sep = dir[dir.len - 1] == '/' or dir[dir.len - 1] == '\\';

    if (has_trailing_sep) {
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ dir, filename });
    } else {
        return std.fmt.allocPrint(allocator, "{s}{c}{s}", .{ dir, sep, filename });
    }
}

/// Format bytes as human-readable string.
pub fn formatBytes(bytes: u64) struct { value: f64, unit: []const u8 } {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB", "PB" };
    var size: f64 = @floatFromInt(bytes);
    var unit_idx: usize = 0;

    while (size >= 1024.0 and unit_idx < units.len - 1) {
        size /= 1024.0;
        unit_idx += 1;
    }

    return .{ .value = size, .unit = units[unit_idx] };
}

/// Format duration in seconds as human-readable string.
pub fn formatDuration(seconds: u64) struct { hours: u64, minutes: u64, secs: u64 } {
    return .{
        .hours = seconds / 3600,
        .minutes = (seconds % 3600) / 60,
        .secs = seconds % 60,
    };
}

/// Check if a URL uses HTTPS.
pub fn isHttps(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "https://");
}

/// Check if a URL is valid HTTP/HTTPS.
pub fn isValidHttpUrl(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://");
}

/// Get the host from a URL.
pub fn getHost(url: []const u8) ?[]const u8 {
    // Skip scheme
    var start: usize = 0;
    if (std.mem.startsWith(u8, url, "https://")) {
        start = 8;
    } else if (std.mem.startsWith(u8, url, "http://")) {
        start = 7;
    } else {
        return null;
    }

    // Find end of host (port, path, or end)
    for (url[start..], start..) |c, i| {
        if (c == ':' or c == '/' or c == '?' or c == '#') {
            return url[start..i];
        }
    }

    return url[start..];
}

// Tests
test "filename from url" {
    try std.testing.expectEqualStrings(
        "file.pdf",
        filenameFromUrl("https://example.com/path/file.pdf"),
    );
    try std.testing.expectEqualStrings(
        "file.pdf",
        filenameFromUrl("https://example.com/file.pdf?query=1"),
    );
    try std.testing.expectEqualStrings(
        "download",
        filenameFromUrl("https://example.com/"),
    );
}

test "parse content disposition" {
    try std.testing.expectEqualStrings(
        "example.pdf",
        parseContentDisposition("attachment; filename=\"example.pdf\"").?,
    );
    try std.testing.expectEqualStrings(
        "example.pdf",
        parseContentDisposition("attachment; filename=example.pdf").?,
    );
    try std.testing.expect(parseContentDisposition("inline") == null);
}

test "get extension" {
    try std.testing.expectEqualStrings("pdf", getExtension("file.pdf").?);
    try std.testing.expectEqualStrings("gz", getExtension("archive.tar.gz").?);
    try std.testing.expect(getExtension("noext") == null);
}

test "format bytes" {
    const kb = formatBytes(1024);
    try std.testing.expect(kb.value == 1.0);
    try std.testing.expectEqualStrings("KB", kb.unit);

    const mb = formatBytes(1024 * 1024);
    try std.testing.expect(mb.value == 1.0);
    try std.testing.expectEqualStrings("MB", mb.unit);
}

test "is https" {
    try std.testing.expect(isHttps("https://example.com"));
    try std.testing.expect(!isHttps("http://example.com"));
}

test "get host" {
    try std.testing.expectEqualStrings("example.com", getHost("https://example.com/path").?);
    try std.testing.expectEqualStrings("example.com", getHost("http://example.com:8080/").?);
}
