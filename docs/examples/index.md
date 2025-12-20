# Examples

Practical examples demonstrating downloader.zig usage.

## Available Examples

| Example                            | Description                       |
| ---------------------------------- | --------------------------------- |
| [Basic](/examples/basic)           | Simple download with progress bar |
| [Advanced](/examples/advanced)     | Full configuration options        |
| [Concurrent](/examples/concurrent) | Parallel downloads with threads   |
| [Resume](/examples/resume)         | Resume interrupted downloads      |

## Running Examples

From the project root:

```bash
# Basic download
zig build run

# With custom URL
zig build run -- https://example.com/file.zip

# Specific examples
zig build run-advanced
zig build run-concurrent
zig build run-resume

# All examples
zig build run-all-examples
```

## Quick Start

### Minimal Download

```zig
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    _ = try downloader.download(
        gpa.allocator(),
        "https://example.com/file.pdf",
        "file.pdf"
    );
}
```

### With Progress

```zig
_ = try downloader.downloadWithProgress(
    allocator,
    url,
    output,
    struct {
        fn callback(p: downloader.Progress) bool {
            if (p.percentage()) |pct| {
                std.debug.print("\r{d:.1}%", .{pct});
            }
            return true;
        }
    }.callback
);
```

### With Configuration

```zig
var client = try downloader.Client.init(allocator, .{
    .max_retries = 5,
    .resume_downloads = true,
    .file_exists_action = .rename_with_number,
});
defer client.deinit();

_ = try client.download(url, output, null);
```

## Common Patterns

### Error Handling

```zig
const result = client.download(url, output, null);
if (result) |bytes| {
    std.debug.print("Downloaded {d} bytes\n", .{bytes});
} else |err| {
    std.debug.print("Failed: {s}\n", .{@errorName(err)});
}
```

### Cancellation

```zig
var cancel_flag = false;

fn callback(p: downloader.Progress) bool {
    _ = p;
    return !cancel_flag;
}
```

### File Naming

```zig
config.file_exists_action = .rename_with_number;
// Creates: file.pdf, file (1).pdf, file (2).pdf, etc.
```
