# Client API

HTTP/HTTPS download client.

## Type

```zig
pub const Client = struct {
    allocator: Allocator,
    config: Config,
    write_buffer: []u8,
};
```

## Constructor

### `init`

Initialize a new download client.

```zig
pub fn init(allocator: Allocator, config: Config) !Client
```

**Parameters:**

- `allocator` - Memory allocator for internal buffers
- `config` - Download configuration

**Returns:** Initialized Client or error

**Example:**

```zig
var client = try downloader.Client.init(allocator, .{
    .max_retries = 5,
    .resume_downloads = true,
});
defer client.deinit();
```

## Destructor

### `deinit`

Release all resources.

```zig
pub fn deinit(self: *Client) void
```

**Example:**

```zig
var client = try Client.init(allocator, .{});
defer client.deinit();
```

## Methods

### `download`

Download a file from URL.

```zig
pub fn download(
    self: *Client,
    url: []const u8,
    output_path: []const u8,
    callback: ?ProgressCallback,
) !u64
```

**Parameters:**

- `url` - HTTP or HTTPS URL
- `output_path` - Local file path
- `callback` - Progress callback (null for silent)

**Returns:** Total bytes downloaded

**Errors:**

- `ConnectionFailed` - Cannot connect
- `ServerError` - Server error response
- `FileOpenError` - Cannot write file
- `RetriesExhausted` - All retries failed
- `Cancelled` - Callback returned false

**Example:**

```zig
const bytes = try client.download(
    "https://example.com/file.zip",
    "file.zip",
    progressCallback
);
```

### `downloadSimple`

Static convenience method.

```zig
pub fn downloadSimple(
    allocator: Allocator,
    url: []const u8,
    output_path: []const u8,
) !u64
```

**Example:**

```zig
const bytes = try Client.downloadSimple(allocator, url, "output.pdf");
```

## Standalone Function

### `downloadFile`

Module-level convenience function.

```zig
pub fn downloadFile(
    allocator: Allocator,
    url: []const u8,
    output_path: []const u8,
) !u64
```

## Thread Safety

Client instances are **not thread-safe**. Create one Client per thread for concurrent downloads.

## See Also

- [Config](/api/config) - Configuration options
- [Progress](/api/progress) - Progress callbacks
- [Errors](/api/errors) - Error handling
