# Errors API

Error types and utilities.

## DownloadError

```zig
pub const DownloadError = error{
    // URL
    InvalidUrl,
    UnsupportedProtocol,

    // Connection
    ConnectionFailed,
    ConnectionTimeout,
    DnsResolutionFailed,
    TlsError,

    // Server
    ServerError,
    InvalidResponse,
    TooManyRedirects,
    InvalidBody,

    // Resume
    ResumeNotSupported,
    FileModified,
    ContentLengthMissing,

    // File
    FileOpenError,
    FileWriteError,
    FileReadError,

    // Control
    DownloadInterrupted,
    RetriesExhausted,
    Cancelled,
    OutOfMemory,
};
```

## StatusCategory

```zig
pub const StatusCategory = enum {
    informational, // 1xx
    success,       // 2xx
    redirect,      // 3xx
    client_error,  // 4xx
    server_error,  // 5xx
    unknown,
};
```

### Methods

```zig
pub fn fromStatus(status: u16) StatusCategory
pub fn isError(self: StatusCategory) bool
pub fn isSuccess(self: StatusCategory) bool
```

## ErrorInfo

```zig
pub const ErrorInfo = struct {
    err: DownloadError,
    http_status: ?u16 = null,
    message: []const u8 = "",
    retry_count: u32 = 0,
};
```

Implements `std.fmt.format`.

## Functions

### `isRetryable`

```zig
pub fn isRetryable(err: DownloadError) bool
```

Returns true for transient errors.

### `getErrorMessage`

```zig
pub fn getErrorMessage(err: DownloadError) []const u8
```

Returns human-readable description.

## Error Categories

### Retryable

- `ConnectionFailed`
- `ConnectionTimeout`
- `DownloadInterrupted`
- `ServerError`

### Non-Retryable

- `InvalidUrl`
- `UnsupportedProtocol`
- `FileOpenError`
- `Cancelled`

## Example

```zig
const result = client.download(url, output, null);

if (result) |bytes| {
    std.debug.print("Success: {d} bytes\n", .{bytes});
} else |err| {
    const msg = downloader.errors_mod.getErrorMessage(err);
    std.debug.print("Error: {s}\n", .{msg});

    if (downloader.errors_mod.isRetryable(err)) {
        std.debug.print("(Retry may help)\n", .{});
    }
}
```

## See Also

- [Error Handling Guide](/guide/errors) - Usage patterns
- [Retry Logic](/guide/retry) - Automatic retries
