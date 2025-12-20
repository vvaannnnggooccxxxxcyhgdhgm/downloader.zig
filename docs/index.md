---
layout: home

hero:
  name: downloader.zig
  text: High-Performance HTTP/HTTPS Downloads
  tagline: A production-ready Zig library for downloading files with streaming, progress, resume, and retry support.
  image:
    src: /logo.svg
    alt: downloader.zig
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/downloader.zig

features:
  - icon: 🌐
    title: HTTP & HTTPS Support
    details: Full support for HTTP/1.1 and HTTPS via std.http with TLS verification.
  - icon: 🌊
    title: Streaming Downloads
    details: Stream data directly to disk with minimal memory overhead using configurable buffers.
  - icon: ⏯️
    title: Resume Support
    details: Automatically resume paused or interrupted downloads using HTTP Range headers.
  - icon: 📊
    title: Progress Reporting
    details: Real-time progress callbacks with speed, ETA, percentage, and customizable progress bars.
  - icon: 🔄
    title: Smart Retries
    details: Configurable retry policies with exponential backoff and jitter for robust downloads.
  - icon: 📁
    title: Smart File Handling
    details: Auto-rename files like Windows (1), (2), skip existing, overwrite, or fail.
  - icon: ⚡
    title: High Performance
    details: Optimized for speed with configurable buffer sizes and minimal allocations.
  - icon: 📦
    title: Zero Dependencies
    details: Built using only the Zig standard library - no external dependencies required.
---

## Quick Start

Add to your `build.zig.zon`:

```bash
zig fetch --save https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz
```

Then use in your code:

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Simple one-liner download
    try downloader.download(
        allocator,
        "https://example.com/file.zip",
        "file.zip"
    );
}
```

## Why downloader.zig?

| Feature           | downloader.zig | curl bindings | Custom HTTP |
| ----------------- | -------------- | ------------- | ----------- |
| Pure Zig          | ✅             | ❌            | ✅          |
| No Dependencies   | ✅             | ❌            | ✅          |
| Resume Support    | ✅             | Manual        | Manual      |
| Progress Callback | ✅             | ✅            | Manual      |
| Retry Logic       | ✅ Built-in    | Manual        | Manual      |
| Smart File Naming | ✅ (1), (2)    | ❌            | Manual      |
| Thread Safe       | ✅ Per-client  | Varies        | Manual      |

## Supported Platforms

| Platform         | Architectures                           | Status          |
| ---------------- | --------------------------------------- | --------------- |
| **Windows**      | x86_64 (64-bit), x86 (32-bit)           | ✅ Full support |
| **Linux**        | x86_64, x86, aarch64, arm, riscv64      | ✅ Full support |
| **macOS**        | x86_64 (Intel), aarch64 (Apple Silicon) | ✅ Full support |
| **FreeBSD**      | x86_64                                  | ✅ Full support |
| **Freestanding** | Various                                 | ⚠️ Build only   |

## Sponsors

If you find this library useful, please consider [sponsoring](https://github.com/sponsors/muhammad-fiaz)!

<div style="text-align: center; margin-top: 2rem;">
  <a href="https://github.com/sponsors/muhammad-fiaz" style="display: inline-block; padding: 0.75rem 1.5rem; background: linear-gradient(135deg, #ea4aaa, #f78166); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">
    💖 Become a Sponsor
  </a>
</div>
