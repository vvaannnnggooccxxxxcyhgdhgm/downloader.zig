# Error Handling

Handle download errors gracefully.

## Error Types

All download errors are in `DownloadError`:

### Connection Errors

| Error                 | Description                 |
| --------------------- | --------------------------- |
| `ConnectionFailed`    | Failed to connect to server |
| `ConnectionTimeout`   | Connection timed out        |
| `DnsResolutionFailed` | Could not resolve hostname  |
| `TlsError`            | TLS/SSL error               |

### Server Errors

| Error              | Description                     |
| ------------------ | ------------------------------- |
| `ServerError`      | Server returned error (4xx/5xx) |
| `InvalidResponse`  | Malformed response              |
| `TooManyRedirects` | Redirect limit exceeded         |
| `InvalidBody`      | Truncated or invalid body       |

### Resume Errors

| Error                  | Description                         |
| ---------------------- | ----------------------------------- |
| `ResumeNotSupported`   | Server doesn't support Range        |
| `FileModified`         | File changed since partial download |
| `ContentLengthMissing` | Content-Length required             |

### File Errors

| Error            | Description             |
| ---------------- | ----------------------- |
| `FileOpenError`  | Cannot create/open file |
| `FileWriteError` | Cannot write to file    |
| `FileReadError`  | Cannot read file        |

### Control Flow

| Error              | Description                    |
| ------------------ | ------------------------------ |
| `RetriesExhausted` | All retry attempts failed      |
| `Cancelled`        | Download cancelled by callback |
| `OutOfMemory`      | Memory allocation failed       |

## Basic Error Handling

```zig
const result = client.download(url, output, null);

if (result) |bytes| {
    std.debug.print("Downloaded {d} bytes\n", .{bytes});
} else |err| {
    std.debug.print("Error: {s}\n", .{@errorName(err)});
}
```

## Specific Error Handling

```zig
client.download(url, output, null) catch |err| switch (err) {
    error.ConnectionFailed => {
        std.debug.print("Cannot connect. Check network.\n", .{});
    },
    error.ServerError => {
        std.debug.print("Server error. Try again later.\n", .{});
    },
    error.FileOpenError => {
        std.debug.print("Cannot write to output location.\n", .{});
    },
    error.RetriesExhausted => {
        std.debug.print("Download failed after retries.\n", .{});
    },
    else => {
        std.debug.print("Unexpected error: {s}\n", .{@errorName(err)});
    },
};
```

## Error Messages

Get human-readable descriptions:

```zig
const msg = downloader.errors_mod.getErrorMessage(err);
std.debug.print("{s}\n", .{msg});
```

## Status Categories

Classify HTTP status codes:

```zig
const category = downloader.StatusCategory.fromStatus(status);

switch (category) {
    .success => {},
    .redirect => {},
    .client_error => {},  // 4xx
    .server_error => {},  // 5xx
    else => {},
}
```

## Retryable Check

Determine if an error is worth retrying:

```zig
if (downloader.errors_mod.isRetryable(err)) {
    std.debug.print("Transient error, retry recommended\n", .{});
}
```

## Next Steps

- [Retry Logic](/guide/retry) - Automatic retry configuration
- [Resume Downloads](/guide/resume) - Continue interrupted downloads
