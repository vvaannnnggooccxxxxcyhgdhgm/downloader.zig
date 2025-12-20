# Basic Example

Simple download with progress bar.

## Overview

Demonstrates:

- Basic download setup
- Customizable progress bar
- Command-line arguments
- File handling

## Running

```bash
# Default sample file
zig build run

# Custom URL
zig build run -- https://example.com/file.zip output.zip
```

## Code

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const url = if (args.len >= 2) args[1] else "https://example.com/sample.pdf";
    const output = if (args.len >= 3) args[2] else "sample.pdf";

    // Configure client
    var client = try downloader.Client.init(allocator, .{
        .resume_downloads = true,
        .max_retries = 3,
        .file_exists_action = .rename_with_number,
    });
    defer client.deinit();

    // Download with progress
    const bytes = try client.download(url, output, progressCallback);
    std.debug.print("\nDownloaded {d} bytes\n", .{bytes});
}

fn progressCallback(p: downloader.Progress) bool {
    const pct = p.percentage() orelse 0;
    const width: u8 = 30;
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

## Key Points

1. **Allocator**: Use `GeneralPurposeAllocator` for applications
2. **Client Lifecycle**: Always `deinit()` the client
3. **Progress Callback**: Return `true` to continue, `false` to cancel
4. **File Handling**: `rename_with_number` creates `file (1).pdf` if exists

## Output

```
[========================>     ] 85.2%
Downloaded 1234567 bytes
```

## See Also

- [Advanced Example](/examples/advanced) - More configuration options
- [Progress Guide](/guide/progress) - Progress customization
