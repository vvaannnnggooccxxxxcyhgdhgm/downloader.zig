//! Basic example demonstrating downloader.zig usage.
//!
//! This example shows simple download with customizable progress bar.
//! Uses a sample PDF file for testing.

const std = @import("std");
const downloader = @import("downloader");

/// Sample PDF file for testing downloads
const SAMPLE_URL = "https://filesamples.com/samples/document/pdf/sample3.pdf";

/// Progress bar configuration
const ProgressBarConfig = struct {
    /// Width of the progress bar in characters
    bar_width: u8 = 30,
    /// Character for filled portion of bar (using ASCII)
    filled_char: u8 = '=',
    /// Character for empty portion of bar (using ASCII)
    empty_char: u8 = '-',
    /// Character for current position
    current_char: u8 = '>',
    /// Show download speed
    show_speed: bool = true,
    /// Show ETA
    show_eta: bool = true,
    /// Show percentage
    show_percentage: bool = true,
    /// Show downloaded bytes
    show_bytes: bool = true,
};

var progress_config = ProgressBarConfig{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Check for updates (optional, runs in background)
    const update_thread = downloader.checkForUpdates(allocator);
    defer if (update_thread) |t| t.join();

    std.debug.print("\n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("              downloader.zig v{s}                       \n", .{downloader.getVersion()});
    std.debug.print("         Production-Ready HTTP/HTTPS Downloader            \n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("\n", .{});

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const url = if (args.len >= 2) args[1] else SAMPLE_URL;
    const output_path = if (args.len >= 3) args[2] else getFilename(url);

    std.debug.print("[*] Download Configuration\n", .{});
    std.debug.print("    URL: {s}\n", .{url});
    std.debug.print("    Output: {s}\n", .{output_path});
    std.debug.print("\n", .{});

    // Configure progress bar (customize these!)
    progress_config = .{
        .bar_width = 40,
        .filled_char = '=',
        .empty_char = ' ',
        .current_char = '>',
        .show_speed = true,
        .show_eta = true,
        .show_percentage = true,
        .show_bytes = true,
    };

    // Download configuration with file handling
    var client = try downloader.Client.init(allocator, .{
        .resume_downloads = true,
        .max_retries = 3,
        .exponential_backoff = true,
        .buffer_size = 128 * 1024, // 128 KB buffer
        .progress_interval_ms = 100,
        .file_exists_action = .rename_with_number, // Like Windows: file (1).pdf, file (2).pdf
    });
    defer client.deinit();

    std.debug.print("[*] Starting download...\n", .{});

    // Download with progress reporting
    const bytes = client.download(url, output_path, progressCallback) catch |err| {
        std.debug.print("\n[!] Download failed: {s}\n", .{@errorName(err)});
        return err;
    };

    std.debug.print("\n\n[+] Download complete!\n", .{});
    std.debug.print("    Total bytes: {d}\n", .{bytes});
    std.debug.print("    Saved to: {s}\n", .{output_path});
}

fn progressCallback(prog: downloader.Progress) bool {
    const cfg = progress_config;

    // Calculate filled portion
    const pct = prog.percentage() orelse 0;
    const filled = @as(usize, @intFromFloat(pct / 100.0 * @as(f64, @floatFromInt(cfg.bar_width))));

    // Build output string
    std.debug.print("\r    ", .{});

    // Progress bar
    std.debug.print("[", .{});
    for (0..cfg.bar_width) |i| {
        if (i < filled) {
            std.debug.print("{c}", .{cfg.filled_char});
        } else if (i == filled) {
            std.debug.print("{c}", .{cfg.current_char});
        } else {
            std.debug.print("{c}", .{cfg.empty_char});
        }
    }
    std.debug.print("]", .{});

    // Percentage
    if (cfg.show_percentage) {
        std.debug.print(" {d:5.1}%", .{pct});
    }

    // Downloaded bytes
    if (cfg.show_bytes) {
        std.debug.print(" | {s}", .{formatBytes(prog.totalDownloaded())});
    }

    // Speed
    if (cfg.show_speed) {
        std.debug.print(" @ {s}/s", .{formatBytes(prog.bytes_per_second)});
    }

    // ETA
    if (cfg.show_eta) {
        if (prog.eta_seconds) |eta| {
            std.debug.print(" ETA: {s}", .{formatDuration(eta)});
        }
    }

    std.debug.print("          ", .{}); // Clear trailing chars

    return true; // Continue downloading
}

fn getFilename(url: []const u8) []const u8 {
    // Find the last slash
    var last_slash: usize = 0;
    for (url, 0..) |c, i| {
        if (c == '/') last_slash = i + 1;
    }

    const filename = url[last_slash..];
    if (filename.len == 0) return "download";

    // Remove query string
    for (filename, 0..) |c, i| {
        if (c == '?') return filename[0..i];
    }

    return filename;
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

fn formatDuration(seconds: u64) []const u8 {
    const S = struct {
        var buf: [32]u8 = undefined;
    };

    const hours = seconds / 3600;
    const mins = (seconds % 3600) / 60;
    const secs = seconds % 60;

    return if (hours > 0)
        std.fmt.bufPrint(&S.buf, "{d}:{d:0>2}:{d:0>2}", .{ hours, mins, secs }) catch "??:??:??"
    else
        std.fmt.bufPrint(&S.buf, "{d}:{d:0>2}", .{ mins, secs }) catch "??:??";
}
