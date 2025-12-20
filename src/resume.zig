//! Download Resume Support
//!
//! Provides functionality for resuming interrupted downloads using
//! HTTP Range headers. Includes file verification and offset calculation.

const std = @import("std");
const errors = @import("errors.zig");

/// Resume capability check result.
pub const ResumeInfo = struct {
    /// Whether resume is possible.
    can_resume: bool,
    /// Byte offset to resume from.
    offset: u64,
    /// Reason if resume is not possible.
    reason: ?ResumeBlockReason,
};

/// Reasons why resume may not be possible.
pub const ResumeBlockReason = enum {
    /// No partial file exists.
    no_partial_file,
    /// Server does not support Range requests.
    server_not_supported,
    /// Partial file is empty.
    file_empty,
    /// Partial file is already complete.
    file_complete,
    /// File was modified on server.
    file_modified,
};

/// Check if a download can be resumed.
///
/// Examines the partial file and server capabilities to determine
/// if resume is possible and at what offset.
pub fn checkResumeCapability(
    output_path: []const u8,
    server_content_length: ?u64,
    server_accepts_ranges: bool,
) ResumeInfo {
    // Check if server supports Range requests
    if (!server_accepts_ranges) {
        return .{
            .can_resume = false,
            .offset = 0,
            .reason = .server_not_supported,
        };
    }

    // Check if partial file exists
    const file = std.fs.cwd().openFile(output_path, .{}) catch {
        return .{
            .can_resume = false,
            .offset = 0,
            .reason = .no_partial_file,
        };
    };
    defer file.close();

    // Get current file size
    const stat = file.stat() catch {
        return .{
            .can_resume = false,
            .offset = 0,
            .reason = .no_partial_file,
        };
    };

    const current_size = stat.size;

    // Empty file - no point resuming
    if (current_size == 0) {
        return .{
            .can_resume = false,
            .offset = 0,
            .reason = .file_empty,
        };
    }

    // Check against server's content length
    if (server_content_length) |total| {
        if (current_size >= total) {
            return .{
                .can_resume = false,
                .offset = 0,
                .reason = .file_complete,
            };
        }
    }

    // Resume is possible
    return .{
        .can_resume = true,
        .offset = current_size,
        .reason = null,
    };
}

/// Open output file for writing, handling resume offset.
///
/// If offset > 0, opens for append. Otherwise creates a new file.
pub fn openOutputFile(path: []const u8, offset: u64) !std.fs.File {
    if (offset > 0) {
        // Open existing file for appending
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        try file.seekTo(offset);
        return file;
    } else {
        // Create new file
        return try std.fs.cwd().createFile(path, .{});
    }
}

/// Verify partial file integrity.
///
/// Returns true if the partial file appears valid for resumption.
pub fn verifyPartialFile(path: []const u8, expected_offset: u64) bool {
    const file = std.fs.cwd().openFile(path, .{}) catch return false;
    defer file.close();

    const stat = file.stat() catch return false;
    return stat.size == expected_offset;
}

/// Delete a partial file if it exists.
pub fn deletePartialFile(path: []const u8) void {
    std.fs.cwd().deleteFile(path) catch {};
}

test "resume capability - no file" {
    const info = checkResumeCapability("nonexistent_file.pdf", 1000, true);
    try std.testing.expect(!info.can_resume);
    try std.testing.expect(info.reason == .no_partial_file);
}

test "resume capability - server not supported" {
    const info = checkResumeCapability("any_file.pdf", 1000, false);
    try std.testing.expect(!info.can_resume);
    try std.testing.expect(info.reason == .server_not_supported);
}
