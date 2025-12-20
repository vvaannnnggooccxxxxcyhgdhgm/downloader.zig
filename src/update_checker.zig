//! Update Checker
//!
//! Provides optional background checking for library updates.
//! Compares the current version against the latest GitHub release.

const std = @import("std");
const version = @import("version.zig");

/// Version comparison result.
pub const VersionRelation = enum {
    local_newer,
    remote_newer,
    equal,
    unknown,
};

/// Update check result.
pub const UpdateInfo = struct {
    available: bool,
    current_version: []const u8,
    latest_version: ?[]const u8,
    download_url: ?[]const u8,
};

/// Check for updates from GitHub.
pub fn checkForUpdates(allocator: std.mem.Allocator) !UpdateInfo {
    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();

    const uri = try std.Uri.parse("https://api.github.com/repos/muhammad-fiaz/downloader.zig/releases/latest");

    var server_header_buffer: [16 * 1024]u8 = undefined;
    var req = try http_client.request(.GET, uri, .{
        .extra_headers = &.{
            .{ .name = "User-Agent", .value = "downloader.zig-update-checker" },
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
        },
    });
    defer req.deinit();

    try req.sendBodiless();
    var resp = try req.receiveHead(&server_header_buffer);

    if (resp.head.status != .ok) {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    }

    var body_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer body_buffer.deinit(allocator);

    var reader_ptr = resp.reader(&server_header_buffer);
    var reader = reader_ptr.adaptToOldInterface();

    const limit = resp.head.content_length;
    var buf: [4096]u8 = undefined;
    while (true) {
        const current_len = body_buffer.items.len;
        const to_read = if (limit) |l| @min(buf.len, l - current_len) else buf.len;
        if (to_read == 0 and limit != null) break;

        const n = try reader.read(buf[0..to_read]);
        if (n == 0) break;

        try body_buffer.appendSlice(allocator, buf[0..n]);
        if (body_buffer.items.len > 1 * 1024 * 1024) return error.StreamTooLong;
    }

    const parsed = try std.json.parseFromSlice(struct {
        tag_name: []const u8,
        html_url: []const u8,
    }, allocator, body_buffer.items, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const latest = parseVersionTag(parsed.value.tag_name);
    const rel = compareVersions(latest);

    return UpdateInfo{
        .available = rel == .remote_newer,
        .current_version = version.version,
        .latest_version = try allocator.dupe(u8, latest),
        .download_url = try allocator.dupe(u8, parsed.value.html_url),
    };
}

/// Check for updates in a background thread.
pub fn checkInBackground(allocator: std.mem.Allocator) !?std.Thread {
    _ = allocator;
    // Background update checking is optional and disabled by default
    // to avoid unexpected network requests.
    return null;
}

/// Compare a version string against the current library version.
pub fn compareVersions(remote_version: []const u8) VersionRelation {
    const local = version.semanticVersion();
    const remote = std.SemanticVersion.parse(remote_version) catch return .unknown;

    if (local.major > remote.major) return .local_newer;
    if (local.major < remote.major) return .remote_newer;

    if (local.minor > remote.minor) return .local_newer;
    if (local.minor < remote.minor) return .remote_newer;

    if (local.patch > remote.patch) return .local_newer;
    if (local.patch < remote.patch) return .remote_newer;

    return .equal;
}

/// Get the current library version.
pub fn getCurrentVersion() []const u8 {
    return version.version;
}

/// Parse a version tag (e.g., "v1.2.3") to version string.
pub fn parseVersionTag(tag: []const u8) []const u8 {
    if (tag.len > 0 and tag[0] == 'v') {
        return tag[1..];
    }
    return tag;
}

/// Format update notification message.
pub fn formatUpdateMessage(
    allocator: std.mem.Allocator,
    current: []const u8,
    latest: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "Update available: {s} -> {s}\n" ++
            "Download: https://github.com/muhammad-fiaz/downloader.zig/releases/latest",
        .{ current, latest },
    );
}

test "version comparison - equal" {
    const result = compareVersions(version.version);
    try std.testing.expect(result == .equal);
}

test "version comparison - remote newer" {
    const result = compareVersions("1.0.0");
    try std.testing.expect(result == .remote_newer);
}

test "version comparison - local newer" {
    const result = compareVersions("0.0.0");
    try std.testing.expect(result == .local_newer);
}

test "current version" {
    const ver = getCurrentVersion();
    try std.testing.expectEqualStrings("0.0.1", ver);
}

test "version tag parsing" {
    try std.testing.expectEqualStrings("1.2.3", parseVersionTag("v1.2.3"));
    try std.testing.expectEqualStrings("1.2.3", parseVersionTag("1.2.3"));
}
