//! Basic example demonstrating downloader.zig usage.
//!
//! This example shows simple download with customizable progress bar.
//! Uses a sample PDF file for testing.

const std = @import("std");
const downloader = @import("downloader");

/// Sample PDF file for testing downloads
const SAMPLE_URL = "https://filesamples.com/samples/document/pdf/sample3.pdf";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("              downloader.zig v{s}                       \n", .{downloader.getVersion()});
    std.debug.print("         Production-Ready HTTP/HTTPS Downloader            \n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("\n", .{});

    const url = SAMPLE_URL;
    const output_path = "sample.pdf";

    std.debug.print("[*] Download Configuration\n", .{});
    std.debug.print("    URL: {s}\n", .{url});
    std.debug.print("    Output: {s}\n", .{output_path});
    std.debug.print("\n", .{});

    // Download configuration with file handling
    var client = try downloader.Client.init(allocator, .{
        .resume_downloads = true,
        .max_retries = 3,
        .exponential_backoff = true,
        .progress_interval_ms = 100,
        .file_exists_action = .rename_with_number,
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
    const bar_width: usize = 40;
    const pct = prog.percentage() orelse 0;
    const filled = @as(usize, @intFromFloat(pct / 100.0 * @as(f64, @floatFromInt(bar_width))));

    std.debug.print("\r    [", .{});
    for (0..bar_width) |i| {
        if (i < filled) {
            std.debug.print("=", .{});
        } else if (i == filled) {
            std.debug.print(">", .{});
        } else {
            std.debug.print(" ", .{});
        }
    }
    const downloaded = formatBytes(prog.totalDownloaded());
    const speed = formatBytes(prog.bytes_per_second);

    std.debug.print("] {d:5.1}% | {d:.2} {s} | {d:.2} {s}/s", .{
        pct,
        downloaded.value,
        downloaded.unit,
        speed.value,
        speed.unit,
    });

    if (prog.eta_seconds) |eta| {
        std.debug.print(" | ETA: {d}s", .{eta});
    }

    return true; // Continue downloading
}

fn formatBytes(bytes: u64) struct { value: f64, unit: []const u8 } {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var size: f64 = @floatFromInt(bytes);
    var unit_idx: usize = 0;
    while (size >= 1024.0 and unit_idx < units.len - 1) {
        size /= 1024.0;
        unit_idx += 1;
    }
    return .{ .value = size, .unit = units[unit_idx] };
}
