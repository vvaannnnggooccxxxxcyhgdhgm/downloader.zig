# Concurrent Example

Parallel downloads with threads.

## Overview

Demonstrates:

- Thread spawning for concurrent downloads
- One Client per thread pattern
- Thread-safe output
- Error collection

## Running

```bash
zig build run-concurrent
```

## Key Pattern

Each thread creates its own Client:

```zig
fn downloadTask(allocator: std.mem.Allocator, task: Task) void {
    // Each thread gets its own client
    var client = downloader.Client.init(allocator, .{}) catch return;
    defer client.deinit();

    _ = client.download(task.url, task.output, null) catch |err| {
        std.debug.print("Failed: {s}\n", .{@errorName(err)});
    };
}
```

## Complete Example

```zig
const std = @import("std");
const downloader = @import("downloader");

const Task = struct {
    url: []const u8,
    output: []const u8,
};

const tasks = [_]Task{
    .{ .url = "https://example.com/file1.pdf", .output = "file1.pdf" },
    .{ .url = "https://example.com/file2.pdf", .output = "file2.pdf" },
    .{ .url = "https://example.com/file3.pdf", .output = "file3.pdf" },
};

var print_mutex = std.Thread.Mutex{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threads: [tasks.len]std.Thread = undefined;

    for (tasks, 0..) |task, i| {
        threads[i] = try std.Thread.spawn(.{}, downloadTask, .{ allocator, task, i });
    }

    for (threads) |t| {
        t.join();
    }

    std.debug.print("All downloads complete\n", .{});
}

fn downloadTask(allocator: std.mem.Allocator, task: Task, id: usize) void {
    var client = downloader.Client.init(allocator, .{
        .file_exists_action = .rename_with_number,
    }) catch |e| {
        threadPrint("[{d}] Init failed: {any}\n", .{id, e});
        return;
    };
    defer client.deinit();

    if (client.download(task.url, task.output, null)) |bytes| {
        threadPrint("[{d}] Done: {d} bytes\n", .{id, bytes});
    } else |err| {
        threadPrint("[{d}] Failed: {s}\n", .{id, @errorName(err)});
    }
}

fn threadPrint(comptime fmt: []const u8, args: anytype) void {
    print_mutex.lock();
    defer print_mutex.unlock();
    std.debug.print(fmt, args);
}
```

## Thread Safety Rules

1. **Create Client per thread** - Clients are not thread-safe
2. **Mutex for output** - Protect shared console output
3. **Shared allocator OK** - `GeneralPurposeAllocator` is thread-safe
4. **Use rename_with_number** - Avoid file conflicts

## Resource Limiting

Limit concurrent downloads:

```zig
const max_concurrent = 4;
var semaphore = std.Thread.Semaphore{ .permits = max_concurrent };

fn limitedDownload(allocator: std.mem.Allocator, task: Task) void {
    semaphore.wait();
    defer semaphore.post();
    // Download...
}
```

## See Also

- [Thread Safety Guide](/guide/thread-safety) - Detailed patterns
- [Concurrent Guide](/guide/concurrent) - More examples
