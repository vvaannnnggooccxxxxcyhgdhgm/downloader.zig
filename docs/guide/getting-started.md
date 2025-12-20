# Getting Started

This guide covers installation and your first download.

## Prerequisites

- Zig 0.15.0 or later
- A project with `build.zig` and `build.zig.zon`

## Installation

### Using zig fetch (Recommended)

```bash
zig fetch --save https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz
```

This updates your `build.zig.zon` automatically.

### Manual Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .downloader = .{
        .url = "https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz",
        .hash = "...", // Run zig fetch to get the hash
    },
},
```

Then update `build.zig`:

```zig
const downloader = b.dependency("downloader", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("downloader", downloader.module("downloader"));
```

## Your First Download

Create a simple download program:

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const bytes = try downloader.download(
        allocator,
        "https://example.com/file.pdf",
        "file.pdf"
    );

    std.debug.print("Downloaded {d} bytes\n", .{bytes});
}
```

## Download with Progress

Track download progress with a callback:

```zig
const bytes = try downloader.downloadWithProgress(
    allocator,
    "https://example.com/large-file.zip",
    "large-file.zip",
    progressCallback
);

fn progressCallback(p: downloader.Progress) bool {
    if (p.percentage()) |pct| {
        std.debug.print("\rProgress: {d:.1}%", .{pct});
    }
    return true; // Continue downloading
}
```

## Download with Configuration

Customize download behavior:

```zig
var config = downloader.Config.default();
config.max_retries = 5;
config.resume_downloads = true;
config.file_exists_action = .rename_with_number;

var client = try downloader.Client.init(allocator, config);
defer client.deinit();

const bytes = try client.download(url, output, null);
```

## Verify Installation

```zig
const version = downloader.getVersion();
std.debug.print("downloader.zig v{s}\n", .{version});
```

Expected output:

```
downloader.zig v0.0.1
```

## Next Steps

- [Installation Details](/guide/installation) - More installation options
- [Configuration](/guide/configuration) - All configuration options
- [Progress Reporting](/guide/progress) - Advanced progress tracking
