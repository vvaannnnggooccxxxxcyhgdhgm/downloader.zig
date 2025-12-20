//! Error Types for Download Operations
//!
//! Provides comprehensive error types for all download-related failures
//! including network, file, validation, and protocol errors.

const std = @import("std");

/// Download operation errors.
///
/// Comprehensive error set covering all failure modes.
pub const DownloadError = error{
    // === Network Errors ===

    /// Failed to establish connection to server.
    ConnectionFailed,

    /// Connection was reset by peer.
    ConnectionReset,

    /// Connection timed out.
    ConnectionTimeout,

    /// DNS resolution failed.
    DnsResolutionFailed,

    /// Network is unreachable.
    NetworkUnreachable,

    /// Host is unreachable.
    HostUnreachable,

    // === Protocol Errors ===

    /// Invalid URL format.
    InvalidUrl,

    /// Unsupported URL scheme (not HTTP or HTTPS).
    UnsupportedScheme,

    /// Server returned an error status code.
    ServerError,

    /// HTTP 400 Bad Request.
    BadRequest,

    /// HTTP 401 Unauthorized.
    Unauthorized,

    /// HTTP 403 Forbidden.
    Forbidden,

    /// HTTP 404 Not Found.
    NotFound,

    /// HTTP 405 Method Not Allowed.
    MethodNotAllowed,

    /// HTTP 408 Request Timeout.
    RequestTimeout,

    /// HTTP 429 Too Many Requests.
    TooManyRequests,

    /// HTTP 500 Internal Server Error.
    InternalServerError,

    /// HTTP 502 Bad Gateway.
    BadGateway,

    /// HTTP 503 Service Unavailable.
    ServiceUnavailable,

    /// HTTP 504 Gateway Timeout.
    GatewayTimeout,

    /// Too many HTTP redirects.
    TooManyRedirects,

    /// Invalid HTTP response.
    InvalidResponse,

    /// Invalid HTTP headers.
    InvalidHeaders,

    /// Content-Length mismatch.
    ContentLengthMismatch,

    // === TLS/SSL Errors ===

    /// TLS handshake failed.
    TlsHandshakeFailed,

    /// TLS certificate verification failed.
    CertificateError,

    /// TLS protocol error.
    TlsError,

    // === File Errors ===

    /// Failed to open output file.
    FileOpenError,

    /// Failed to write to output file.
    FileWriteError,

    /// Failed to read file.
    FileReadError,

    /// File already exists.
    FileAlreadyExists,

    /// Disk is full.
    DiskFull,

    /// Permission denied.
    PermissionDenied,

    /// Invalid file path.
    InvalidPath,

    /// Failed to create directory.
    DirectoryCreationFailed,

    /// Failed to rename file.
    RenameError,

    // === Resume Errors ===

    /// Server does not support range requests.
    RangeNotSupported,

    /// Resume failed, file was modified.
    ResumeFileMismatch,

    /// Invalid range specified.
    InvalidRange,

    // === Validation Errors ===

    /// Checksum verification failed.
    ChecksumMismatch,

    /// File size does not match expected.
    SizeMismatch,

    /// Content validation failed.
    ValidationFailed,

    // === Rate Limiting ===

    /// Download was rate limited.
    RateLimited,

    /// Bandwidth limit exceeded.
    BandwidthExceeded,

    // === Control Errors ===

    /// Download was cancelled by user.
    Cancelled,

    /// All retry attempts exhausted.
    RetriesExhausted,

    /// Operation timed out.
    Timeout,

    /// Out of memory.
    OutOfMemory,
};

/// HTTP status code categories.
pub const StatusCategory = enum {
    informational, // 1xx
    success, // 2xx
    redirect, // 3xx
    client_error, // 4xx
    server_error, // 5xx
    unknown,

    /// Get category from HTTP status code.
    pub fn fromStatusCode(code: u16) StatusCategory {
        return switch (code) {
            100...199 => .informational,
            200...299 => .success,
            300...399 => .redirect,
            400...499 => .client_error,
            500...599 => .server_error,
            else => .unknown,
        };
    }
};

/// Convert HTTP status code to DownloadError.
pub fn errorFromStatusCode(code: u16) ?DownloadError {
    return switch (code) {
        200, 201, 202, 204, 206 => null, // Success codes
        400 => DownloadError.BadRequest,
        401 => DownloadError.Unauthorized,
        403 => DownloadError.Forbidden,
        404 => DownloadError.NotFound,
        405 => DownloadError.MethodNotAllowed,
        408 => DownloadError.RequestTimeout,
        429 => DownloadError.TooManyRequests,
        500 => DownloadError.InternalServerError,
        502 => DownloadError.BadGateway,
        503 => DownloadError.ServiceUnavailable,
        504 => DownloadError.GatewayTimeout,
        else => if (code >= 400 and code < 500)
            DownloadError.BadRequest
        else if (code >= 500)
            DownloadError.ServerError
        else
            null,
    };
}

/// Get a human-readable description of an error.
pub fn errorDescription(err: DownloadError) []const u8 {
    return switch (err) {
        .ConnectionFailed => "Failed to connect to server",
        .ConnectionReset => "Connection was reset",
        .ConnectionTimeout => "Connection timed out",
        .DnsResolutionFailed => "DNS resolution failed",
        .NetworkUnreachable => "Network is unreachable",
        .HostUnreachable => "Host is unreachable",
        .InvalidUrl => "Invalid URL format",
        .UnsupportedScheme => "Unsupported URL scheme",
        .ServerError => "Server returned an error",
        .BadRequest => "Bad request (400)",
        .Unauthorized => "Unauthorized (401)",
        .Forbidden => "Forbidden (403)",
        .NotFound => "Not found (404)",
        .MethodNotAllowed => "Method not allowed (405)",
        .RequestTimeout => "Request timeout (408)",
        .TooManyRequests => "Too many requests (429)",
        .InternalServerError => "Internal server error (500)",
        .BadGateway => "Bad gateway (502)",
        .ServiceUnavailable => "Service unavailable (503)",
        .GatewayTimeout => "Gateway timeout (504)",
        .TooManyRedirects => "Too many redirects",
        .InvalidResponse => "Invalid HTTP response",
        .InvalidHeaders => "Invalid HTTP headers",
        .ContentLengthMismatch => "Content length mismatch",
        .TlsHandshakeFailed => "TLS handshake failed",
        .CertificateError => "Certificate verification failed",
        .TlsError => "TLS protocol error",
        .FileOpenError => "Failed to open file",
        .FileWriteError => "Failed to write to file",
        .FileReadError => "Failed to read file",
        .FileAlreadyExists => "File already exists",
        .DiskFull => "Disk is full",
        .PermissionDenied => "Permission denied",
        .InvalidPath => "Invalid file path",
        .DirectoryCreationFailed => "Failed to create directory",
        .RenameError => "Failed to rename file",
        .RangeNotSupported => "Range requests not supported",
        .ResumeFileMismatch => "Resume failed, file was modified",
        .InvalidRange => "Invalid byte range",
        .ChecksumMismatch => "Checksum verification failed",
        .SizeMismatch => "File size mismatch",
        .ValidationFailed => "Content validation failed",
        .RateLimited => "Rate limited",
        .BandwidthExceeded => "Bandwidth limit exceeded",
        .Cancelled => "Download cancelled",
        .RetriesExhausted => "All retry attempts exhausted",
        .Timeout => "Operation timed out",
        .OutOfMemory => "Out of memory",
    };
}

/// Check if an error is retryable.
pub fn isRetryable(err: DownloadError) bool {
    return switch (err) {
        error.ConnectionFailed,
        error.ConnectionReset,
        error.ConnectionTimeout,
        error.DnsResolutionFailed,
        error.NetworkUnreachable,
        error.RequestTimeout,
        error.TooManyRequests,
        error.InternalServerError,
        error.BadGateway,
        error.ServiceUnavailable,
        error.GatewayTimeout,
        error.TlsHandshakeFailed,
        error.RateLimited,
        error.Timeout,
        => true,
        else => false,
    };
}

/// Check if an error is a network error.
pub fn isNetworkError(err: DownloadError) bool {
    return switch (err) {
        error.ConnectionFailed,
        error.ConnectionReset,
        error.ConnectionTimeout,
        error.DnsResolutionFailed,
        error.NetworkUnreachable,
        error.HostUnreachable,
        => true,
        else => false,
    };
}

/// Check if an error is a file system error.
pub fn isFileError(err: DownloadError) bool {
    return switch (err) {
        error.FileOpenError,
        error.FileWriteError,
        error.FileReadError,
        error.FileAlreadyExists,
        error.DiskFull,
        error.PermissionDenied,
        error.InvalidPath,
        error.DirectoryCreationFailed,
        error.RenameError,
        => true,
        else => false,
    };
}

pub fn toDownloadError(err: anyerror) DownloadError {
    if (@typeInfo(DownloadError).error_set) |set| {
        inline for (set) |member| {
            if (std.mem.eql(u8, member.name, @errorName(err))) {
                return @field(DownloadError, member.name);
            }
        }
    }

    // Map common POSIX/Network errors to our set
    return switch (err) {
        error.ConnectionRefused, error.ConnectionResetByPeer, error.ConnectionTimedOut => DownloadError.ConnectionFailed,
        error.DnsResolutionFailed, error.UnknownHostName => DownloadError.DnsResolutionFailed,
        error.NetworkUnreachable, error.HostUnreachable => DownloadError.NetworkUnreachable,
        error.AccessDenied => DownloadError.PermissionDenied,
        error.DiskQuota, error.NoSpaceLeft => DownloadError.DiskFull,
        error.FileNotFound => DownloadError.NotFound,
        error.OutOfMemory => DownloadError.OutOfMemory,
        error.TlsInitializationFailed, error.TlsHandshakeFailed => DownloadError.TlsHandshakeFailed,
        error.Canceled, error.OperationAborted => DownloadError.Cancelled,
        else => DownloadError.ServerError,
    };
}

// Tests
test "status category" {
    try std.testing.expect(StatusCategory.fromStatusCode(200) == .success);
    try std.testing.expect(StatusCategory.fromStatusCode(404) == .client_error);
    try std.testing.expect(StatusCategory.fromStatusCode(500) == .server_error);
    try std.testing.expect(StatusCategory.fromStatusCode(301) == .redirect);
}

test "error from status code" {
    try std.testing.expect(errorFromStatusCode(200) == null);
    try std.testing.expect(errorFromStatusCode(404).? == DownloadError.NotFound);
    try std.testing.expect(errorFromStatusCode(500).? == DownloadError.InternalServerError);
}

test "error retryable" {
    try std.testing.expect(isRetryable(DownloadError.ConnectionTimeout));
    try std.testing.expect(isRetryable(DownloadError.ServiceUnavailable));
    try std.testing.expect(!isRetryable(DownloadError.NotFound));
    try std.testing.expect(!isRetryable(DownloadError.Cancelled));
}

test "error categories" {
    try std.testing.expect(isNetworkError(DownloadError.ConnectionFailed));
    try std.testing.expect(!isNetworkError(DownloadError.FileWriteError));
    try std.testing.expect(isFileError(DownloadError.DiskFull));
    try std.testing.expect(!isFileError(DownloadError.ConnectionFailed));
}
