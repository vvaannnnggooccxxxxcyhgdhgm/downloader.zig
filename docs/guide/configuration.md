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
| `read_timeout_ms`    | `u64` | 60000   | Read timeout (ms)           |
| `max_redirects`      | `u16` | 10      | Maximum redirects to follow |

```zig
var config = downloader.Config.default();
config.connect_timeout_ms = 10000;  // 10 seconds
config.read_timeout_ms = 120000;    // 2 minutes
config.max_redirects = 5;
```

### File Handling

| Option               | Type               | Default               | Description                         |
| -------------------- | ------------------ | --------------------- | ----------------------------------- |
| `resume_downloads`   | `bool`             | true                  | Attempt to resume partial downloads |
| `file_exists_action` | `FileExistsAction` | `.rename_with_number` | How to handle existing files        |

#### FileExistsAction Options

| Action                | Description                                              |
| --------------------- | -------------------------------------------------------- |
| `rename_with_number`  | Create file (1), file (2), etc. like Windows/Linux/macOS |
| `overwrite`           | Replace existing file                                    |
| `resume_or_overwrite` | Try resume, if not possible overwrite                    |
| `skip`                | Don't download if file already exists                    |
| `fail`                | Return an error if file exists                           |

```zig
var config = downloader.Config.default();
config.file_exists_action = .rename_with_number;  // Default - safe

// Examples of other options:
config.file_exists_action = .overwrite;           // Replace file
config.file_exists_action = .resume_or_overwrite; // Resume if possible
config.file_exists_action = .skip;                // Skip if exists
config.file_exists_action = .fail;                // Error if exists
```

### Buffer & Performance

| Option        | Type    | Default | Description                   |
| ------------- | ------- | ------- | ----------------------------- |
| `buffer_size` | `usize` | 65536   | Download buffer size in bytes |

```zig
// For large files, use bigger buffers
var config = downloader.Config.forLargeFiles();
// Sets buffer_size to 256 KB

// Or set manually
var config = downloader.Config.default();
config.buffer_size = 512 * 1024;  // 512 KB
```

### Identity & Security

| Option       | Type          | Default | Description              |
| ------------ | ------------- | ------- | ------------------------ |
| `user_agent` | `?[]const u8` | null    | Custom User-Agent header |
| `verify_tls` | `bool`        | true    | Verify TLS certificates  |

```zig
var config = downloader.Config.default();
config.user_agent = "MyApp/1.0 (+https://myapp.com)";
config.verify_tls = true;  // Always true in production!
```

### Progress Reporting

| Option                    | Type    | Default | Description                            |
| ------------------------- | ------- | ------- | -------------------------------------- |
| `progress_interval_bytes` | `usize` | 0       | Report every N bytes (0 = every chunk) |
| `progress_interval_ms`    | `u64`   | 100     | Minimum ms between reports             |

```zig
var config = downloader.Config.default();
config.progress_interval_ms = 250;  // Report 4x per second max
config.progress_interval_bytes = 1024 * 1024;  // Report every 1 MB
```

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

- 256 KB buffer
- 5 retries
- 2 minute read timeout
- Progress every 1 MB

### Small Files

```zig
const config = downloader.Config.forSmallFiles();
```

Optimized for small, quick downloads:

- 16 KB buffer
- 2 retries
- 500ms retry delay

### No Resume

```zig
const config = downloader.Config.noResume();
```

Disables resume functionality:

- `resume_downloads = false`
- `file_exists_action = .overwrite`

### No Retries

```zig
const config = downloader.Config.noRetries();
```

Disables all retry logic:

- `max_retries = 0`

## Configuration Validation

The `Config` struct includes validation:

```zig
var config = downloader.Config.default();
config.buffer_size = 0;  // Invalid!

try config.validate();  // Returns error.InvalidBufferSize
```

Validation rules:

- `buffer_size` must be > 0 and ≤ 16 MB

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

    // Retry settings
    config.max_retries = 5;
    config.retry_delay_ms = 500;
    config.exponential_backoff = true;

    // Connection settings
    config.connect_timeout_ms = 15000;
    config.read_timeout_ms = 120000;

    // File handling
    config.resume_downloads = true;
    config.file_exists_action = .rename_with_number;

    // Performance
    config.buffer_size = 128 * 1024;

    // Identity
    config.user_agent = "MyDownloader/1.0";

    // Validate configuration
    try config.validate();

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

## Next Steps

- [Progress Reporting](/guide/progress) - Track download progress
- [Resume Downloads](/guide/resume) - Resume interrupted downloads
- [Error Handling](/guide/errors) - Handle download errors
