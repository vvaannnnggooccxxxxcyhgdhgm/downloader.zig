//! Downloader.zig - Production-Ready HTTP/HTTPS Download Library
//!
//! A high-performance, feature-rich download library for Zig providing:
//! - HTTP/HTTPS support via std.http.Client
//! - Automatic retries with exponential backoff
//! - Resume capability using Range requests
//! - Progress tracking with speed and ETA
//! - Custom headers, authentication, and cookies
//! - Filename extraction from Content-Disposition
//! - Smart file handling (rename, overwrite, skip)
//! - Thread-safe design for concurrent downloads
//!
//! ## Quick Start
//!
//! ```zig
//! const downloader = @import("downloader");
//!
//! const bytes = try downloader.download(
//!     allocator,
//!     "https://example.com/file.pdf",
//!     "file.pdf"
//! );
//! ```

const std = @import("std");

// === Core Modules ===

/// HTTP/HTTPS download client.
pub const client = @import("client.zig");
pub const Client = client.Client;
pub const DownloadResult = client.DownloadResult;

/// Download configuration options.
pub const config = @import("config.zig");
pub const Config = config.Config;
pub const FileExistsAction = config.FileExistsAction;
pub const FilenameStrategy = config.FilenameStrategy;
pub const HttpMethod = config.HttpMethod;
pub const HttpHeader = config.HttpHeader;
pub const ChecksumAlgorithm = config.ChecksumAlgorithm;

/// Error types for download operations.
pub const errors = @import("errors.zig");
pub const DownloadError = errors.DownloadError;
pub const StatusCategory = errors.StatusCategory;
pub const errorFromStatusCode = errors.errorFromStatusCode;
pub const errorDescription = errors.errorDescription;
pub const isRetryable = errors.isRetryable;
pub const isNetworkError = errors.isNetworkError;
pub const isFileError = errors.isFileError;

/// Progress tracking and reporting.
pub const progress = @import("progress.zig");
pub const Progress = progress.Progress;
pub const ProgressCallback = progress.ProgressCallback;
pub const ProgressTracker = progress.ProgressTracker;
pub const FormattedBytes = progress.FormattedBytes;
pub const FormattedDuration = progress.FormattedDuration;
pub const formatBytes = progress.formatBytes;
pub const formatDuration = progress.formatDuration;
pub const noopCallback = progress.noopCallback;
pub const stderrCallback = progress.stderrCallback;

/// Resume download support.
pub const resume_mod = @import("resume.zig");
pub const ResumeInfo = resume_mod.ResumeInfo;
pub const ResumeState = resume_mod.ResumeState;
pub const ResumeMetadata = resume_mod.ResumeMetadata;
pub const getResumeInfo = resume_mod.getResumeInfo;
pub const supportsRangeRequests = resume_mod.supportsRangeRequests;
pub const validateResume = resume_mod.validateResume;

/// Retry logic and backoff strategies.
pub const retry = @import("retry.zig");
pub const RetryState = retry.RetryState;
pub const RetryStats = retry.RetryStats;
pub const BackoffStrategy = retry.BackoffStrategy;
pub const CircuitBreaker = retry.CircuitBreaker;
pub const shouldRetry = retry.shouldRetry;
pub const delayForError = retry.delayForError;

/// Utility functions.
pub const util = @import("util.zig");
pub const filenameFromUrl = util.filenameFromUrl;
pub const parseContentDisposition = util.parseContentDisposition;
pub const sanitizeFilename = util.sanitizeFilename;
pub const getExtension = util.getExtension;
pub const joinPath = util.joinPath;
pub const isHttps = util.isHttps;
pub const isValidHttpUrl = util.isValidHttpUrl;
pub const getHost = util.getHost;
pub const getUniqueFilename = util.getUniqueFilename;

/// Version information.
pub const version = @import("version.zig");
pub const getVersion = version.getVersion;
pub const getVersionInfo = version.getVersionInfo;

/// Update checker.
pub const update_checker = @import("update_checker.zig");
pub const checkForUpdates = update_checker.checkForUpdates;

// === Convenience Functions ===

/// Download a file from URL to the specified path.
///
/// This is the simplest way to download a file with default settings.
///
/// Example:
/// ```zig
/// const bytes = try downloader.download(allocator, url, "output.pdf");
/// ```
pub fn download(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
) !u64 {
    return client.downloadFile(allocator, url, output_path);
}

/// Download a file with custom configuration.
///
/// Example:
/// ```zig
/// const bytes = try downloader.downloadWithConfig(
///     allocator,
///     url,
///     "output.pdf",
///     .{ .max_retries = 5, .resume_downloads = true },
/// );
/// ```
pub fn downloadWithConfig(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
    cfg: Config,
) !u64 {
    return client.downloadFileWithConfig(allocator, url, output_path, cfg);
}

/// Download a file with progress callback.
///
/// Example:
/// ```zig
/// const bytes = try downloader.downloadWithProgress(
///     allocator,
///     url,
///     "output.pdf",
///     progressCallback,
/// );
/// ```
pub fn downloadWithProgress(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_path: []const u8,
    callback: ProgressCallback,
) !u64 {
    var c = try Client.init(allocator, Config.default());
    defer c.deinit();
    return c.download(url, output_path, callback);
}

/// Create a configured download client.
///
/// Use this for multiple downloads with the same configuration.
///
/// Example:
/// ```zig
/// var downloader = try downloader.createClient(allocator, .{
///     .max_retries = 5,
///     .resume_downloads = true,
/// });
/// defer downloader.deinit();
///
/// try downloader.download(url1, "file1.pdf", null);
/// try downloader.download(url2, "file2.pdf", null);
/// ```
pub fn createClient(allocator: std.mem.Allocator, cfg: Config) !Client {
    return Client.init(allocator, cfg);
}

// === Library Information ===

/// Library name.
pub const name = "downloader.zig";

/// Library description.
pub const description = "Production-ready HTTP/HTTPS download library for Zig";

/// Minimum supported Zig version.
pub const min_zig_version = "0.15.0";

/// Check if current Zig version is supported.
pub fn isZigVersionSupported() bool {
    const zig_version = @import("builtin").zig_version;
    return zig_version.major > 0 or (zig_version.major == 0 and zig_version.minor >= 15);
}

// === Tests ===

test "version info" {
    const ver = getVersion();
    try std.testing.expect(ver.len > 0);
    try std.testing.expectEqualStrings("0.0.1", ver);
}

test "library info" {
    try std.testing.expectEqualStrings("downloader.zig", name);
    try std.testing.expect(isZigVersionSupported());
}

test "config default" {
    const cfg = Config.default();
    try std.testing.expect(cfg.max_retries == 3);
    try std.testing.expect(cfg.follow_redirects == true);
}

test "config presets" {
    const large = Config.forLargeFiles();
    try std.testing.expect(large.buffer_size == 1024 * 1024);
    try std.testing.expect(large.resume_downloads == true);

    const small = Config.forSmallFiles();
    try std.testing.expect(small.buffer_size == 16 * 1024);

    const api = Config.forApi();
    try std.testing.expect(api.connect_timeout_ms == 10000);
}

test "error utilities" {
    try std.testing.expect(isRetryable(DownloadError.ConnectionTimeout));
    try std.testing.expect(!isRetryable(DownloadError.NotFound));
    try std.testing.expect(isNetworkError(DownloadError.ConnectionFailed));
    try std.testing.expect(isFileError(DownloadError.DiskFull));
}

test "progress formatting" {
    const bytes = formatBytes(1024 * 1024);
    try std.testing.expect(bytes.value == 1.0);
    try std.testing.expectEqualStrings("MB", bytes.unit);

    const dur = formatDuration(3661);
    try std.testing.expect(dur.hours == 1);
    try std.testing.expect(dur.minutes == 1);
    try std.testing.expect(dur.seconds == 1);
}

test "url utilities" {
    try std.testing.expect(isHttps("https://example.com"));
    try std.testing.expect(!isHttps("http://example.com"));
    try std.testing.expect(isValidHttpUrl("https://example.com"));
    try std.testing.expect(isValidHttpUrl("http://example.com"));
    try std.testing.expect(!isValidHttpUrl("ftp://example.com"));
}

test "filename utilities" {
    try std.testing.expectEqualStrings(
        "file.pdf",
        filenameFromUrl("https://example.com/path/file.pdf"),
    );

    try std.testing.expectEqualStrings(
        "pdf",
        getExtension("file.pdf").?,
    );
}

test {
    // Reference all test modules
    _ = client;
    _ = config;
    _ = errors;
    _ = progress;
    _ = resume_mod;
    _ = retry;
    _ = util;
    _ = version;
    _ = update_checker;
}
