# Thread Safety

Understanding thread safety guarantees.

## Overview

- **Client instances are NOT thread-safe**
- Each thread should create its own Client
- The library uses no global mutable state

## Correct Usage

### One Client Per Thread

```zig
fn downloadThread(allocator: std.mem.Allocator, url: []const u8) void {
    // Create client in the thread
    var client = downloader.Client.init(allocator, .{}) catch return;
    defer client.deinit();

    _ = client.download(url, "output.pdf", null) catch {};
}
```

### Shared Allocator

The allocator can be shared if it's thread-safe:

```zig
// GeneralPurposeAllocator is thread-safe
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Safe to use in multiple threads
_ = try std.Thread.spawn(.{}, downloadThread, .{allocator});
_ = try std.Thread.spawn(.{}, downloadThread, .{allocator});
```

## Incorrect Usage

### Shared Client (DON'T DO THIS)

```zig
// WRONG: Single client shared between threads
var client = try downloader.Client.init(allocator, .{});

// WRONG: Both threads use same client
_ = try std.Thread.spawn(.{}, worker, .{&client});
_ = try std.Thread.spawn(.{}, worker, .{&client});
```

### Shared Progress State

Protect shared state with a mutex:

```zig
var total_bytes: u64 = 0;
var bytes_mutex = std.Thread.Mutex{};

fn updateBytes(bytes: u64) void {
    bytes_mutex.lock();
    defer bytes_mutex.unlock();
    total_bytes += bytes;
}
```

## Recommended Patterns

### Client Pool

For server applications with many downloads:

```zig
const ClientPool = struct {
    clients: []Client,
    available: std.ArrayList(usize),
    mutex: std.Thread.Mutex,

    fn acquire(self: *ClientPool) ?*Client {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.available.popOrNull()) |idx| {
            return &self.clients[idx];
        }
        return null;
    }

    fn release(self: *ClientPool, client: *Client) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const idx = (@intFromPtr(client) - @intFromPtr(&self.clients[0])) / @sizeOf(Client);
        self.available.append(idx) catch {};
    }
};
```

### Worker Pool

```zig
const WorkerPool = struct {
    threads: []std.Thread,
    queue: TaskQueue,

    fn submit(self: *WorkerPool, task: Task) !void {
        try self.queue.push(task);
    }
};
```

## Thread-Safe Operations

These operations are thread-safe:

- `downloader.getVersion()`
- `downloader.getSemanticVersion()`
- Creating new Client instances
- Using separate clients in different threads

## Next Steps

- [Concurrent Downloads](/guide/concurrent) - Parallel download example
- [Configuration](/guide/configuration) - All options
