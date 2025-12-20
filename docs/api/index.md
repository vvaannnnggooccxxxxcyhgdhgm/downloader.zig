# API Reference

Complete API documentation for downloader.zig.

## Modules

### Core

| Module                    | Description                     |
| ------------------------- | ------------------------------- |
| [Client](/api/client)     | HTTP/HTTPS download client      |
| [Config](/api/config)     | Configuration options           |
| [Progress](/api/progress) | Progress tracking and callbacks |
| [Errors](/api/errors)     | Error types and handling        |

## Quick Reference

### Download Functions

```zig
// Simple download
fn download(allocator, url, output_path) !u64

// Download with progress
fn downloadWithProgress(allocator, url, output_path, callback) !u64

// Download with full configuration
fn downloadWithConfig(allocator, url, output_path, config, callback) !u64

// Check for updates
fn checkForUpdates(allocator) !UpdateInfo
```

### Client Methods

```zig
// Initialize client
fn init(allocator, config) !Client

// Release resources
fn deinit(self) void

// Perform download
fn download(self, url, output_path, callback) !u64
```

### Configuration Presets

```zig
Config.default()        // Sensible defaults
Config.forLargeFiles()  // Optimized for large files
Config.forSmallFiles()  // Optimized for small files
Config.noResume()       // Resume disabled
Config.noRetries()      // Retries disabled
```

### Progress Callbacks

```zig
// Callback signature
fn callback(progress: Progress) bool

// Built-in callbacks
noopCallback   // No output
stderrCallback // Print to stderr
```

## Type Hierarchy

```
downloader
├── Client
├── Config
│   └── FileExistsAction
├── Progress
├── ProgressCallback
├── ProgressTracker
├── DownloadError
├── StatusCategory
└── ErrorInfo
```

## Import

```zig
const downloader = @import("downloader");

// Access types
const Client = downloader.Client;
const Config = downloader.Config;
const Progress = downloader.Progress;
```

## Version

```zig
downloader.getVersion()          // "0.0.1"
downloader.getSemanticVersion()  // std.SemanticVersion
```
