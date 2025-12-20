//! Advanced example with custom configuration.
//!
//! Demonstrates all configuration options including:
//! - FileExistsAction for handling existing files
//! - Customizable progress bar styles
//! - Retry and timeout settings

const std = @import("std");
const downloader = @import("downloader");

/// Sample PDF file for testing downloads
const SAMPLE_URL = "https://filesamples.com/samples/document/pdf/sample3.pdf";

/// Different progress bar styles
const ProgressStyle = enum {
    bar,
    percentage_only,
    bytes_only,
    minimal,
    detailed,
};

var current_style: ProgressStyle = .detailed;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("           Advanced Configuration Example                   \n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("\n", .{});

    const output = "sample3.pdf";

    std.debug.print("[*] Configuration Details\n", .{});
    std.debug.print("    URL: {s}\n", .{SAMPLE_URL});
    std.debug.print("    Output: {s}\n", .{output});
    std.debug.print("\n", .{});

    // Custom configuration showcasing all options
    var config = downloader.Config.default();

    // Retry settings
    config.max_retries = 5;
    config.retry_delay_ms = 500;
    config.max_retry_delay_ms = 30000;
    config.exponential_backoff = true;

    // Connection settings
    config.connect_timeout_ms = 30000;
    config.read_timeout_ms = 60000;

    // Resume and file handling
    config.resume_downloads = true;

    // File exists handling options:
    // - .overwrite: Replace existing file
    // - .resume_or_overwrite: Try resume, else overwrite
    // - .skip: Don't download if file exists
    // - .rename_with_number: Create file (1), file (2), etc.
    // - .fail: Return error if file exists
    config.file_exists_action = .rename_with_number;

    // Buffer and performance
    config.buffer_size = 64 * 1024; // 64KB buffer

    // Custom identifiers
    config.user_agent = "DownloaderZig-Advanced/1.0";

    // TLS settings
    config.verify_tls = true;

    // Progress reporting
    config.progress_interval_ms = 100;

    std.debug.print("[*] Applied Configuration:\n", .{});
    std.debug.print("    - Max Retries: {d}\n", .{config.max_retries});
    std.debug.print("    - Retry Delay: {d}ms (exponential: {s})\n", .{ config.retry_delay_ms, if (config.exponential_backoff) "yes" else "no" });
    std.debug.print("    - Connect Timeout: {d}ms\n", .{config.connect_timeout_ms});
    std.debug.print("    - Buffer Size: {d}KB\n", .{config.buffer_size / 1024});
    std.debug.print("    - Resume Downloads: {s}\n", .{if (config.resume_downloads) "enabled" else "disabled"});
    std.debug.print("    - File Exists Action: {s}\n", .{@tagName(config.file_exists_action)});
    std.debug.print("    - TLS Verification: {s}\n", .{if (config.verify_tls) "enabled" else "disabled"});
    std.debug.print("    - User-Agent: {s}\n", .{config.getUserAgent()});
    std.debug.print("\n", .{});

    // Demonstrate different progress styles
    std.debug.print("[*] Progress Style: {s}\n", .{@tagName(current_style)});
    std.debug.print("\n", .{});

    var client = try downloader.Client.init(allocator, config);
    defer client.deinit();

    std.debug.print("[*] Starting download...\n", .{});

    const bytes = client.download(SAMPLE_URL, output, progressCallback) catch |err| {
        std.debug.print("\n[!] Download failed: {s}\n", .{@errorName(err)});
        return err;
    };

    std.debug.print("\n\n[+] Download complete: {d} bytes\n", .{bytes});

    // Verify file exists
    if (std.fs.cwd().openFile(output, .{})) |file| {
        defer file.close();
        const stat = try file.stat();
        std.debug.print("[*] File verified: {d} bytes on disk\n", .{stat.size});
    } else |_| {
        std.debug.print("[!] Could not verify file\n", .{});
    }
}

fn progressCallback(p: downloader.Progress) bool {
    switch (current_style) {
        .bar => {
            drawProgressBar(p.percentage() orelse 0, 40);
        },
        .percentage_only => {
            const pct = p.percentage() orelse 0;
            std.debug.print("\r    {d:.1}%", .{pct});
        },
        .bytes_only => {
            std.debug.print("\r    {s} downloaded", .{formatBytes(p.totalDownloaded())});
        },
        .minimal => {
            const pct = p.percentage() orelse 0;
            std.debug.print("\r    {d:.0}%", .{pct});
        },
        .detailed => {
            drawDetailedProgress(p);
        },
    }
    return true;
}

fn drawProgressBar(pct: f64, width: u8) void {
    const filled = @as(usize, @intFromFloat(pct / 100.0 * @as(f64, @floatFromInt(width))));

    std.debug.print("\r    [", .{});
    for (0..width) |i| {
        if (i < filled) {
            std.debug.print("#", .{});
        } else {
            std.debug.print("-", .{});
        }
    }
    std.debug.print("] {d:.1}%", .{pct});
}

fn drawDetailedProgress(p: downloader.Progress) void {
    const pct = p.percentage() orelse 0;
    const speed = formatBytes(p.bytes_per_second);
    const downloaded = formatBytes(p.totalDownloaded());

    var eta_buf: [32]u8 = undefined;
    const eta = if (p.eta_seconds) |e|
        std.fmt.bufPrint(&eta_buf, "{d}:{d:0>2}", .{ e / 60, e % 60 }) catch "??:??"
    else
        "??:??";

    std.debug.print("\r    ", .{});

    // Mini bar
    const bar_width: u8 = 20;
    const filled = @as(usize, @intFromFloat(pct / 100.0 * @as(f64, @floatFromInt(bar_width))));

    std.debug.print("[", .{});
    for (0..bar_width) |i| {
        if (i < filled) {
            std.debug.print("=", .{});
        } else if (i == filled) {
            std.debug.print(">", .{});
        } else {
            std.debug.print(" ", .{});
        }
    }
    std.debug.print("] {d:5.1}% | {s} | {s}/s | ETA: {s}    ", .{ pct, downloaded, speed, eta });
}

fn formatBytes(bytes: u64) []const u8 {
    const S = struct {
        var buf: [32]u8 = undefined;
    };

    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var size: f64 = @floatFromInt(bytes);
    var unit_idx: usize = 0;

    while (size >= 1024.0 and unit_idx < units.len - 1) {
        size /= 1024.0;
        unit_idx += 1;
    }

    return std.fmt.bufPrint(&S.buf, "{d:.2} {s}", .{ size, units[unit_idx] }) catch "???";
}
