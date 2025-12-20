# Custom User-Agent

Configure the HTTP User-Agent header.

## Default User-Agent

By default, requests use:

```
downloader.zig/0.0.1
```

## Custom User-Agent

Set a custom User-Agent string:

```zig
var config = downloader.Config.default();
config.user_agent = "MyApp/1.0 (+https://myapp.com)";

var client = try downloader.Client.init(allocator, config);
```

## Best Practices

### Include Contact Information

Many servers prefer User-Agents that include contact:

```zig
config.user_agent = "MyBot/1.0 (contact@example.com)";
```

### Identify Your Application

```zig
config.user_agent = "MyDownloader/2.1.0 (Windows; x64)";
```

### Follow Conventions

Common User-Agent format:

```
Product/Version (Comment; Platform)
```

## Examples

### Download Tool

```zig
config.user_agent = "zig-fetch/1.0";
```

### Package Manager

```zig
config.user_agent = "zigpm/0.1.0 (Zig Package Manager)";
```

### API Client

```zig
config.user_agent = "MyAPI-Client/2.0 (api@company.com)";
```

## Getting Current User-Agent

```zig
const agent = config.getUserAgent();
std.debug.print("User-Agent: {s}\n", .{agent});
```

## Server Requirements

Some servers require specific User-Agents:

- API servers may require registration
- CDNs may block bot-like agents
- Some servers require browser-like agents

## Next Steps

- [Configuration](/guide/configuration) - All options
- [Error Handling](/guide/errors) - Handle failures
