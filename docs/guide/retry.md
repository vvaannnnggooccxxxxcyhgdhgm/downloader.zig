# Retry Logic

Handle transient failures with automatic retries.

## Default Behavior

Retries are enabled by default:

```zig
var config = downloader.Config.default();
// max_retries = 3
// retry_delay_ms = 1000
// exponential_backoff = true
```

## Configuration

```zig
var config = downloader.Config.default();

// Maximum retry attempts
config.max_retries = 5;

// Base delay between retries
config.retry_delay_ms = 500;

// Maximum delay cap
config.max_retry_delay_ms = 30000;

// Use exponential backoff
config.exponential_backoff = true;
```

## Exponential Backoff

With exponential backoff enabled, delays increase:

| Attempt | Delay   |
| ------- | ------- |
| 1       | ~500ms  |
| 2       | ~1000ms |
| 3       | ~2000ms |
| 4       | ~4000ms |
| 5       | ~8000ms |

Jitter (±25%) is applied to prevent thundering herd.

## Constant Delay

Disable exponential backoff for constant delays:

```zig
config.exponential_backoff = false;
config.retry_delay_ms = 2000;  // Always 2 seconds
```

## Retryable Errors

These errors trigger retries:

- `ConnectionFailed`
- `ConnectionTimeout`
- `DownloadInterrupted`
- `ConnectionResetByPeer`
- `BrokenPipe`
- `NetworkUnreachable`
- `HostUnreachable`

## Non-Retryable Errors

These errors fail immediately:

- `InvalidUrl`
- `UnsupportedProtocol`
- `FileOpenError`
- `Cancelled`

## Disabling Retries

```zig
var config = downloader.Config.noRetries();
// Sets max_retries = 0
```

## Example

```zig
var config = downloader.Config.default();
config.max_retries = 5;
config.retry_delay_ms = 1000;
config.max_retry_delay_ms = 30000;
config.exponential_backoff = true;

var client = try downloader.Client.init(allocator, config);
defer client.deinit();

// Will retry up to 5 times on transient failures
const bytes = try client.download(url, output, callback);
```

## Error After Retries

When all retries are exhausted:

```zig
client.download(url, output, null) catch |err| {
    if (err == error.RetriesExhausted) {
        std.debug.print("Download failed after all retries\n", .{});
    }
};
```

## Next Steps

- [Error Handling](/guide/errors) - Handle all error types
- [Configuration](/guide/configuration) - All options
