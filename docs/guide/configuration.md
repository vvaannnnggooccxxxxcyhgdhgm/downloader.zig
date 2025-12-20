# Configuration

downloader.zig provides extensive configuration options to customize download behavior.

## Config Struct

All options are set via the `Config` struct:

```zig
const downloader = @import("downloader");

var config = downloader.Config.default();
config.max_retries = 5;
config.resume_downloads = true;
config.file_exists_action = .rename_with_number;

var client = try downloader.Client.init(allocator, config);
```

## Configuration Options

### Update Checking

| Option                | Type   | Default | Description                                  |
| --------------------- | ------ | ------- | -------------------------------------------- |
| `enable_update_check` | `bool` | true    | Automatically check for library updates once |

By default, the library checks for updates from the GitHub repository at the start of the first download in a process. You can disable this by setting `enable_update_check` to `false`.

```zig
var config = downloader.Config.default();
config.enable_update_check = false; // Disable auto-check
```

### Retry Settings

| Option                | Type   | Default | Description                                   |
| --------------------- | ------ | ------- | --------------------------------------------- |
| `max_retries`         | `u32`  | 3       | Maximum retry attempts for transient failures |
| `retry_delay_ms`      | `u64`  | 1000    | Base delay between retries (ms)               |
| `max_retry_delay_ms`  | `u64`  | 30000   | Maximum delay cap for exponential backoff     |
| `exponential_backoff` | `bool` | true    | Use exponential backoff for retries           |

```zig
var config = downloader.Config.default();
config.max_retries = 5;
config.retry_delay_ms = 500;
config.max_retry_delay_ms = 60000;
config.exponential_backoff = true;
```

### Connection Settings

| Option               | Type  | Default | Description                 |
| -------------------- | ----- | ------- | --------------------------- |
| `connect_timeout_ms` | `u64` | 30000   | Connection timeout (ms)     |
| `read_timeout_ms`    | `u64` | 0       | Read timeout (ms, 0=none)   |
| `max_redirects`      | `u32` | 10      | Maximum redirects to follow |

### File Handling

| Option               | Type               | Default               | Description                         |
| -------------------- | ------------------ | --------------------- | ----------------------------------- |
| `resume_downloads`   | `bool`             | false                 | Attempt to resume partial downloads |
| `file_exists_action` | `FileExistsAction` | `.rename_with_number` | How to handle existing files        |
| `filename_strategy`  | `FilenameStrategy` | `.use_provided`       | How to resolve the output filename  |

### Buffer & Performance

| Option        | Type    | Default | Description                   |
| ------------- | ------- | ------- | ----------------------------- |
| `buffer_size` | `usize` | 65536   | Download buffer size in bytes |

## Preset Configurations

### Default

```zig
const config = downloader.Config.default();
```

Sensible defaults suitable for most use cases.

### Large Files

```zig
const config = downloader.Config.forLargeFiles();
```

Optimized for large file downloads:

- 1 MB buffer
- Resume enabled
- Use temporary file
- 5 retries
- Exponential backoff

### Small Files

```zig
const config = downloader.Config.forSmallFiles();
```

Optimized for small, quick downloads:

- 16 KB buffer
- 2 retries
- Resume disabled

## Complete Example

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create custom configuration
    var config = downloader.Config.default();

    // Disable auto update check
    config.enable_update_check = false;

    // Retry settings
    config.max_retries = 5;
    config.exponential_backoff = true;

    // File handling
    config.resume_downloads = true;
    config.file_exists_action = .rename_with_number;

    // Performance
    config.buffer_size = 128 * 1024;

    // Create client
    var client = try downloader.Client.init(allocator, config);
    defer client.deinit();

    // Download
    _ = try client.download(
        "https://example.com/file.zip",
        "file.zip",
        null
    );
}
```
