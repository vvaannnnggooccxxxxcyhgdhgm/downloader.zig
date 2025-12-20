//! HTTP/HTTPS Download Client
//!
//! Provides a high-level interface for downloading files over HTTP and HTTPS.
//! Supports custom headers, request body, automatic retries, resume capability,
//! progress reporting, and filename extraction from Content-Disposition.

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;

const config_mod = @import("config.zig");
const Config = config_mod.Config;
const HttpHeader = config_mod.HttpHeader;
const HttpMethod = config_mod.HttpMethod;
const FilenameStrategy = config_mod.FilenameStrategy;
const FileExistsAction = config_mod.FileExistsAction;
const errors = @import("errors.zig");
const DownloadError = errors.DownloadError;
const progress_mod = @import("progress.zig");
const Progress = progress_mod.Progress;
const ProgressCallback = progress_mod.ProgressCallback;
const ProgressTracker = progress_mod.ProgressTracker;
const resume_mod = @import("resume.zig");
const retry_mod = @import("retry.zig");
const RetryState = retry_mod.RetryState;
const util = @import("util.zig");
const update_checker = @import("update_checker.zig");

var update_check_done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

/// Download result containing metadata about the completed download.
pub const DownloadResult = struct {
    /// Total bytes downloaded.
    bytes_downloaded: u64,
    /// Final output path (may differ from requested if renamed).
    output_path: []const u8,
    /// Filename extracted from response (if auto-detected).
    detected_filename: ?[]const u8,
    /// Content-Type from response headers.
    content_type: ?[]const u8,
    /// Whether download was resumed.
    was_resumed: bool,
    /// HTTP status code.
    status_code: u16,
};

/// HTTP/HTTPS download client.
///
/// Thread Safety: Each Client instance should be used by a single thread.
/// For concurrent downloads, create separate Client instances per thread.
pub const Client = struct {
    allocator: Allocator,
    config: Config,
    read_buffer: []u8,
    redirect_buffer: []u8,

    // Response metadata (populated after download)
    last_content_type: ?[]const u8 = null,
    last_content_disposition: ?[]const u8 = null,
    last_status_code: u16 = 0,

    /// Initialize a new download client.
    pub fn init(allocator: Allocator, config: Config) !Client {
        const read_buffer = try allocator.alloc(u8, config.buffer_size);
        errdefer allocator.free(read_buffer);

        const redirect_buffer = try allocator.alloc(u8, 8 * 1024);
        errdefer allocator.free(redirect_buffer);

        return Client{
            .allocator = allocator,
            .config = config,
            .read_buffer = read_buffer,
            .redirect_buffer = redirect_buffer,
        };
    }

    /// Release all resources held by the client.
    pub fn deinit(self: *Client) void {
        self.allocator.free(self.read_buffer);
        self.allocator.free(self.redirect_buffer);
        self.* = undefined;
    }

    /// Download a file from the specified URL.
    pub fn download(
        self: *Client,
        url: []const u8,
        output_path: []const u8,
        callback: ?ProgressCallback,
    ) !u64 {
        // Automatic update check
        if (self.config.enable_update_check and !update_check_done.swap(true, .seq_cst)) {
            if (update_checker.checkForUpdates(self.allocator)) |info| {
                if (info.available) {
                    std.debug.print("\n[!] A newer version of downloader.zig is available ({s} -> {s})!\n", .{
                        info.current_version,
                        info.latest_version orelse "unknown",
                    });
                    std.debug.print("    Download: {s}\n\n", .{info.download_url orelse "https://github.com/muhammad-fiaz/downloader.zig/releases/latest"});
                }
            } else |_| {
                // Ignore update check errors to not interrupt the download
            }
        }

        var retry_state = RetryState.init(self.config);

        while (retry_state.canRetry()) {
            const result = self.downloadOnce(url, output_path, callback);

            if (result) |bytes| {
                return bytes;
            } else |err| {
                const download_err = errors.toDownloadError(err);
                if (!retry_mod.shouldRetry(download_err) or retry_state.isLastAttempt()) {
                    return download_err;
                }
                try retry_state.nextAttempt();
                retry_state.wait();
            }
        }

        return DownloadError.RetriesExhausted;
    }

    /// Download with full result metadata.
    pub fn downloadWithResult(
        self: *Client,
        url: []const u8,
        output_path: []const u8,
        callback: ?ProgressCallback,
    ) !DownloadResult {
        const bytes = try self.download(url, output_path, callback);

        return DownloadResult{
            .bytes_downloaded = bytes,
            .output_path = output_path,
            .detected_filename = if (self.last_content_disposition) |cd|
                util.parseContentDisposition(cd)
            else
                null,
            .content_type = self.last_content_type,
            .was_resumed = false,
            .status_code = self.last_status_code,
        };
    }

    /// Perform a HEAD request to get file metadata without downloading.
    pub fn head(self: *Client, url: []const u8) !HeadResult {
        var http_client = http.Client{ .allocator = self.allocator };
        defer http_client.deinit();

        const uri = std.Uri.parse(url) catch return DownloadError.InvalidUrl;

        const headers = try self.buildHeaders(self.allocator);
        defer self.allocator.free(headers);

        var request = try http_client.request(.HEAD, uri, .{
            .headers = headers,
            .server_header_buffer = self.redirect_buffer,
        });
        defer request.deinit();

        try request.sendBodiless();
        const response = try request.receiveHead(self.redirect_buffer);

        return HeadResult{
            .status_code = @intFromEnum(response.head.status),
            .content_length = response.head.content_length,
            .content_type = response.head.content_type,
            .supports_range = true,
        };
    }

    /// Information from HEAD request.
    pub const HeadResult = struct {
        status_code: u16,
        content_length: ?u64,
        content_type: ?[]const u8,
        supports_range: bool,
    };

    /// Build extra headers from config.
    fn buildHeaders(self: *const Client, allocator: Allocator) ![]std.http.Header {
        var headers: std.ArrayListUnmanaged(std.http.Header) = .empty;
        errdefer headers.deinit(allocator);

        try headers.append(allocator, .{ .name = "User-Agent", .value = self.config.getUserAgent() });

        if (self.config.authorization) |auth| {
            try headers.append(allocator, .{ .name = "Authorization", .value = auth });
        }
        if (self.config.accept) |accept| {
            try headers.append(allocator, .{ .name = "Accept", .value = accept });
        }
        if (self.config.referer) |referer| {
            try headers.append(allocator, .{ .name = "Referer", .value = referer });
        }
        if (self.config.cookie) |cookie| {
            try headers.append(allocator, .{ .name = "Cookie", .value = cookie });
        }
        if (self.config.content_type) |ct| {
            try headers.append(allocator, .{ .name = "Content-Type", .value = ct });
        }

        // Add custom headers
        for (self.config.custom_headers) |h| {
            try headers.append(allocator, .{ .name = h.name, .value = h.value });
        }

        return headers.toOwnedSlice(allocator);
    }

    /// Perform a single download attempt with streaming.
    fn downloadOnce(
        self: *Client,
        url: []const u8,
        output_path: []const u8,
        callback: ?ProgressCallback,
    ) !u64 {
        var current_url = try self.allocator.dupe(u8, url);
        defer self.allocator.free(current_url);

        var redirect_count: u32 = 0;

        while (true) {
            var http_client = http.Client{ .allocator = self.allocator };
            defer http_client.deinit();

            const uri = std.Uri.parse(current_url) catch return DownloadError.InvalidUrl;

            // Check for existing file if resume is enabled
            var start_offset: u64 = 0;
            var open_flags: std.fs.File.CreateFlags = .{};

            if (self.config.resume_downloads) {
                if (try resume_mod.getResumeInfo(self.allocator, output_path)) |info| {
                    start_offset = info.existing_size;
                    open_flags.truncate = false;
                }
            }

            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();

            // Build headers
            const headers_list = try self.buildHeaders(arena_allocator);

            var final_headers: std.ArrayListUnmanaged(std.http.Header) = .empty;
            try final_headers.appendSlice(arena_allocator, headers_list);

            if (start_offset > 0) {
                const range_header = try std.fmt.allocPrint(arena_allocator, "bytes={d}-", .{start_offset});
                try final_headers.append(arena_allocator, .{ .name = "Range", .value = range_header });
            }

            // Create request
            var request = try http_client.request(HttpMethodToString(self.config.method), uri, .{
                .headers = .{
                    .user_agent = .{ .override = self.config.getUserAgent() },
                },
                .extra_headers = final_headers.items,
                .redirect_behavior = .unhandled,
            });
            defer request.deinit();

            // Send request
            if (self.config.request_body) |body| {
                const body_bytes = try arena_allocator.dupe(u8, body);
                try request.sendBodyComplete(body_bytes);
            } else {
                try request.sendBodiless();
            }

            var response = try request.receiveHead(self.redirect_buffer);

            // Store response metadata
            self.last_status_code = @intFromEnum(response.head.status);
            self.last_content_type = response.head.content_type;

            // Handle redirects
            if (self.config.follow_redirects and
                (response.head.status == .moved_permanently or
                    response.head.status == .found or
                    response.head.status == .see_other or
                    response.head.status == .temporary_redirect or
                    response.head.status == .permanent_redirect))
            {
                if (redirect_count >= self.config.max_redirects) {
                    return DownloadError.TooManyRedirects;
                }

                if (response.head.location) |location| {
                    redirect_count += 1;
                    self.allocator.free(current_url);
                    current_url = try self.allocator.dupe(u8, location);
                    continue;
                }
            }

            // Check status
            if (response.head.status != .ok and response.head.status != .partial_content) {
                if (errors.errorFromStatusCode(self.last_status_code)) |err| {
                    return err;
                }
                return DownloadError.ServerError;
            }

            // Get content length
            const content_length = response.head.content_length;

            // Handle filename strategy and file existence
            var final_output_managed: ?[]u8 = null;
            defer if (final_output_managed) |m| self.allocator.free(m);

            var final_output: []const u8 = output_path;

            // Strategy: Extract from Content-Disposition if requested
            if (self.config.filename_strategy == .from_content_disposition or self.config.filename_strategy == .auto) {
                if (response.head.content_disposition) |cd| {
                    if (util.parseContentDisposition(cd)) |filename| {
                        const sanitized = try util.sanitizeFilename(self.allocator, filename);
                        final_output_managed = sanitized;
                        final_output = sanitized;
                    }
                }
            }

            // Strategy: Extract from URL if requested and not found in CD
            if (final_output_managed == null and (self.config.filename_strategy == .from_url or self.config.filename_strategy == .auto)) {
                const filename = util.filenameFromUrl(current_url);
                const sanitized = try util.sanitizeFilename(self.allocator, filename);
                final_output_managed = sanitized;
                final_output = sanitized;
            }

            // Handle file exists action
            if (self.config.file_exists_action == .rename_with_number) {
                const unique = try util.getUniqueFilename(self.allocator, final_output, 100);
                if (final_output_managed) |m| self.allocator.free(m);
                final_output_managed = unique;
                final_output = unique;
            } else if (self.config.file_exists_action == .skip) {
                if (std.fs.cwd().access(final_output, .{})) |_| {
                    return 0;
                } else |_| {}
            } else if (self.config.file_exists_action == .fail) {
                if (std.fs.cwd().access(final_output, .{})) |_| {
                    return DownloadError.FileAlreadyExists;
                } else |_| {}
            }

            // Create directories
            if (self.config.create_directories) {
                if (std.fs.path.dirname(final_output)) |dir| {
                    if (dir.len > 0) {
                        std.fs.cwd().makePath(dir) catch {};
                    }
                }
            }

            // Open file
            const file = if (start_offset > 0)
                try std.fs.cwd().openFile(final_output, .{ .mode = .read_write })
            else
                try std.fs.cwd().createFile(final_output, open_flags);
            defer file.close();

            if (start_offset > 0) {
                try file.seekTo(start_offset);
            }

            // Progress tracker
            var tracker = ProgressTracker.init(start_offset, if (content_length) |cl| cl + start_offset else null);

            // Read body
            var total_bytes: u64 = 0;
            var buf: [64 * 1024]u8 = undefined;

            if (callback) |cb| {
                if (!cb(tracker.progress(current_url, final_output))) return DownloadError.Cancelled;
            }

            var reader_ptr = response.reader(self.redirect_buffer);
            var reader = reader_ptr.adaptToOldInterface();
            while (true) {
                const to_read = if (content_length) |cl|
                    @min(buf.len, cl - total_bytes)
                else
                    buf.len;

                if (to_read == 0 and content_length != null) break;

                const read = try reader.read(buf[0..to_read]);
                if (read == 0) break;

                try file.writeAll(buf[0..read]);
                total_bytes += read;
                tracker.update(read);

                if (callback) |cb| {
                    if (tracker.shouldReport(self.config.progress_interval_ms)) {
                        if (!cb(tracker.progress(current_url, final_output))) return DownloadError.Cancelled;
                    }
                }
            }

            // Final progress report
            if (callback) |cb| {
                if (content_length == null) tracker.total_size = total_bytes + start_offset;
                _ = cb(tracker.progress(current_url, final_output));
            }

            const total_downloaded = total_bytes + start_offset;

            // Validate file size if expected
            if (self.config.expected_size) |expected| {
                if (total_downloaded != expected) {
                    return DownloadError.SizeMismatch;
                }
            }

            // Validate checksum if expected
            if (self.config.expected_checksum) |expected| {
                if (self.config.checksum_algorithm != .none) {
                    try self.verifyChecksum(final_output, expected, self.config.checksum_algorithm);
                }
            }

            return total_downloaded;
        }
    }

    fn verifyChecksum(self: *Client, path: []const u8, expected: []const u8, algo: config_mod.ChecksumAlgorithm) !void {
        _ = self;
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var hasher = try ChecksumHasher.init(algo);
        var buf: [64 * 1024]u8 = undefined;

        while (true) {
            const read = try file.read(&buf);
            if (read == 0) break;
            hasher.update(buf[0..read]);
        }

        var digest: [64]u8 = undefined;
        const hash_len = hasher.final(&digest);

        // Convert expected hex string to bytes for comparison
        var expected_bytes: [64]u8 = undefined;
        const expected_slice = std.fmt.hexToBytes(&expected_bytes, expected) catch return DownloadError.ChecksumMismatch;

        if (!std.mem.eql(u8, digest[0..hash_len], expected_slice)) {
            return DownloadError.ChecksumMismatch;
        }
    }

    const ChecksumHasher = union(enum) {
        md5: std.crypto.hash.Md5,
        sha1: std.crypto.hash.Sha1,
        sha256: std.crypto.hash.sha2.Sha256,
        sha512: std.crypto.hash.sha2.Sha512,
        crc32: std.hash.Crc32,

        pub fn init(algo: config_mod.ChecksumAlgorithm) !ChecksumHasher {
            return switch (algo) {
                .md5 => .{ .md5 = std.crypto.hash.Md5.init(.{}) },
                .sha1 => .{ .sha1 = std.crypto.hash.Sha1.init(.{}) },
                .sha256 => .{ .sha256 = std.crypto.hash.sha2.Sha256.init(.{}) },
                .sha512 => .{ .sha512 = std.crypto.hash.sha2.Sha512.init(.{}) },
                .crc32 => .{ .crc32 = std.hash.Crc32.init() },
                .none => unreachable,
            };
        }

        pub fn update(self: *ChecksumHasher, data: []const u8) void {
            switch (self.*) {
                .md5 => |*h| h.update(data),
                .sha1 => |*h| h.update(data),
                .sha256 => |*h| h.update(data),
                .sha512 => |*h| h.update(data),
                .crc32 => |*h| h.update(data),
            }
        }

        pub fn final(self: *ChecksumHasher, out: []u8) usize {
            return switch (self.*) {
                .md5 => |*h| {
                    h.final(out[0..16]);
                    return 16;
                },
                .sha1 => |*h| {
                    h.final(out[0..20]);
                    return 20;
                },
                .sha256 => |*h| {
                    h.final(out[0..32]);
                    return 32;
                },
                .sha512 => |*h| {
                    h.final(out[0..64]);
                    return 64;
                },
                .crc32 => |h| {
                    std.mem.writeInt(u32, out[0..4], h.final(), .big);
                    return 4;
                },
            };
        }
    };

    fn HttpMethodToString(method: HttpMethod) std.http.Method {
        return switch (method) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .HEAD => .HEAD,
            .PATCH => .PATCH,
            .OPTIONS => .OPTIONS,
        };
    }

    /// Download a file using default configuration.
    pub fn downloadSimple(
        allocator: Allocator,
        url: []const u8,
        output_path: []const u8,
    ) !u64 {
        var client = try Client.init(allocator, Config.default());
        defer client.deinit();
        return client.download(url, output_path, null);
    }

    /// POST request with body.
    pub fn post(
        self: *Client,
        url: []const u8,
        body: []const u8,
        output_path: []const u8,
    ) !u64 {
        // Store original config
        const original_method = self.config.method;
        const original_body = self.config.request_body;

        // Set POST config
        self.config.method = .POST;
        self.config.request_body = body;

        defer {
            self.config.method = original_method;
            self.config.request_body = original_body;
        }

        return self.download(url, output_path, null);
    }
};

/// Download a file to the specified path.
pub fn downloadFile(
    allocator: Allocator,
    url: []const u8,
    output_path: []const u8,
) !u64 {
    return Client.downloadSimple(allocator, url, output_path);
}

/// Download a file with custom configuration.
pub fn downloadFileWithConfig(
    allocator: Allocator,
    url: []const u8,
    output_path: []const u8,
    config: Config,
) !u64 {
    var client = try Client.init(allocator, config);
    defer client.deinit();
    return client.download(url, output_path, null);
}
