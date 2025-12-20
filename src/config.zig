//! Download Configuration
//!
//! Provides configuration options for HTTP/HTTPS downloads including
//! retry logic, resume capability, file handling, and request customization.

const std = @import("std");

/// Action to take when the output file already exists.
pub const FileExistsAction = enum {
    /// Rename with number suffix like Windows: file (1).pdf, file (2).pdf
    rename_with_number,
    /// Overwrite the existing file
    overwrite,
    /// Try to resume download, otherwise overwrite
    resume_or_overwrite,
    /// Skip download if file exists
    skip,
    /// Return an error if file exists
    fail,
};

/// Filename resolution strategy.
pub const FilenameStrategy = enum {
    /// Use the provided output path as-is
    use_provided,
    /// Extract filename from URL path
    from_url,
    /// Extract filename from Content-Disposition header if available
    from_content_disposition,
    /// Try Content-Disposition first, then URL, then provided
    auto,
};

/// HTTP request method.
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    HEAD,
    PATCH,
    OPTIONS,
};

/// HTTP header key-value pair.
pub const HttpHeader = struct {
    name: []const u8,
    value: []const u8,
};

/// Download configuration options.
///
/// Controls retry behavior, resume capability, file handling,
/// request headers, and other download parameters.
pub const Config = struct {
    // === Retry Configuration ===

    /// Maximum number of retry attempts (0 = no retries).
    max_retries: u32 = 3,

    /// Delay between retry attempts in milliseconds.
    retry_delay_ms: u64 = 1000,

    /// Whether to use exponential backoff for retries.
    exponential_backoff: bool = true,

    /// Maximum delay between retries in milliseconds.
    max_retry_delay_ms: u64 = 30000,

    // === Connection Configuration ===

    /// Connection timeout in milliseconds.
    connect_timeout_ms: u64 = 30000,

    /// Read timeout in milliseconds (0 = no timeout).
    read_timeout_ms: u64 = 0,

    /// Whether to follow HTTP redirects.
    follow_redirects: bool = true,

    /// Maximum number of redirects to follow.
    max_redirects: u32 = 10,

    // === Buffer Configuration ===

    /// Size of the read buffer in bytes.
    buffer_size: usize = 64 * 1024, // 64 KB

    // === Resume Configuration ===

    /// Whether to attempt resuming interrupted downloads.
    resume_downloads: bool = false,

    // === Progress Configuration ===

    /// Minimum interval between progress reports in milliseconds.
    progress_interval_ms: u64 = 100,

    // === File Handling ===

    /// Action to take when output file already exists.
    file_exists_action: FileExistsAction = .rename_with_number,

    /// Strategy for resolving the output filename.
    filename_strategy: FilenameStrategy = .use_provided,

    /// Whether to create parent directories if they don't exist.
    create_directories: bool = true,

    /// Whether to use temporary file during download (rename on completion).
    use_temp_file: bool = false,

    /// Suffix for temporary files (used when use_temp_file is true).
    temp_suffix: []const u8 = ".download",

    // === Request Configuration ===

    /// HTTP method for the request.
    method: HttpMethod = .GET,

    /// Custom User-Agent header value.
    user_agent: ?[]const u8 = null,

    /// Custom headers to include in the request.
    custom_headers: []const HttpHeader = &.{},

    /// Request body for POST/PUT requests.
    request_body: ?[]const u8 = null,

    /// Content-Type header for request body.
    content_type: ?[]const u8 = null,

    /// Authorization header value (e.g., "Bearer token123").
    authorization: ?[]const u8 = null,

    /// Accept header value.
    accept: ?[]const u8 = null,

    /// Accept-Encoding header value.
    accept_encoding: ?[]const u8 = null,

    /// Referer header value.
    referer: ?[]const u8 = null,

    /// Cookie header value.
    cookie: ?[]const u8 = null,

    // === Range Request Configuration ===

    /// Start byte for range request (null = from beginning).
    range_start: ?u64 = null,

    /// End byte for range request (null = to end).
    range_end: ?u64 = null,

    // === Security Configuration ===

    /// Whether to verify TLS certificates.
    verify_tls: bool = true,

    // === Validation ===

    /// Expected file size for validation (null = don't validate).
    expected_size: ?u64 = null,

    /// Expected checksum for validation (null = don't validate).
    expected_checksum: ?[]const u8 = null,

    /// Checksum algorithm to use.
    checksum_algorithm: ChecksumAlgorithm = .none,

    /// Whether to automatically check for library updates.
    enable_update_check: bool = true,

    /// Default User-Agent string.
    const DEFAULT_USER_AGENT = "DownloaderZig/0.0.1";

    /// Get the User-Agent string to use.
    pub fn getUserAgent(self: *const Config) []const u8 {
        return self.user_agent orelse DEFAULT_USER_AGENT;
    }

    /// Create a default configuration.
    pub fn default() Config {
        return .{};
    }

    /// Create a configuration optimized for large files.
    pub fn forLargeFiles() Config {
        return .{
            .buffer_size = 1024 * 1024, // 1 MB buffer
            .resume_downloads = true,
            .use_temp_file = true,
            .max_retries = 5,
            .exponential_backoff = true,
            .file_exists_action = .resume_or_overwrite,
        };
    }

    /// Create a configuration optimized for small files.
    pub fn forSmallFiles() Config {
        return .{
            .buffer_size = 16 * 1024, // 16 KB buffer
            .resume_downloads = false,
            .use_temp_file = false,
            .max_retries = 2,
        };
    }

    /// Create a configuration for API requests.
    pub fn forApi() Config {
        return .{
            .buffer_size = 8 * 1024, // 8 KB buffer
            .resume_downloads = false,
            .follow_redirects = true,
            .max_retries = 3,
            .connect_timeout_ms = 10000,
        };
    }

    /// Set custom headers from a slice.
    pub fn withHeaders(self: Config, headers: []const HttpHeader) Config {
        var config = self;
        config.custom_headers = headers;
        return config;
    }

    /// Set authorization header.
    pub fn withAuth(self: Config, auth: []const u8) Config {
        var config = self;
        config.authorization = auth;
        return config;
    }

    /// Set User-Agent header.
    pub fn withUserAgent(self: Config, ua: []const u8) Config {
        var config = self;
        config.user_agent = ua;
        return config;
    }

    /// Enable resume with recommended settings.
    pub fn withResume(self: Config) Config {
        var config = self;
        config.resume_downloads = true;
        config.file_exists_action = .resume_or_overwrite;
        return config;
    }

    /// Set byte range for partial download.
    pub fn withRange(self: Config, start: ?u64, end: ?u64) Config {
        var config = self;
        config.range_start = start;
        config.range_end = end;
        return config;
    }

    /// Build Range header value.
    pub fn getRangeHeader(self: *const Config, allocator: std.mem.Allocator) !?[]u8 {
        if (self.range_start == null and self.range_end == null) {
            return null;
        }

        const start = self.range_start orelse 0;
        if (self.range_end) |end| {
            return try std.fmt.allocPrint(allocator, "bytes={d}-{d}", .{ start, end });
        } else {
            return try std.fmt.allocPrint(allocator, "bytes={d}-", .{start});
        }
    }
};

/// Checksum algorithm for file validation.
pub const ChecksumAlgorithm = enum {
    none,
    md5,
    sha1,
    sha256,
    sha512,
    crc32,
};

// Tests
test "default config" {
    const config = Config.default();
    try std.testing.expect(config.max_retries == 3);
    try std.testing.expect(config.buffer_size == 64 * 1024);
    try std.testing.expect(config.follow_redirects == true);
}

test "large file config" {
    const config = Config.forLargeFiles();
    try std.testing.expect(config.buffer_size == 1024 * 1024);
    try std.testing.expect(config.resume_downloads == true);
    try std.testing.expect(config.use_temp_file == true);
}

test "config with headers" {
    const headers = [_]HttpHeader{
        .{ .name = "X-Custom", .value = "test" },
    };
    const config = Config.default().withHeaders(&headers);
    try std.testing.expect(config.custom_headers.len == 1);
}

test "config with auth" {
    const config = Config.default().withAuth("Bearer token123");
    try std.testing.expect(config.authorization != null);
}

test "config with range" {
    const config = Config.default().withRange(1000, 2000);
    try std.testing.expect(config.range_start.? == 1000);
    try std.testing.expect(config.range_end.? == 2000);
}
