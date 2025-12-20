# Resume Downloads

Continue interrupted downloads using HTTP Range headers.

## Enabling Resume

Resume is enabled by default:

```zig
var config = downloader.Config.default();
config.resume_downloads = true;  // Default
```

## How It Works

1. Client checks for existing partial file
2. Sends HEAD request to verify server support
3. If supported, sends GET with `Range` header
4. Server responds with `206 Partial Content`
5. Download continues from last byte

## Requirements

Resume requires:

- Server support for Range requests (`Accept-Ranges: bytes`)
- Existing partial file on disk
- File unchanged on server since partial download

## File Exists Actions

Control behavior when file exists:

```zig
var config = downloader.Config.default();

// Create file (1), file (2), etc. (default)
config.file_exists_action = .rename_with_number;

// Try resume, otherwise overwrite
config.file_exists_action = .resume_or_overwrite;

// Always overwrite
config.file_exists_action = .overwrite;

// Don't download if exists
config.file_exists_action = .skip;

// Return error if exists
config.file_exists_action = .fail;
```

## Detecting Resume

Check if download was resumed via progress callback:

```zig
fn progressCallback(p: downloader.Progress) bool {
    if (p.is_resumed) {
        std.debug.print("Resuming from byte {d}\n", .{p.start_offset});
    }
    return true;
}
```

## Example

```zig
var config = downloader.Config.default();
config.resume_downloads = true;
config.file_exists_action = .resume_or_overwrite;

var client = try downloader.Client.init(allocator, config);
defer client.deinit();

const bytes = try client.download(url, "large-file.iso", callback);
std.debug.print("Downloaded {d} bytes this session\n", .{bytes});
```

## Fallback Behavior

If resume fails:

- Server doesn't support Range: starts fresh download
- File modified on server: starts fresh download
- Partial file deleted: starts fresh download

## Disabling Resume

```zig
var config = downloader.Config.noResume();
// Sets resume_downloads = false
// Sets file_exists_action = .overwrite
```

## Next Steps

- [Retry Logic](/guide/retry) - Handle transient failures
- [Configuration](/guide/configuration) - All options
