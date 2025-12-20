//! Resume capability usage example.
//!
//! Demonstrates the download resume functionality with Range headers.

const std = @import("std");
const downloader = @import("downloader");

/// Sample large file for testing resume capability
const SAMPLE_URL = "https://filesamples.com/samples/video/mp4/sample_640x360.mp4";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const output = "resume_test.mp4";

    std.debug.print("\n[*] Resume Capability Demo\n", .{});

    // Step 1: Start a download and cancel it halfway
    std.debug.print("[*] Step 1: Starting download (will cancel at 10%)...\n", .{});
    {
        var config = downloader.Config.default();
        config.file_exists_action = .overwrite;

        var client = try downloader.Client.init(allocator, config);
        defer client.deinit();

        _ = client.download(SAMPLE_URL, output, cancelAtTenPercent) catch |err| {
            if (err == error.Cancelled) {
                std.debug.print("\n[!] Download intentionally cancelled at 10%\n", .{});
            } else {
                return err;
            }
        };
    }

    // Verify partial file exists
    if (std.fs.cwd().openFile(output, .{})) |file| {
        const stat = try file.stat();
        const size = formatBytes(stat.size);
        std.debug.print("[*] Partial file size: {d:.2} {s}\n", .{ size.value, size.unit });
        file.close();
    } else |_| {}

    // Step 2: Resume the download
    std.debug.print("\n[*] Step 2: Resuming download...\n", .{});
    {
        var config = downloader.Config.forLargeFiles();
        config.resume_downloads = true;
        config.file_exists_action = .resume_or_overwrite;

        var client = try downloader.Client.init(allocator, config);
        defer client.deinit();

        const bytes = try client.download(SAMPLE_URL, output, progressCallback);
        std.debug.print("\n[+] Resumed download complete! Total bytes this session: {d}\n", .{bytes});
    }

    // Verify final file
    if (std.fs.cwd().openFile(output, .{})) |file| {
        const stat = try file.stat();
        const size = formatBytes(stat.size);
        std.debug.print("[+] Final file size: {d:.2} {s}\n", .{ size.value, size.unit });
        file.close();
    } else |_| {}
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

fn cancelAtTenPercent(p: downloader.Progress) bool {
    const pct = p.percentage() orelse 0;
    if (pct >= 10.0) return false; // Signal cancel

    std.debug.print("\r    Downloading: {d:.1}%", .{pct});
    return true;
}

fn progressCallback(p: downloader.Progress) bool {
    const pct = p.percentage() orelse 0;
    const downloaded = formatBytes(p.totalDownloaded());
    std.debug.print("\r    Resuming: {d:.1}% ({d:.2} {s} downloaded)", .{ pct, downloaded.value, downloaded.unit });
    return true;
}
