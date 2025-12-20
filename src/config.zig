//! Download Configuration
//!
//! Provides configuration options for controlling download behavior including
//! retry policies, timeouts, buffer sizes, and file handling strategies.
//!
//! ## Example
//! ```zig
//! var config = Config.default();
//! config.max_retries = 5;
//! config.resume_downloads = true;
//! ```

const std = @import("std");

/// Strategy for handling existing files during download.
pub const FileExistsAction = enum {
    /// Replace the existing file.
    overwrite,
    /// Attempt resume if possible, otherwise overwrite.
    resume_or_overwrite,
    /// Skip download if file already exists and is complete.
    skip,
    /// Create a new file with numeric suffix: file (1).ext, file (2).ext, etc.
    rename_with_number,
    /// Return an error if the file exists.
    fail,
};

/// Configuration options for download operations.
///
/// All fields have sensible defaults. Configuration is immutable
/// once a Client is initialized.
pub const Config = struct {
    // Retry settings

    /// Maximum retry attempts for transient failures (0 = no retries).
    max_retries: u32 = 3,
    /// Base delay between retry attempts in milliseconds.
    retry_delay_ms: u64 = 1000,
    /// Maximum retry delay cap in milliseconds.
    max_retry_delay_ms: u64 = 30000,
    /// Use exponential backoff for retry delays.
    exponential_backoff: bool = true,

    // Connection settings

    /// Connection timeout in milliseconds (0 = no timeout).
    connect_timeout_ms: u64 = 30000,
    /// Read timeout in milliseconds (0 = no timeout).
    read_timeout_ms: u64 = 60000,

    // File handling

    /// Attempt to resume partial downloads using Range headers.
    resume_downloads: bool = true,
    /// Strategy for handling existing files.
    file_exists_action: FileExistsAction = .rename_with_number,
    /// Legacy: overwrite existing files (use file_exists_action instead).
    overwrite_existing: bool = false,

    // Performance

    /// Download buffer size in bytes.
    buffer_size: usize = 64 * 1024,
    /// Maximum HTTP redirects to follow (0 = disable redirects).
    max_redirects: u16 = 10,

    // Identity

    /// Custom User-Agent header (null = use library default).
    user_agent: ?[]const u8 = null,
    /// Verify TLS certificates (disable only for testing).
    verify_tls: bool = true,

    // Progress reporting

    /// Minimum bytes between progress callbacks (0 = every chunk).
    progress_interval_bytes: usize = 0,
    /// Minimum milliseconds between progress callbacks.
    progress_interval_ms: u64 = 100,

    /// Create configuration with default values.
    pub fn default() Config {
        return .{};
    }

    /// Configuration optimized for large file downloads.
    pub fn forLargeFiles() Config {
        return .{
            .buffer_size = 256 * 1024,
            .max_retries = 5,
            .retry_delay_ms = 2000,
            .max_retry_delay_ms = 60000,
            .read_timeout_ms = 120000,
            .progress_interval_bytes = 1024 * 1024,
        };
    }

    /// Configuration optimized for small file downloads.
    pub fn forSmallFiles() Config {
        return .{
            .buffer_size = 16 * 1024,
            .max_retries = 2,
            .retry_delay_ms = 500,
            .max_retry_delay_ms = 5000,
            .progress_interval_bytes = 0,
        };
    }

    /// Configuration with resume disabled.
    pub fn noResume() Config {
        return .{
            .resume_downloads = false,
            .overwrite_existing = true,
            .file_exists_action = .overwrite,
        };
    }

    /// Configuration with retries disabled.
    pub fn noRetries() Config {
        return .{
            .max_retries = 0,
        };
    }

    /// Get the effective User-Agent string.
    pub fn getUserAgent(self: Config) []const u8 {
        const version = @import("version.zig");
        const default_agent = "downloader.zig/" ++ version.version;
        return self.user_agent orelse default_agent;
    }

    /// Validate configuration values.
    pub fn validate(self: Config) !void {
        if (self.buffer_size == 0) {
            return error.InvalidBufferSize;
        }
        if (self.buffer_size > 16 * 1024 * 1024) {
            return error.BufferSizeTooLarge;
        }
    }
};

/// Configuration validation errors.
pub const ConfigError = error{
    InvalidBufferSize,
    BufferSizeTooLarge,
};

test "default configuration" {
    const config = Config.default();
    try std.testing.expect(config.max_retries == 3);
    try std.testing.expect(config.resume_downloads == true);
    try std.testing.expect(config.buffer_size == 64 * 1024);
    try std.testing.expect(config.file_exists_action == .rename_with_number);
}

test "large files configuration" {
    const config = Config.forLargeFiles();
    try std.testing.expect(config.buffer_size == 256 * 1024);
    try std.testing.expect(config.max_retries == 5);
}

test "configuration validation" {
    const valid = Config.default();
    try valid.validate();

    var invalid = Config.default();
    invalid.buffer_size = 0;
    try std.testing.expectError(error.InvalidBufferSize, invalid.validate());
}

test "user agent generation" {
    const config = Config.default();
    const agent = config.getUserAgent();
    try std.testing.expect(std.mem.startsWith(u8, agent, "downloader.zig/"));
}
