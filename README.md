# downloader.zig

[![CI](https://github.com/muhammad-fiaz/downloader.zig/actions/workflows/ci.yml/badge.svg)](https://github.com/muhammad-fiaz/downloader.zig/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready HTTP/HTTPS download library for [Zig](https://ziglang.org).

## Features

- **HTTP/HTTPS Support** - Full protocol support via `std.http`
- **Automatic Retries** - Configurable retry logic with exponential backoff
- **Resume Capability** - Continue interrupted downloads using Range headers
- **Progress Tracking** - Real-time callbacks with speed and ETA
- **Smart File Handling** - Multiple strategies for existing files (`FileExistsAction`)
- **Thread Safety** - One client per thread pattern for concurrent downloads
- **Zero Dependencies** - Built entirely on the Zig standard library
- **Cross-Platform** - Windows, Linux, macOS (32-bit and 64-bit)

## Requirements

- Zig 0.15.0 or later

## Installation

### Using zig fetch

```bash
zig fetch --save https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz
```

### Manual

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .downloader = .{
        .url = "https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz",
        .hash = "...", // Run zig fetch to get the hash
    },
},
```

Then in `build.zig`:

```zig
const downloader = b.dependency("downloader", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("downloader", downloader.module("downloader"));
```

## Quick Start

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const bytes = try downloader.download(
        gpa.allocator(),
        "https://example.com/file.pdf",
        "file.pdf"
    );

    std.debug.print("Downloaded {d} bytes\n", .{bytes});
}
```

## Configuration

```zig
var config = downloader.Config.default();

// Retry settings
config.max_retries = 5;
config.retry_delay_ms = 1000;
config.exponential_backoff = true;

// Resume and file handling
config.resume_downloads = true;
config.file_exists_action = .rename_with_number; // Creates file (1), file (2), etc.

// Custom User-Agent
config.user_agent = "MyApp/1.0";

var client = try downloader.Client.init(allocator, config);
defer client.deinit();
```

## FileExistsAction

Control behavior when the output file already exists:

| Value                  | Description                                           |
| ---------------------- | ----------------------------------------------------- |
| `.rename_with_number`  | Create `file (1).ext`, `file (2).ext`, etc. (default) |
| `.overwrite`           | Replace existing file                                 |
| `.resume_or_overwrite` | Try resume, otherwise overwrite                       |
| `.skip`                | Don't download if file exists                         |
| `.fail`                | Return error if file exists                           |

## Progress Callback

```zig
fn progressCallback(p: downloader.Progress) bool {
    if (p.percentage()) |pct| {
        std.debug.print("\rProgress: {d:.1}%", .{pct});
    }
    return true; // Return false to cancel
}

const bytes = try client.download(url, output, progressCallback);
```

## Concurrent Downloads

Each thread must create its own Client:

```zig
fn downloadTask(allocator: std.mem.Allocator, url: []const u8) void {
    var client = downloader.Client.init(allocator, .{}) catch return;
    defer client.deinit();

    _ = client.download(url, "output.pdf", null) catch {};
}
```

## Examples

```bash
# Basic download
zig build run

# Advanced configuration
zig build run-advanced

# Concurrent downloads
zig build run-concurrent

# Resume capability
zig build run-resume
```

## Documentation

Full documentation available at: https://muhammad-fiaz.github.io/downloader.zig/

## Platform Support

| Platform | 32-bit | 64-bit |
| -------- | ------ | ------ |
| Windows  | ✅     | ✅     |
| Linux    | ✅     | ✅     |
| macOS    | ✅     | ✅     |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please read the contributing guidelines before submitting PRs.

## Author

[Muhammad Fiaz](https://github.com/muhammad-fiaz)
