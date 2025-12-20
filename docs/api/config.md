# Config API

Download configuration options.

## Type

```zig
pub const Config = struct {
    max_retries: u32 = 3,
    retry_delay_ms: u64 = 1000,
    max_retry_delay_ms: u64 = 30000,
    exponential_backoff: bool = true,
    connect_timeout_ms: u64 = 30000,
    read_timeout_ms: u64 = 60000,
    resume_downloads: bool = true,
    file_exists_action: FileExistsAction = .rename_with_number,
    overwrite_existing: bool = false,
    buffer_size: usize = 64 * 1024,
    max_redirects: u16 = 10,
    user_agent: ?[]const u8 = null,
    verify_tls: bool = true,
    progress_interval_bytes: usize = 0,
    progress_interval_ms: u64 = 100,
};
```

## FileExistsAction

```zig
pub const FileExistsAction = enum {
    overwrite,           // Replace existing file
    resume_or_overwrite, // Try resume, otherwise overwrite
    skip,                // Skip if exists
    rename_with_number,  // Create file (1), file (2), etc.
    fail,                // Return error
};
```

## Preset Constructors

### `default`

```zig
pub fn default() Config
```

Standard configuration with sensible defaults.

### `forLargeFiles`

```zig
pub fn forLargeFiles() Config
```

Optimized for large downloads:

- 256 KB buffer
- 5 retries
- 2 minute timeout
- Progress every 1 MB

### `forSmallFiles`

```zig
pub fn forSmallFiles() Config
```

Optimized for quick downloads:

- 16 KB buffer
- 2 retries
- 500ms delay

### `noResume`

```zig
pub fn noResume() Config
```

Resume disabled, overwrite enabled.

### `noRetries`

```zig
pub fn noRetries() Config
```

All retries disabled.

## Methods

### `getUserAgent`

```zig
pub fn getUserAgent(self: Config) []const u8
```

Returns the effective User-Agent string.

### `validate`

```zig
pub fn validate(self: Config) !void
```

Validate configuration values.

**Errors:**

- `InvalidBufferSize` - Buffer size is 0
- `BufferSizeTooLarge` - Buffer exceeds 16 MB

## Field Reference

### Retry Settings

| Field                 | Type   | Default | Description             |
| --------------------- | ------ | ------- | ----------------------- |
| `max_retries`         | `u32`  | 3       | Maximum retry attempts  |
| `retry_delay_ms`      | `u64`  | 1000    | Base retry delay        |
| `max_retry_delay_ms`  | `u64`  | 30000   | Maximum delay cap       |
| `exponential_backoff` | `bool` | true    | Use exponential backoff |

### Connection Settings

| Field                | Type  | Default | Description        |
| -------------------- | ----- | ------- | ------------------ |
| `connect_timeout_ms` | `u64` | 30000   | Connection timeout |
| `read_timeout_ms`    | `u64` | 60000   | Read timeout       |
| `max_redirects`      | `u16` | 10      | Redirect limit     |

### File Handling

| Field                | Type               | Default               | Description            |
| -------------------- | ------------------ | --------------------- | ---------------------- |
| `resume_downloads`   | `bool`             | true                  | Enable resume          |
| `file_exists_action` | `FileExistsAction` | `.rename_with_number` | Existing file handling |

### Performance

| Field                  | Type    | Default | Description          |
| ---------------------- | ------- | ------- | -------------------- |
| `buffer_size`          | `usize` | 65536   | Download buffer      |
| `progress_interval_ms` | `u64`   | 100     | Progress update rate |

### Identity

| Field        | Type          | Default | Description       |
| ------------ | ------------- | ------- | ----------------- |
| `user_agent` | `?[]const u8` | null    | Custom User-Agent |
| `verify_tls` | `bool`        | true    | TLS verification  |

## Example

```zig
var config = downloader.Config.default();
config.max_retries = 5;
config.resume_downloads = true;
config.file_exists_action = .rename_with_number;
config.buffer_size = 128 * 1024;

try config.validate();

var client = try Client.init(allocator, config);
```

## See Also

- [Client](/api/client) - Download client
- [Configuration Guide](/guide/configuration) - Usage guide
