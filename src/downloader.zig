//! downloader.zig - HTTP/HTTPS Download Library
//!
//! A production-ready library for downloading files with support for:
//! - HTTP and HTTPS protocols
//! - Automatic retry with exponential backoff
//! - Resume capability via Range headers
//! - Real-time progress reporting
//! - Configurable timeouts and buffer sizes
//!
//! ## Quick Start
//! ```zig
//! const downloader = @import("downloader");
//!
//! // Simple download
//! try downloader.download(allocator, url, "output.pdf");
//!
//! // With progress callback
//! try downloader.downloadWithProgress(allocator, url, "output.pdf", callback);
//! ```
//!
//! ## Thread Safety
//! Client instances are not thread-safe. Create one Client per thread
//! for concurrent downloads.

const std = @import("std");

// Re-export public modules
pub const client = @import("client.zig");
pub const config = @import("config.zig");
pub const progress = @import("progress.zig");
pub const errors_mod = @import("errors.zig");
pub const version = @import("version.zig");
pub const update_checker = @import("update_checker.zig");

// Public type aliases
pub const Client = client.Client;
pub const Config = config.Config;
pub const FileExistsAction = config.FileExistsAction;
pub const Progress = progress.Progress;
pub const ProgressCallback = progress.ProgressCallback;
pub const ProgressTracker = progress.ProgressTracker;
pub const DownloadError = errors_mod.DownloadError;
pub const StatusCategory = errors_mod.StatusCategory;
pub const ErrorInfo = errors_mod.ErrorInfo;

// Built-in progress callbacks
pub const noopCallback = progress.noopCallback;
pub const stderrCallback = progress.stderrCallback;

/// Download a file using default configuration.
///
/// Parameters:
///   - allocator: Memory allocator for internal buffers
///   - url: HTTP or HTTPS URL to download
///   - output_path: Local file path for the downloaded content
///
/// Returns: Total bytes downloaded
pub fn download(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
) !u64 {
    return downloadWithConfig(allocator, url, output_path, Config.default(), null);
}

/// Download a file with progress reporting.
///
/// The callback receives progress updates and can return false to cancel.
pub fn downloadWithProgress(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
    callback: ProgressCallback,
) !u64 {
    return downloadWithConfig(allocator, url, output_path, Config.default(), callback);
}

/// Download a file with custom configuration and optional progress callback.
pub fn downloadWithConfig(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
    cfg: Config,
    callback: ?ProgressCallback,
) !u64 {
    var c = try Client.init(allocator, cfg);
    defer c.deinit();
    return c.download(url, output_path, callback);
}

/// Get the library version string.
pub fn getVersion() []const u8 {
    return version.version;
}

/// Get the library semantic version.
pub fn getSemanticVersion() std.SemanticVersion {
    return version.semanticVersion();
}

/// Check for library updates in background.
///
/// Returns a thread handle that can be joined, or null if check was skipped.
/// Update information is printed to stderr if available.
pub fn checkForUpdates(allocator: std.mem.Allocator) ?std.Thread {
    return update_checker.checkInBackground(allocator);
}

// Tests

test "public API accessibility" {
    _ = Client;
    _ = Config;
    _ = Progress;
    _ = DownloadError;
    _ = noopCallback;
    _ = stderrCallback;
}

test "version" {
    try std.testing.expectEqualStrings("0.0.1", getVersion());

    const sv = getSemanticVersion();
    try std.testing.expectEqual(@as(usize, 0), sv.major);
    try std.testing.expectEqual(@as(usize, 0), sv.minor);
    try std.testing.expectEqual(@as(usize, 1), sv.patch);
}

test {
    _ = @import("client.zig");
    _ = @import("config.zig");
    _ = @import("progress.zig");
    _ = @import("errors.zig");
    _ = @import("resume.zig");
    _ = @import("retry.zig");
    _ = @import("util.zig");
    _ = @import("version.zig");
    _ = @import("update_checker.zig");
}
