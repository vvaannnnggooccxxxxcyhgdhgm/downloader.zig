# Advanced Example

Full configuration and progress styles.

## Overview

Demonstrates:

- All configuration options
- Multiple progress bar styles
- FileExistsAction options
- Configuration validation

## Running

```bash
zig build run-advanced
```

## Configuration

```zig
var config = downloader.Config.default();

// Retry settings
config.max_retries = 5;
config.retry_delay_ms = 500;
config.max_retry_delay_ms = 30000;
config.exponential_backoff = true;

// Connection settings
config.connect_timeout_ms = 30000;
config.read_timeout_ms = 60000;

// File handling
config.resume_downloads = true;
config.file_exists_action = .rename_with_number;

// Performance
config.buffer_size = 64 * 1024;

// Identity
config.user_agent = "MyDownloader/1.0";

// TLS
config.verify_tls = true;

// Progress
config.progress_interval_ms = 100;
```

## FileExistsAction Options

```zig
// Create file (1), file (2), etc.
config.file_exists_action = .rename_with_number;

// Replace existing file
config.file_exists_action = .overwrite;

// Try resume, otherwise overwrite
config.file_exists_action = .resume_or_overwrite;

// Skip if exists
config.file_exists_action = .skip;

// Error if exists
config.file_exists_action = .fail;
```

## Progress Styles

### Bar Style

```zig
fn barProgress(p: downloader.Progress) bool {
    const pct = p.percentage() orelse 0;
    const width: u8 = 40;
    const filled = @as(usize, @intFromFloat(pct / 100.0 * @as(f64, width)));

    std.debug.print("\r[", .{});
    for (0..width) |i| {
        if (i < filled) std.debug.print("#", .{}) else std.debug.print("-", .{});
    }
    std.debug.print("] {d:.1}%", .{pct});
    return true;
}
```

### Detailed Style

```zig
fn detailedProgress(p: downloader.Progress) bool {
    const pct = p.percentage() orelse 0;
    const speed_kb = p.bytes_per_second / 1024;

    std.debug.print("\r{d:.1}% | {d} KB/s", .{pct, speed_kb});

    if (p.eta_seconds) |eta| {
        std.debug.print(" | ETA: {d}:{d:0>2}", .{eta / 60, eta % 60});
    }
    return true;
}
```

## Complete Example

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var config = downloader.Config.default();
    config.max_retries = 5;
    config.resume_downloads = true;
    config.file_exists_action = .rename_with_number;
    config.user_agent = "AdvancedExample/1.0";

    try config.validate();

    var client = try downloader.Client.init(gpa.allocator(), config);
    defer client.deinit();

    const bytes = try client.download(url, output, progressCallback);
    std.debug.print("\nComplete: {d} bytes\n", .{bytes});
}
```

## See Also

- [Configuration Guide](/guide/configuration) - All options
- [Config API](/api/config) - API reference
