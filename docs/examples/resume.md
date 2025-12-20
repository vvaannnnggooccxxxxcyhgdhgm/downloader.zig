# Resume Example

Resume interrupted downloads.

## Overview

Demonstrates:

- Resume configuration
- Detecting resumed downloads
- Fallback to fresh download
- File exists handling

## Running

```bash
zig build run-resume
```

## Configuration

```zig
var config = downloader.Config.default();
config.resume_downloads = true;
config.file_exists_action = .resume_or_overwrite;
```

## Detecting Resume

Check `is_resumed` in progress callback:

```zig
fn progressCallback(p: downloader.Progress) bool {
    if (p.is_resumed) {
        std.debug.print("Resuming from byte {d}\n", .{p.start_offset});
    }
    // Show progress...
    return true;
}
```

## Example

```zig
const std = @import("std");
const downloader = @import("downloader");

const url = "https://example.com/large-file.iso";
const output = "large-file.iso";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var config = downloader.Config.default();
    config.resume_downloads = true;
    config.file_exists_action = .resume_or_overwrite;

    var client = try downloader.Client.init(gpa.allocator(), config);
    defer client.deinit();

    const bytes = client.download(url, output, progressCallback) catch |err| {
        if (err == error.ResumeNotSupported) {
            std.debug.print("Server doesn't support resume\n", .{});
            return tryFreshDownload(gpa.allocator());
        }
        return err;
    };

    std.debug.print("\nDownloaded {d} bytes this session\n", .{bytes});
}

fn progressCallback(p: downloader.Progress) bool {
    const pct = p.percentage() orelse 0;

    if (p.is_resumed and p.start_offset > 0) {
        std.debug.print("\rResuming: {d:.1}%", .{pct});
    } else {
        std.debug.print("\rDownloading: {d:.1}%", .{pct});
    }

    return true;
}

fn tryFreshDownload(allocator: std.mem.Allocator) !void {
    std.fs.cwd().deleteFile(output) catch {};

    var config = downloader.Config.noResume();
    var client = try downloader.Client.init(allocator, config);
    defer client.deinit();

    _ = try client.download(url, output, progressCallback);
}
```

## How Resume Works

1. Checks for existing partial file
2. Sends HEAD request to verify server support
3. If supported, sends GET with `Range` header
4. Server responds with `206 Partial Content`
5. Download continues from last byte

## Requirements

- Server must support Range requests
- Partial file must exist on disk
- File must not have changed on server

## Fallback Behavior

When resume fails:

- **Server doesn't support**: Start fresh
- **File modified**: Start fresh
- **Partial deleted**: Start fresh

## See Also

- [Resume Guide](/guide/resume) - Detailed explanation
- [Configuration](/guide/configuration) - FileExistsAction options
