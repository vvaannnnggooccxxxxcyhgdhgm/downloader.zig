# Config API

Download configuration options.

## Type

```zig
pub const Config = struct {
    // Retry Configuration
    max_retries: u32 = 3,
    retry_delay_ms: u64 = 1000,
    exponential_backoff: bool = true,
    max_retry_delay_ms: u64 = 30000,

    // Connection Configuration
    connect_timeout_ms: u64 = 30000,
    read_timeout_ms: u64 = 0,
    follow_redirects: bool = true,
    max_redirects: u32 = 10,

    // Buffer Configuration
    buffer_size: usize = 64 * 1024,

    // Resume Configuration
    resume_downloads: bool = false,

    // Progress Configuration
    progress_interval_ms: u64 = 100,

    // File Handling
    file_exists_action: FileExistsAction = .rename_with_number,
    filename_strategy: FilenameStrategy = .use_provided,
    create_directories: bool = true,
    use_temp_file: bool = false,
    temp_suffix: []const u8 = ".download",

    // Request Configuration
    method: HttpMethod = .GET,
    user_agent: ?[]const u8 = null,
    custom_headers: []const HttpHeader = &.{},
    request_body: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    authorization: ?[]const u8 = null,
    accept: ?[]const u8 = null,
    accept_encoding: ?[]const u8 = null,
    referer: ?[]const u8 = null,
    cookie: ?[]const u8 = null,

    // Range Request Configuration
    range_start: ?u64 = null,
    range_end: ?u64 = null,

    // Security Configuration
    verify_tls: bool = true,

    // Validation
    expected_size: ?u64 = null,
    expected_checksum: ?[]const u8 = null,
    checksum_algorithm: ChecksumAlgorithm = .none,

    // Update Check
    enable_update_check: bool = true,
};
```

## FileExistsAction

```zig
pub const FileExistsAction = enum {
    rename_with_number,  // Create file (1), file (2), etc.
    overwrite,           // Replace existing file
    resume_or_overwrite, // Try resume, otherwise overwrite
    skip,                // Skip if exists
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

- 1 MB buffer
- Resume enabled
- Use temporary file
- 5 retries
- Exponential backoff

### `forSmallFiles`

```zig
pub fn forSmallFiles() Config
```

Optimized for quick downloads:

- 16 KB buffer
- 2 retries
- Resume disabled

## Methods

### `getUserAgent`

```zig
pub fn getUserAgent(self: *const Config) []const u8
```

Returns the effective User-Agent string.

## Field Reference

### Update Check Settings

| Field                 | Type   | Default | Description                             |
| --------------------- | ------ | ------- | --------------------------------------- |
| `enable_update_check` | `bool` | true    | Automatically check for library updates |

### Retry Settings

| Field                 | Type   | Default | Description             |
| --------------------- | ------ | ------- | ----------------------- |
| `max_retries`         | `u32`  | 3       | Maximum retry attempts  |
| `retry_delay_ms`      | `u64`  | 1000    | Base retry delay        |
| `max_retry_delay_ms`  | `u64`  | 30000   | Maximum delay cap       |
| `exponential_backoff` | `bool` | true    | Use exponential backoff |

### See Also

- [Client](/api/client) - Download client
- [Configuration Guide](/guide/configuration) - Usage guide
