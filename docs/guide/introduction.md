# Introduction

**downloader.zig** is a production-ready HTTP/HTTPS download library for the [Zig programming language](https://ziglang.org).

## What is downloader.zig?

A lightweight, zero-dependency library that provides:

- **HTTP/HTTPS Downloads** - Full protocol support via `std.http`
- **Resume Capability** - Continue interrupted downloads using Range headers
- **Automatic Retries** - Configurable retry logic with exponential backoff
- **Progress Tracking** - Real-time callbacks with speed and ETA
- **Smart File Handling** - Multiple strategies for existing files

## Key Features

### Zero Dependencies

Built entirely on the Zig standard library. No external C libraries or package dependencies required.

### Cross-Platform

Works on Windows, Linux, macOS, and FreeBSD. Supports both 32-bit and 64-bit architectures.

### Memory Safe

Designed with Zig's safety guarantees. No hidden allocations. All resources are explicitly managed.

### Configurable

Fine-grained control over timeouts, buffer sizes, retry behavior, and file handling.

## Use Cases

- CLI download tools
- Package managers
- Asset downloaders for games
- Automated backup systems
- Update distribution

## Quick Example

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try downloader.download(
        gpa.allocator(),
        "https://example.com/file.zip",
        "file.zip"
    );
}
```

## Next Steps

- [Getting Started](/guide/getting-started) - Installation and first download
- [Configuration](/guide/configuration) - Customize download behavior
- [API Reference](/api/) - Full API documentation
