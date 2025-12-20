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

/// Check for updates in a background thread.
///
/// Returns a thread handle that can be joined, or null if disabled.
pub fn checkInBackground(allocator: std.mem.Allocator) ?std.Thread {
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
