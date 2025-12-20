//! Download Error Types
//!
//! Defines error types and utilities for handling download failures.
//! Includes HTTP status classification and detailed error information.

const std = @import("std");

/// Errors that can occur during download operations.
pub const DownloadError = error{
    // URL errors
    InvalidUrl,
    UnsupportedProtocol,

    // Connection errors
    ConnectionFailed,
    ConnectionTimeout,
    DnsResolutionFailed,
    TlsError,

    // Server errors
    ServerError,
    InvalidResponse,
    TooManyRedirects,
    InvalidBody,

    // Resume errors
    ResumeNotSupported,
    FileModified,
    ContentLengthMissing,

    // File errors
    FileOpenError,
    FileWriteError,
    FileReadError,

    // Control flow
    DownloadInterrupted,
    RetriesExhausted,
    Cancelled,
    OutOfMemory,
};

/// HTTP status code classification.
pub const StatusCategory = enum {
    informational, // 1xx
    success, // 2xx
    redirect, // 3xx
    client_error, // 4xx
    server_error, // 5xx
    unknown,

    /// Classify an HTTP status code.
    pub fn fromStatus(status: u16) StatusCategory {
        return switch (status) {
            100...199 => .informational,
            200...299 => .success,
            300...399 => .redirect,
            400...499 => .client_error,
            500...599 => .server_error,
            else => .unknown,
        };
    }

    /// Check if the status indicates an error.
    pub fn isError(self: StatusCategory) bool {
        return self == .client_error or self == .server_error;
    }

    /// Check if the status indicates success.
    pub fn isSuccess(self: StatusCategory) bool {
        return self == .success;
    }
};

/// Extended error information with context.
pub const ErrorInfo = struct {
    err: DownloadError,
    http_status: ?u16 = null,
    message: []const u8 = "",
    retry_count: u32 = 0,

    /// Format error information for display.
    pub fn format(
        self: ErrorInfo,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("DownloadError: {s}", .{@errorName(self.err)});

        if (self.http_status) |status| {
            try writer.print(" (HTTP {d})", .{status});
        }

        if (self.message.len > 0) {
            try writer.print(" - {s}", .{self.message});
        }

        if (self.retry_count > 0) {
            try writer.print(" [retries: {d}]", .{self.retry_count});
        }
    }
};

/// Check if an error is likely transient and worth retrying.
pub fn isRetryable(err: DownloadError) bool {
    return switch (err) {
        error.ConnectionFailed,
        error.ConnectionTimeout,
        error.DownloadInterrupted,
        error.ServerError,
        => true,
        else => false,
    };
}

/// Get a human-readable description for an error.
pub fn getErrorMessage(err: DownloadError) []const u8 {
    return switch (err) {
        error.InvalidUrl => "The URL is malformed or invalid",
        error.UnsupportedProtocol => "Only HTTP and HTTPS protocols are supported",
        error.ConnectionFailed => "Failed to establish connection to server",
        error.ConnectionTimeout => "Connection attempt timed out",
        error.DnsResolutionFailed => "Could not resolve hostname",
        error.TlsError => "TLS/SSL handshake or certificate error",
        error.ServerError => "Server returned an error response",
        error.InvalidResponse => "Server response is malformed",
        error.TooManyRedirects => "Maximum redirect limit exceeded",
        error.InvalidBody => "Response body is truncated or invalid",
        error.ResumeNotSupported => "Server does not support resume (Range requests)",
        error.FileModified => "Remote file changed since partial download",
        error.ContentLengthMissing => "Content-Length header required for resume",
        error.FileOpenError => "Cannot create or open output file",
        error.FileWriteError => "Cannot write to output file",
        error.FileReadError => "Cannot read from file",
        error.DownloadInterrupted => "Download was unexpectedly interrupted",
        error.RetriesExhausted => "All retry attempts failed",
        error.Cancelled => "Download was cancelled by user",
        error.OutOfMemory => "Memory allocation failed",
    };
}

test "status category classification" {
    try std.testing.expect(StatusCategory.fromStatus(200) == .success);
    try std.testing.expect(StatusCategory.fromStatus(206) == .success);
    try std.testing.expect(StatusCategory.fromStatus(301) == .redirect);
    try std.testing.expect(StatusCategory.fromStatus(404) == .client_error);
    try std.testing.expect(StatusCategory.fromStatus(500) == .server_error);
}

test "status category methods" {
    try std.testing.expect(StatusCategory.success.isSuccess());
    try std.testing.expect(!StatusCategory.success.isError());
    try std.testing.expect(StatusCategory.client_error.isError());
    try std.testing.expect(StatusCategory.server_error.isError());
}

test "retryable errors" {
    try std.testing.expect(isRetryable(error.ConnectionFailed));
    try std.testing.expect(isRetryable(error.ConnectionTimeout));
    try std.testing.expect(!isRetryable(error.InvalidUrl));
    try std.testing.expect(!isRetryable(error.FileOpenError));
}
