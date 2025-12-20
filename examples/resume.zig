//! Resume capability usage example.
//!
//! Demonstrates the download resume functionality with Range headers.

const std = @import("std");
const downloader = @import("downloader");

/// Sample PDF file for testing resume capability
const SAMPLE_URL = "https://filesamples.com/samples/document/pdf/sample3.pdf";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const output = "resume_test.pdf";

    std.debug.print("\n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("               Resume Capability Demo                       \n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("\n", .{});

    // Step 1: Create a partial file to simulate an interrupted download
    std.debug.print("[*] Step 1: Simulating interrupted download\n", .{});
    {
        const file = try std.fs.cwd().createFile(output, .{});
        defer file.close();

        // Write some placeholder data (simulating partial download)
        const partial_data = "%PDF-1.4 (partial download simulation)\n";
        try file.writeAll(partial_data);

        std.debug.print("    Created partial file: {s}\n", .{output});
        std.debug.print("    Partial size: {d} bytes\n", .{partial_data.len});
    }

    // Step 2: Attempt to resume download
    std.debug.print("\n[*] Step 2: Attempting to resume download\n", .{});
    std.debug.print("    URL: {s}\n", .{SAMPLE_URL});
    std.debug.print("\n", .{});

    // Configuration with resume enabled
    var config = downloader.Config.default();
    config.resume_downloads = true;
    config.file_exists_action = .resume_or_overwrite; // Try resume, if not possible overwrite

    var client = try downloader.Client.init(allocator, config);
    defer client.deinit();

    const bytes = client.download(SAMPLE_URL, output, progressCallback) catch |err| {
        std.debug.print("\n[!] Download failed: {s}\n", .{@errorName(err)});

        // If resume failed, try fresh download
        if (err == error.ResumeNotSupported or err == error.FileModified) {
            std.debug.print("\n[*] Resume not supported, trying fresh download...\n", .{});

            // Delete partial file
            std.fs.cwd().deleteFile(output) catch {};

            var fresh_config = downloader.Config.default();
            fresh_config.resume_downloads = false;
            fresh_config.file_exists_action = .overwrite;

            var fresh_client = try downloader.Client.init(allocator, fresh_config);
            defer fresh_client.deinit();

            const fresh_bytes = try fresh_client.download(SAMPLE_URL, output, progressCallback);
            std.debug.print("\n[+] Fresh download complete: {d} bytes\n", .{fresh_bytes});
            return;
        }

        return err;
    };

    std.debug.print("\n\n[+] Download complete!\n", .{});
    std.debug.print("    Bytes downloaded this session: {d}\n", .{bytes});

    // Verify final file
    if (std.fs.cwd().openFile(output, .{})) |file| {
        defer file.close();
        const stat = try file.stat();
        std.debug.print("    Final file size: {d} bytes\n", .{stat.size});
    } else |_| {}
}

fn progressCallback(p: downloader.Progress) bool {
    if (p.is_resumed) {
        std.debug.print("\r    [*] Resuming from byte {d}...", .{p.start_offset});
    } else {
        // Draw progress bar
        const pct = p.percentage() orelse 0;
        const bar_width: u8 = 30;
        const filled = @as(usize, @intFromFloat(pct / 100.0 * @as(f64, @floatFromInt(bar_width))));

        std.debug.print("\r    [", .{});
        for (0..bar_width) |i| {
            if (i < filled) {
                std.debug.print("#", .{});
            } else {
                std.debug.print("-", .{});
            }
        }
        std.debug.print("] {d:.1}% | {d} bytes", .{ pct, p.totalDownloaded() });
    }
    return true;
}
