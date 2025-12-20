# Update Checker

Check for library updates against the project repository.

## Automatic Update Checking

By default, `downloader.zig` automatically checks for updates during the first download in a process.

If a new version is found, a message is printed to `stderr`:

```text
[!] A newer version of downloader.zig is available (0.0.1 -> 0.1.0)!
    Download: https://github.com/muhammad-fiaz/downloader.zig/releases/latest
```

### Disabling Auto-Check

To disable this behavior, set `enable_update_check` to `false` in your configuration:

```zig
var config = downloader.Config.default();
config.enable_update_check = false;
```

## Manual Check Example

You can also trigger a check manually at any time using `checkForUpdates`.

### Running the Example

```bash
zig build run-update_check
```

### Code

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("[*] Checking for library updates...\n", .{});

    // Check for updates (fetches from GitHub API)
    const info = try downloader.checkForUpdates(allocator);

    if (info.available) {
        std.debug.print("\n[!] A newer version of downloader.zig is available!\n", .{});
        std.debug.print("    Current version: {s}\n", .{info.current_version});
        std.debug.print("    Latest version:  {s}\n", .{info.latest_version.?});
        std.debug.print("    Download URL:    {s}\n", .{info.download_url.?});
    } else {
        std.debug.print("\n[+] You are using the latest version ({s}).\n", .{info.current_version});
    }
}
```

## Features

1. **GitHub API**: Uses GitHub's releases API to fetch the latest version.
2. **Semantic Versioning**: Automatically compares versions using semantic versioning rules.
3. **Download URL**: Provides the direct path to the latest release assets.

## Implementation Details

The `checkForUpdates` function:

- Sends a GET request to GitHub with a custom User-Agent.
- Parses the JSON response to find `tag_name`.
- Compares it with `downloader.version`.
- Uses `std.atomic.Value` to ensure it only runs once when triggered automatically.
