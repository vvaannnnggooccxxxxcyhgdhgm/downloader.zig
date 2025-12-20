//! Advanced example demonstrating full downloader.zig capabilities.
//!
//! Shows custom headers, file exists actions, and concurrent downloads.

const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const url = "https://httpbin.org/get";
    const output = "headers_test.json";

    // Advanced configuration
    var config = downloader.Config.default();
    config.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0";
    config.authorization = "Bearer my-secret-token";
    config.custom_headers = &.{
        .{ .name = "X-Feature-Enabled", .value = "true" },
        .{ .name = "X-Client-ID", .value = "downloader-zig-v0.0.1" },
    };
    config.follow_redirects = true;
    config.max_redirects = 5;
    config.file_exists_action = .rename_with_number;

    var client = try downloader.Client.init(allocator, config);
    defer client.deinit();

    std.debug.print("[*] Downloading with custom headers...\n", .{});

    const bytes = try client.download(url, output, null);

    std.debug.print("[+] Saved to {s} ({d} bytes)\n", .{ output, bytes });

    // Try again - should trigger rename_with_number
    std.debug.print("[*] Downloading again (should be renamed)...\n", .{});
    const bytes2 = try client.download(url, output, null);
    std.debug.print("[+] Saved again ({d} bytes)\n", .{bytes2});

    // Check for renamed files
    if (std.fs.cwd().openFile("headers_test (1).json", .{})) |file| {
        defer file.close();
        std.debug.print("[+] Verified: headers_test (1).json exists!\n", .{});
    } else |_| {}
}
