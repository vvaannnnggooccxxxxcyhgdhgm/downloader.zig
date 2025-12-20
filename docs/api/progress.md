# Progress API

Progress tracking and reporting.

## Progress Type

```zig
pub const Progress = struct {
    bytes_downloaded: u64,     // Bytes this session
    total_bytes: ?u64,         // Total size (null if unknown)
    bytes_per_second: u64,     // Current speed
    eta_seconds: ?u64,         // Time remaining
    start_offset: u64,         // Resume offset
    is_resumed: bool,          // Whether resumed
    url: []const u8,           // Source URL
    output_path: []const u8,   // Output file
};
```

## Methods

### `percentage`

```zig
pub fn percentage(self: Progress) ?f64
```

Returns download percentage (0.0 to 100.0), or null if total unknown.

### `totalDownloaded`

```zig
pub fn totalDownloaded(self: Progress) u64
```

Returns total bytes including resume offset.

### `remainingBytes`

```zig
pub fn remainingBytes(self: Progress) ?u64
```

Returns remaining bytes, or null if total unknown.

## ProgressCallback

```zig
pub const ProgressCallback = *const fn (progress: Progress) bool;
```

Return `true` to continue, `false` to cancel.

## Built-in Callbacks

### `noopCallback`

```zig
pub fn noopCallback(_: Progress) bool
```

Silent callback that always continues.

### `stderrCallback`

```zig
pub fn stderrCallback(p: Progress) bool
```

Prints progress to stderr.

## ProgressTracker

Internal tracking state for calculating speed and ETA.

```zig
pub const ProgressTracker = struct {
    start_time: i64,
    last_report_time: i64,
    total_bytes_downloaded: u64,
    last_reported_bytes: u64,
    start_offset: u64,
    total_size: ?u64,
};
```

### Constructor

```zig
pub fn init(start_offset: u64, total_size: ?u64) ProgressTracker
```

### Methods

```zig
pub fn update(self: *ProgressTracker, bytes: u64) void
pub fn bytesPerSecond(self: *const ProgressTracker) u64
pub fn etaSeconds(self: *const ProgressTracker) ?u64
pub fn progress(self: *const ProgressTracker, url: []const u8, output_path: []const u8) Progress
pub fn shouldReport(self: *ProgressTracker, interval_ms: u64) bool
```

## Example

```zig
fn progressCallback(p: downloader.Progress) bool {
    if (p.percentage()) |pct| {
        std.debug.print("\r{d:.1}%", .{pct});
    } else {
        std.debug.print("\r{d} bytes", .{p.totalDownloaded()});
    }

    std.debug.print(" @ {d} KB/s", .{p.bytes_per_second / 1024});

    if (p.eta_seconds) |eta| {
        std.debug.print(" ETA: {d}:{d:0>2}", .{eta / 60, eta % 60});
    }

    return true; // Continue
}
```

## See Also

- [Progress Guide](/guide/progress) - Usage examples
- [Client](/api/client) - Using callbacks
