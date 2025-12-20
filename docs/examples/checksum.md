# Checksum Verification

Verify file integrity with cryptographic hashes.

## Overview

Demonstrates:

- SHA-256 verification
- Automatic verification after download
- Handling of `ChecksumMismatch` error

## Running

```bash
zig build run-checksum
```

## Code

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const url = "https://filesamples.com/samples/document/pdf/sample1.pdf";
    const output = "checksum_test.pdf";

    // Expected SHA-256 of the file
    const expected_sha256 = "6b22904a7de5b77bf40598c37e94e01771485e1b900651b58bf50af7009f8056";

    var config = downloader.Config.default();
    config.expected_checksum = expected_sha256;
    config.checksum_algorithm = .sha256;
    config.file_exists_action = .overwrite;

    var client = try downloader.Client.init(allocator, config);
    defer client.deinit();

    std.debug.print("[*] Downloading with SHA-256 verification...\n", .{});

    const bytes = client.download(url, output, null) catch |err| {
        if (err == error.ChecksumMismatch) {
            std.debug.print("\n[!] SECURITY ALERT: Checksum mismatch!\n", .{});
            return;
        }
        return err;
    };

    std.debug.print("[+] Downloaded and verified! ({d} bytes)\n", .{bytes});
}
```

## Supported Algorithms

- `md5`
- `sha1`
- `sha256`
- `sha512`
- `crc32`

## Key Points

1. **Automatic Verification**: The client automatically calculates the hash during streaming download.
2. **Security**: Always use `sha256` or `sha512` for security-sensitive downloads.
3. **Efficiency**: Checksum calculation happens as data is being written, requiring no extra pass over the file.
