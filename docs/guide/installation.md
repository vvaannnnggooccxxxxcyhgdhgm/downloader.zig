# Installation

Multiple methods for adding downloader.zig to your project.

## Requirements

- Zig 0.15.0 or later
- Existing Zig project with `build.zig`

## Method 1: zig fetch (Recommended)

```bash
zig fetch --save https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz
```

This command:

1. Downloads the package
2. Calculates the hash
3. Updates your `build.zig.zon`

## Method 2: Manual Configuration

### Step 1: Update build.zig.zon

```zig
.{
    .name = "my-project",
    .version = "0.0.1",
    .dependencies = .{
        .downloader = .{
            .url = "https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz",
            .hash = "...",
        },
    },
    .paths = .{ "src", "build.zig", "build.zig.zon" },
}
```

### Step 2: Get the Hash

```bash
zig fetch --hash https://github.com/muhammad-fiaz/downloader.zig/archive/refs/tags/v0.0.1.tar.gz
```

### Step 3: Update build.zig

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const downloader = b.dependency("downloader", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("downloader", downloader.module("downloader"));
    b.installArtifact(exe);
}
```

## Method 3: Git Submodule

```bash
git submodule add https://github.com/muhammad-fiaz/downloader.zig.git libs/downloader
```

Then configure in `build.zig`:

```zig
const downloader_mod = b.createModule(.{
    .root_source_file = b.path("libs/downloader/src/downloader.zig"),
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("downloader", downloader_mod);
```

## Verification

Create a test file:

```zig
const std = @import("std");
const downloader = @import("downloader");

pub fn main() void {
    std.debug.print("downloader.zig v{s}\n", .{downloader.getVersion()});
}
```

Build and run:

```bash
zig build run
```

Expected output:

```
downloader.zig v0.0.1
```

## Troubleshooting

### Hash Mismatch

If you get a hash mismatch error:

1. Delete `.zig-cache`
2. Run `zig fetch --save ...` again

### Module Not Found

Ensure your `build.zig` correctly calls `addImport`:

```zig
exe.root_module.addImport("downloader", downloader.module("downloader"));
```

### Network Issues

For environments behind a proxy:

```bash
export HTTP_PROXY=http://proxy:port
export HTTPS_PROXY=http://proxy:port
zig fetch --save ...
```

## Next Steps

- [Configuration](/guide/configuration) - Customize behavior
- [API Reference](/api/) - Full documentation
