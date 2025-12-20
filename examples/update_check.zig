const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("[*] Checking for library updates...\n", .{});

    // Option 1: Manual check
    const info = try downloader.checkForUpdates(allocator);

    if (info.available) {
        std.debug.print("\n[!] A newer version of downloader.zig is available!\n", .{});
        std.debug.print("    Current version: {s}\n", .{info.current_version});
        std.debug.print("    Latest version:  {s}\n", .{info.latest_version.?});
        std.debug.print("    Download URL:    {s}\n", .{info.download_url.?});
    } else {
        std.debug.print("\n[+] You are using the latest version ({s}).\n", .{info.current_version});
    }
}
