//! Concurrent downloads example.
//!
//! Demonstrates how to run multiple downloads in parallel using threads.

const std = @import("std");
const downloader = @import("downloader");

const DownloadTask = struct {
    url: []const u8,
    output: []const u8,
    allocator: std.mem.Allocator,

    pub fn run(self: *const DownloadTask) void {
        var client = downloader.Client.init(self.allocator, downloader.Config.default()) catch return;
        defer client.deinit();

        _ = client.download(self.url, self.output, null) catch |err| {
            std.debug.print("[!] Error downloading {s}: {s}\n", .{ self.url, @errorName(err) });
            return;
        };

        std.debug.print("[+] Finished: {s} -> {s}\n", .{ self.url, self.output });
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const tasks = [_]DownloadTask{
        .{ .url = "https://filesamples.com/samples/document/pdf/sample1.pdf", .output = "sample1.pdf", .allocator = allocator },
        .{ .url = "https://filesamples.com/samples/document/pdf/sample2.pdf", .output = "sample2.pdf", .allocator = allocator },
        .{ .url = "https://filesamples.com/samples/document/pdf/sample3.pdf", .output = "sample3.pdf", .allocator = allocator },
    };

    std.debug.print("[*] Starting {d} concurrent downloads...\n", .{tasks.len});

    var threads: std.ArrayList(std.Thread) = .empty;
    defer threads.deinit(allocator);

    for (&tasks) |*task| {
        const thread = try std.Thread.spawn(.{}, DownloadTask.run, .{task});
        try threads.append(allocator, thread);
    }

    for (threads.items) |thread| {
        thread.join();
    }

    std.debug.print("\n[+] All concurrent downloads finished!\n", .{});
}
