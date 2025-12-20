# Progress Reporting

Track download progress with real-time callbacks.

## Progress Callback

The progress callback receives a `Progress` struct and returns a boolean:

- Return `true` to continue downloading
- Return `false` to cancel

```zig
fn progressCallback(p: downloader.Progress) bool {
    if (p.percentage()) |pct| {
        std.debug.print("\rDownloading: {d:.1}%", .{pct});
    }
    return true;
}

const bytes = try downloader.downloadWithProgress(
    allocator,
    url,
    output,
    progressCallback
);
```

## Progress Information

The `Progress` struct contains:

| Field              | Type   | Description                           |
| ------------------ | ------ | ------------------------------------- |
| `bytes_downloaded` | `u64`  | Bytes downloaded this session         |
| `total_bytes`      | `?u64` | Total file size (null if unknown)     |
| `bytes_per_second` | `u64`  | Current download speed                |
| `eta_seconds`      | `?u64` | Estimated time remaining              |
| `start_offset`     | `u64`  | Resume offset (0 for fresh downloads) |
| `is_resumed`       | `bool` | Whether this is a resumed download    |

### Helper Methods

```zig
// Get percentage (0.0 to 100.0), null if total unknown
const pct: ?f64 = progress.percentage();

// Total bytes including resumed portion
const total: u64 = progress.totalDownloaded();

// Bytes remaining, null if total unknown
const remaining: ?u64 = progress.remainingBytes();
```

## Progress Bar Example

```zig
fn progressBar(p: downloader.Progress) bool {
    const width: u8 = 30;
    const pct = p.percentage() orelse 0;
    const filled = @as(usize, @intFromFloat(pct / 100.0 * @as(f64, width)));

    std.debug.print("\r[", .{});
    for (0..width) |i| {
        if (i < filled) {
            std.debug.print("=", .{});
        } else if (i == filled) {
            std.debug.print(">", .{});
        } else {
            std.debug.print(" ", .{});
        }
    }
    std.debug.print("] {d:.1}%", .{pct});

    return true;
}
```

## Speed and ETA

```zig
fn detailedProgress(p: downloader.Progress) bool {
    const speed_kb = p.bytes_per_second / 1024;

    std.debug.print("\rSpeed: {d} KB/s", .{speed_kb});

    if (p.eta_seconds) |eta| {
        const mins = eta / 60;
        const secs = eta % 60;
        std.debug.print(" | ETA: {d}:{d:0>2}", .{mins, secs});
    }

    return true;
}
```

## Cancellation

Return `false` to cancel:

```zig
var cancelled = false;

fn cancellableCallback(p: downloader.Progress) bool {
    if (cancelled) return false;
    // ... display progress
    return true;
}
```

## Built-in Callbacks

```zig
// Silent - no output
downloader.noopCallback

// Print to stderr
downloader.stderrCallback
```

## Throttling Updates

Configure update frequency:

```zig
var config = downloader.Config.default();
config.progress_interval_ms = 250;  // Max 4 updates per second
```

## Next Steps

- [Resume Downloads](/guide/resume) - Continue interrupted downloads
- [Error Handling](/guide/errors) - Handle download failures
