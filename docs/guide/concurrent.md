# Concurrent Downloads

Download multiple files in parallel.

## Thread Safety

**Important:** Each thread must have its own `Client` instance. The `Client` struct is not thread-safe.

## Pattern

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threads: [tasks.len]std.Thread = undefined;

    for (tasks, 0..) |task, i| {
        threads[i] = try std.Thread.spawn(.{}, downloadTask, .{ allocator, task });
    }

    for (threads) |t| {
        t.join();
    }
}

fn downloadTask(allocator: std.mem.Allocator, task: Task) void {
    // Each thread gets its own client
    var client = downloader.Client.init(allocator, .{}) catch return;
    defer client.deinit();

    _ = client.download(task.url, task.output, null) catch |err| {
        std.debug.print("Failed: {s}\n", .{@errorName(err)});
    };
}
```

## Thread-Safe Progress

Use a mutex for thread-safe output:

```zig
var print_mutex = std.Thread.Mutex{};

fn threadSafePrint(comptime fmt: []const u8, args: anytype) void {
    print_mutex.lock();
    defer print_mutex.unlock();
    std.debug.print(fmt, args);
}
```

## File Naming

Use `rename_with_number` to avoid conflicts:

```zig
var config = downloader.Config.default();
config.file_exists_action = .rename_with_number;
```

## Resource Limits

Consider limiting concurrent downloads:

```zig
const max_concurrent = 4;
var semaphore = std.Thread.Semaphore{ .permits = max_concurrent };

fn downloadWithLimit(allocator: std.mem.Allocator, task: Task) void {
    semaphore.wait();
    defer semaphore.post();

    // Download...
}
```

## Error Collection

Collect errors from all threads:

```zig
const Result = struct {
    success: bool,
    bytes: u64,
    err: ?anyerror,
};

var results: [tasks.len]Result = undefined;

fn downloadTask(allocator: std.mem.Allocator, task: Task, idx: usize) void {
    var client = downloader.Client.init(allocator, .{}) catch |e| {
        results[idx] = .{ .success = false, .bytes = 0, .err = e };
        return;
    };
    defer client.deinit();

    if (client.download(task.url, task.output, null)) |bytes| {
        results[idx] = .{ .success = true, .bytes = bytes, .err = null };
    } else |err| {
        results[idx] = .{ .success = false, .bytes = 0, .err = err };
    }
}
```

## Next Steps

- [Thread Safety](/guide/thread-safety) - Thread safety details
- [Configuration](/guide/configuration) - All options
