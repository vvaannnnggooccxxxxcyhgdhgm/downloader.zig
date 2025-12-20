//! HTTP/HTTPS Download Client
//!
//! Provides a high-level interface for downloading files over HTTP and HTTPS.
//! Supports automatic retries, resume capability, and progress reporting.

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;

const config_mod = @import("config.zig");
const Config = config_mod.Config;
const errors = @import("errors.zig");
const DownloadError = errors.DownloadError;
const progress_mod = @import("progress.zig");
const Progress = progress_mod.Progress;
const ProgressCallback = progress_mod.ProgressCallback;
const ProgressTracker = progress_mod.ProgressTracker;
const resume_mod = @import("resume.zig");
const retry_mod = @import("retry.zig");
const RetryState = retry_mod.RetryState;

/// HTTP/HTTPS download client.
///
/// Thread Safety: Each Client instance should be used by a single thread.
/// For concurrent downloads, create separate Client instances per thread.
pub const Client = struct {
    allocator: Allocator,
    config: Config,
    read_buffer: []u8,
    redirect_buffer: []u8,

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
        var retry_state = RetryState.init(self.config);

        while (retry_state.canRetry()) {
            const result = self.downloadOnce(url, output_path, callback);

            if (result) |bytes| {
                return bytes;
            } else |err| {
                if (!retry_mod.shouldRetry(err) or retry_state.isLastAttempt()) {
                    return err;
                }
                try retry_state.nextAttempt();
                retry_state.wait();
            }
        }

        return DownloadError.RetriesExhausted;
    }

    /// Perform a single download attempt with streaming.
    fn downloadOnce(
        self: *Client,
        url: []const u8,
        output_path: []const u8,
        callback: ?ProgressCallback,
    ) !u64 {
        var http_client = http.Client{ .allocator = self.allocator };
        defer http_client.deinit();

        const uri = std.Uri.parse(url) catch return DownloadError.InvalidUrl;

        const user_agent = self.config.getUserAgent();

        // Create request
        var request = http_client.request(.GET, uri, .{
            .extra_headers = &.{
                .{ .name = "User-Agent", .value = user_agent },
            },
        }) catch return DownloadError.ConnectionFailed;
        defer request.deinit();

        // Send request without body (GET request)
        request.sendBodiless() catch return DownloadError.ConnectionFailed;

        // Receive response headers
        var response = request.receiveHead(self.redirect_buffer) catch return DownloadError.ConnectionFailed;

        // Check status
        if (response.head.status != .ok and response.head.status != .partial_content) {
            return DownloadError.ServerError;
        }

        // Get content length for progress tracking
        const content_length = response.head.content_length;

        // Open file for writing
        const file = std.fs.cwd().createFile(output_path, .{}) catch {
            return DownloadError.FileOpenError;
        };
        defer file.close();

        // Initialize progress tracker
        var tracker = ProgressTracker.init(0, content_length);

        // Get response body reader
        var transfer_buffer: [64]u8 = undefined;
        const body_reader = response.reader(&transfer_buffer);

        // Read response body in chunks and write to file
        var total_bytes: u64 = 0;

        // Initial progress report (0%)
        if (callback) |cb| {
            if (!cb(tracker.progress(url, output_path))) {
                return DownloadError.Cancelled;
            }
        }

        while (true) {
            // Read a chunk from the response using readSliceShort
            const bytes_read = body_reader.readSliceShort(self.read_buffer) catch break;
            if (bytes_read == 0) break;

            // Write chunk to file
            file.writeAll(self.read_buffer[0..bytes_read]) catch {
                return DownloadError.FileWriteError;
            };

            total_bytes += bytes_read;
            tracker.update(bytes_read);

            // Report progress at intervals
            if (callback) |cb| {
                if (tracker.shouldReport(self.config.progress_interval_ms)) {
                    if (!cb(tracker.progress(url, output_path))) {
                        return DownloadError.Cancelled;
                    }
                }
            }
        }

        // Final progress report (100%) - always report when complete
        if (callback) |cb| {
            // Force update total size to match downloaded for 100% display
            if (content_length == null) {
                tracker.total_size = total_bytes;
            }
            _ = cb(tracker.progress(url, output_path));
        }

        return total_bytes;
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
};

/// Download a file to the specified path.
pub fn downloadFile(
    allocator: Allocator,
    url: []const u8,
    output_path: []const u8,
) !u64 {
    return Client.downloadSimple(allocator, url, output_path);
}
