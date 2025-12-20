//! Progress Tracking and Reporting
//!
//! Provides types and utilities for tracking download progress,
//! calculating speed and ETA, and reporting status to callbacks.

const std = @import("std");

/// Download progress information.
///
/// Passed to progress callbacks with current download statistics.
pub const Progress = struct {
    /// Bytes downloaded in current session.
    bytes_downloaded: u64,
    /// Total file size if known.
    total_bytes: ?u64,
    /// Current download speed in bytes per second.
    bytes_per_second: u64,
    /// Estimated time remaining in seconds.
    eta_seconds: ?u64,
    /// Starting byte offset (non-zero for resumed downloads).
    start_offset: u64,
    /// Whether this is a resumed download.
    is_resumed: bool,
    /// Source URL being downloaded.
    url: []const u8,
    /// Output file path.
    output_path: []const u8,

    /// Calculate download progress as percentage (0.0 to 100.0).
    ///
    /// Returns null if total size is unknown.
    pub fn percentage(self: Progress) ?f64 {
        const total = self.total_bytes orelse return null;
        if (total == 0) return 100.0;
        const downloaded = self.start_offset + self.bytes_downloaded;
        return @as(f64, @floatFromInt(downloaded)) / @as(f64, @floatFromInt(total)) * 100.0;
    }

    /// Total bytes including resumed portion.
    pub fn totalDownloaded(self: Progress) u64 {
        return self.start_offset + self.bytes_downloaded;
    }

    /// Remaining bytes to download.
    ///
    /// Returns null if total size is unknown.
    pub fn remainingBytes(self: Progress) ?u64 {
        const total = self.total_bytes orelse return null;
        const downloaded = self.totalDownloaded();
        return if (downloaded >= total) 0 else total - downloaded;
    }

    /// Format progress for display.
    pub fn format(
        self: Progress,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        if (self.percentage()) |pct| {
            try writer.print("{d:.1}%", .{pct});
        } else {
            try writer.print("{d} bytes", .{self.totalDownloaded()});
        }

        try writer.print(" @ {d} KB/s", .{self.bytes_per_second / 1024});

        if (self.eta_seconds) |eta| {
            const mins = eta / 60;
            const secs = eta % 60;
            try writer.print(" ETA {d}:{d:0>2}", .{ mins, secs });
        }
    }
};

/// Progress callback function type.
///
/// Return true to continue downloading, false to cancel.
pub const ProgressCallback = *const fn (progress: Progress) bool;

/// No-operation callback that always continues.
pub fn noopCallback(_: Progress) bool {
    return true;
}

/// Callback that prints progress to stderr.
pub fn stderrCallback(p: Progress) bool {
    std.debug.print("\r{}", .{p});
    return true;
}

/// Internal progress tracking state.
///
/// Tracks timing and byte counts to calculate speed and ETA.
pub const ProgressTracker = struct {
    start_time: i64,
    last_report_time: i64,
    total_bytes_downloaded: u64,
    last_reported_bytes: u64,
    start_offset: u64,
    total_size: ?u64,

    /// Initialize a new progress tracker.
    pub fn init(start_offset: u64, total_size: ?u64) ProgressTracker {
        const now = std.time.milliTimestamp();
        return .{
            .start_time = now,
            .last_report_time = now,
            .total_bytes_downloaded = 0,
            .last_reported_bytes = 0,
            .start_offset = start_offset,
            .total_size = total_size,
        };
    }

    /// Update with newly downloaded bytes.
    pub fn update(self: *ProgressTracker, bytes: u64) void {
        self.total_bytes_downloaded += bytes;
    }

    /// Calculate current download speed.
    pub fn bytesPerSecond(self: *const ProgressTracker) u64 {
        const elapsed_ms = std.time.milliTimestamp() - self.start_time;
        if (elapsed_ms <= 0) return 0;
        return (self.total_bytes_downloaded * 1000) / @as(u64, @intCast(elapsed_ms));
    }

    /// Calculate estimated time remaining.
    pub fn etaSeconds(self: *const ProgressTracker) ?u64 {
        const total = self.total_size orelse return null;
        const speed = self.bytesPerSecond();
        if (speed == 0) return null;

        const downloaded = self.start_offset + self.total_bytes_downloaded;
        if (downloaded >= total) return 0;

        const remaining = total - downloaded;
        return remaining / speed;
    }

    /// Create a Progress struct with current statistics.
    pub fn progress(self: *const ProgressTracker, url: []const u8, output_path: []const u8) Progress {
        return .{
            .bytes_downloaded = self.total_bytes_downloaded,
            .total_bytes = self.total_size,
            .bytes_per_second = self.bytesPerSecond(),
            .eta_seconds = self.etaSeconds(),
            .start_offset = self.start_offset,
            .is_resumed = self.start_offset > 0,
            .url = url,
            .output_path = output_path,
        };
    }

    /// Check if enough time has passed for a progress report.
    pub fn shouldReport(self: *ProgressTracker, interval_ms: u64) bool {
        const now = std.time.milliTimestamp();
        const elapsed = now - self.last_report_time;
        if (elapsed >= @as(i64, @intCast(interval_ms))) {
            self.last_report_time = now;
            self.last_reported_bytes = self.total_bytes_downloaded;
            return true;
        }
        return false;
    }
};

test "progress percentage" {
    const p = Progress{
        .bytes_downloaded = 50,
        .total_bytes = 100,
        .bytes_per_second = 10,
        .eta_seconds = 5,
        .start_offset = 0,
        .is_resumed = false,
        .url = "",
        .output_path = "",
    };

    const pct = p.percentage().?;
    try std.testing.expect(pct >= 49.9 and pct <= 50.1);
}

test "progress with unknown total" {
    const p = Progress{
        .bytes_downloaded = 50,
        .total_bytes = null,
        .bytes_per_second = 10,
        .eta_seconds = null,
        .start_offset = 0,
        .is_resumed = false,
        .url = "",
        .output_path = "",
    };

    try std.testing.expect(p.percentage() == null);
    try std.testing.expect(p.remainingBytes() == null);
}

test "progress tracker" {
    var tracker = ProgressTracker.init(0, 1000);
    tracker.update(100);
    try std.testing.expect(tracker.total_bytes_downloaded == 100);
}
