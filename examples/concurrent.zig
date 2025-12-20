//! Concurrent download example.
//! Downloads multiple files in parallel using separate threads.

const std = @import("std");
const downloader = @import("downloader");

const DownloadTask = struct {
    url: []const u8,
    output: []const u8,
};

/// Sample files for concurrent download testing
const tasks = [_]DownloadTask{
    .{
        .url = "https://filesamples.com/samples/document/pdf/sample3.pdf",
        .output = "sample3_concurrent.pdf",
    },
    .{
        .url = "https://filesamples.com/samples/document/pdf/sample2.pdf",
        .output = "sample2_concurrent.pdf",
    },
    .{
        .url = "https://filesamples.com/samples/document/pdf/sample1.pdf",
        .output = "sample1_concurrent.pdf",
    },
};

/// Thread-safe progress mutex
var progress_mutex = std.Thread.Mutex{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("             Concurrent Downloads Example                   \n", .{});
    std.debug.print("===========================================================\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("[*] Starting {d} concurrent downloads...\n\n", .{tasks.len});

    // Use a fixed-size array for threads since we know the count
    var threads: [tasks.len]std.Thread = undefined;
    var thread_count: usize = 0;

    // Start all download threads
    for (tasks, 0..) |task, i| {
        std.debug.print("    [{d}] Spawning thread for: {s}\n", .{ i + 1, task.output });
        threads[thread_count] = try std.Thread.spawn(.{}, downloadWorker, .{ allocator, task, i + 1 });
        thread_count += 1;
    }

    std.debug.print("\n[*] Waiting for all downloads to complete...\n\n", .{});

    // Wait for all threads to complete
    for (threads[0..thread_count]) |thread| {
        thread.join();
    }

    std.debug.print("\n[+] All downloads finished!\n\n", .{});

    // Verify downloaded files
    std.debug.print("[*] Verifying downloaded files:\n", .{});
    for (tasks) |task| {
        if (std.fs.cwd().openFile(task.output, .{})) |file| {
            defer file.close();
            const stat = file.stat() catch continue;
            std.debug.print("    + {s}: {d} bytes\n", .{ task.output, stat.size });
        } else |_| {
            std.debug.print("    - {s}: not found\n", .{task.output});
        }
    }
}

fn downloadWorker(allocator: std.mem.Allocator, task: DownloadTask, thread_id: usize) void {
    // Each thread must have its own Client instance (thread safety)
    var client = downloader.Client.init(allocator, .{
        .resume_downloads = true,
        .max_retries = 3,
        .progress_interval_ms = 500,
        .file_exists_action = .rename_with_number, // Safe for concurrent downloads
    }) catch |err| {
        threadSafePrint("    [{d}] Failed to init client: {any}\n", .{ thread_id, err });
        return;
    };
    defer client.deinit();

    // Create thread-specific progress callback
    const result = client.download(task.url, task.output, null);

    if (result) |bytes| {
        threadSafePrint("    [{d}] Completed {s}: {d} bytes\n", .{ thread_id, task.output, bytes });
    } else |err| {
        threadSafePrint("    [{d}] Failed {s}: {any}\n", .{ thread_id, task.output, err });
    }
}

fn threadSafePrint(comptime fmt: []const u8, args: anytype) void {
    progress_mutex.lock();
    defer progress_mutex.unlock();
    std.debug.print(fmt, args);
}
