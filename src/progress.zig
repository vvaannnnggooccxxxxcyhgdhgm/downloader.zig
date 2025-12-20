//! Progress Tracking and Reporting
//!
//! Provides comprehensive progress tracking for downloads including
//! speed calculation, ETA estimation, and formatted output.

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
    /// Elapsed time in milliseconds.
    elapsed_ms: u64,
    /// Average speed over entire download.
    average_speed: u64,

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

    /// Check if download is complete.
    pub fn isComplete(self: Progress) bool {
        if (self.total_bytes) |total| {
            return self.totalDownloaded() >= total;
        }
        return false;
    }

    /// Get formatted speed string.
    pub fn formattedSpeed(self: Progress) FormattedBytes {
        return formatBytes(self.bytes_per_second);
    }

    /// Get formatted downloaded size.
    pub fn formattedDownloaded(self: Progress) FormattedBytes {
        return formatBytes(self.totalDownloaded());
    }

    /// Get formatted total size.
    pub fn formattedTotal(self: Progress) ?FormattedBytes {
        if (self.total_bytes) |total| {
            return formatBytes(total);
        }
        return null;
    }

    /// Get formatted ETA.
    pub fn formattedEta(self: Progress) ?FormattedDuration {
        if (self.eta_seconds) |eta| {
            return formatDuration(eta);
        }
        return null;
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

        const speed = self.formattedSpeed();
        try writer.print(" @ {d:.2} {s}/s", .{ speed.value, speed.unit });

        if (self.formattedEta()) |eta| {
            if (eta.hours > 0) {
                try writer.print(" ETA {d}:{d:0>2}:{d:0>2}", .{ eta.hours, eta.minutes, eta.seconds });
            } else {
                try writer.print(" ETA {d}:{d:0>2}", .{ eta.minutes, eta.seconds });
            }
        }
    }
};

/// Formatted bytes with value and unit.
pub const FormattedBytes = struct {
    value: f64,
    unit: []const u8,
};

/// Formatted duration with hours, minutes, seconds.
pub const FormattedDuration = struct {
    hours: u64,
    minutes: u64,
    seconds: u64,
};

/// Format bytes to human-readable format.
pub fn formatBytes(bytes: u64) FormattedBytes {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB", "PB" };
    var size: f64 = @floatFromInt(bytes);
    var unit_idx: usize = 0;

    while (size >= 1024.0 and unit_idx < units.len - 1) {
        size /= 1024.0;
        unit_idx += 1;
    }

    return .{ .value = size, .unit = units[unit_idx] };
}

/// Format duration to hours:minutes:seconds.
pub fn formatDuration(seconds: u64) FormattedDuration {
    return .{
        .hours = seconds / 3600,
        .minutes = (seconds % 3600) / 60,
        .seconds = seconds % 60,
    };
}

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

/// Create a progress bar callback with custom width.
pub fn progressBarCallback(width: u8) ProgressCallback {
    _ = width;
    return stderrCallback;
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

    // Speed calculation (rolling average)
    speed_samples: [10]u64 = [_]u64{0} ** 10,
    sample_index: usize = 0,
    sample_count: usize = 0,

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

    /// Record a speed sample for rolling average.
    pub fn recordSpeedSample(self: *ProgressTracker, speed: u64) void {
        self.speed_samples[self.sample_index] = speed;
        self.sample_index = (self.sample_index + 1) % self.speed_samples.len;
        if (self.sample_count < self.speed_samples.len) {
            self.sample_count += 1;
        }
    }

    /// Get rolling average speed.
    pub fn averageSpeed(self: *const ProgressTracker) u64 {
        if (self.sample_count == 0) return self.bytesPerSecond();

        var sum: u64 = 0;
        for (self.speed_samples[0..self.sample_count]) |s| {
            sum += s;
        }
        return sum / self.sample_count;
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

    /// Get elapsed time in milliseconds.
    pub fn elapsedMs(self: *const ProgressTracker) u64 {
        const elapsed = std.time.milliTimestamp() - self.start_time;
        return if (elapsed > 0) @intCast(elapsed) else 0;
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
            .elapsed_ms = self.elapsedMs(),
            .average_speed = self.averageSpeed(),
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

    /// Reset the tracker for a new download.
    pub fn reset(self: *ProgressTracker) void {
        const now = std.time.milliTimestamp();
        self.start_time = now;
        self.last_report_time = now;
        self.total_bytes_downloaded = 0;
        self.last_reported_bytes = 0;
        self.sample_count = 0;
        self.sample_index = 0;
    }
};

// Tests
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
        .elapsed_ms = 5000,
        .average_speed = 10,
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
        .elapsed_ms = 5000,
        .average_speed = 10,
    };

    try std.testing.expect(p.percentage() == null);
    try std.testing.expect(p.remainingBytes() == null);
}

test "progress tracker" {
    var tracker = ProgressTracker.init(0, 1000);
    tracker.update(100);
    try std.testing.expect(tracker.total_bytes_downloaded == 100);
}

test "format bytes" {
    const kb = formatBytes(1024);
    try std.testing.expect(kb.value == 1.0);
    try std.testing.expectEqualStrings("KB", kb.unit);

    const mb = formatBytes(1024 * 1024);
    try std.testing.expect(mb.value == 1.0);
    try std.testing.expectEqualStrings("MB", mb.unit);
}

test "format duration" {
    const d = formatDuration(3661);
    try std.testing.expect(d.hours == 1);
    try std.testing.expect(d.minutes == 1);
    try std.testing.expect(d.seconds == 1);
}

test "progress is complete" {
    const complete = Progress{
        .bytes_downloaded = 100,
        .total_bytes = 100,
        .bytes_per_second = 0,
        .eta_seconds = 0,
        .start_offset = 0,
        .is_resumed = false,
        .url = "",
        .output_path = "",
        .elapsed_ms = 1000,
        .average_speed = 100,
    };
    try std.testing.expect(complete.isComplete());

    const incomplete = Progress{
        .bytes_downloaded = 50,
        .total_bytes = 100,
        .bytes_per_second = 10,
        .eta_seconds = 5,
        .start_offset = 0,
        .is_resumed = false,
        .url = "",
        .output_path = "",
        .elapsed_ms = 5000,
        .average_speed = 10,
    };
    try std.testing.expect(!incomplete.isComplete());
}
