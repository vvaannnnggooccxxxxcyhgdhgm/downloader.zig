//! Retry Logic
//!
//! Provides configurable retry behavior with exponential backoff
//! for handling transient download failures.

const std = @import("std");
const config_mod = @import("config.zig");
const Config = config_mod.Config;
const util = @import("util.zig");

/// Retry state tracker.
///
/// Manages retry attempts, delays, and backoff calculation.
pub const RetryState = struct {
    attempt: u32,
    max_attempts: u32,
    base_delay_ms: u64,
    max_delay_ms: u64,
    use_exponential: bool,

    /// Initialize retry state from configuration.
    pub fn init(config: Config) RetryState {
        return .{
            .attempt = 0,
            .max_attempts = config.max_retries + 1, // +1 for initial attempt
            .base_delay_ms = config.retry_delay_ms,
            .max_delay_ms = config.max_retry_delay_ms,
            .use_exponential = config.exponential_backoff,
        };
    }

    /// Check if more retry attempts are available.
    pub fn canRetry(self: *const RetryState) bool {
        return self.attempt < self.max_attempts;
    }

    /// Check if this is the last attempt.
    pub fn isLastAttempt(self: *const RetryState) bool {
        return self.attempt >= self.max_attempts - 1;
    }

    /// Advance to the next retry attempt.
    pub fn nextAttempt(self: *RetryState) !void {
        if (!self.canRetry()) {
            return error.RetriesExhausted;
        }
        self.attempt += 1;
    }

    /// Calculate delay for current attempt.
    pub fn currentDelay(self: *const RetryState) u64 {
        if (self.attempt == 0) return 0;
        return util.calculateBackoff(
            self.base_delay_ms,
            self.max_delay_ms,
            self.attempt - 1,
            self.use_exponential,
        );
    }

    /// Wait for the calculated delay.
    pub fn wait(self: *const RetryState) void {
        const delay = self.currentDelay();
        if (delay > 0) {
            util.sleepMs(delay);
        }
    }

    /// Get remaining retry attempts.
    pub fn remainingAttempts(self: *const RetryState) u32 {
        if (self.attempt >= self.max_attempts) return 0;
        return self.max_attempts - self.attempt;
    }
};

/// Determine if an error should trigger a retry.
///
/// Returns true for transient errors that may succeed on retry.
pub fn shouldRetry(err: anyerror) bool {
    return util.isRetryableError(err);
}

/// Errors that should trigger retries.
pub const RetryableErrors = struct {
    pub const connection = [_]anyerror{
        error.ConnectionFailed,
        error.ConnectionTimeout,
        error.ConnectionResetByPeer,
    };

    pub const network = [_]anyerror{
        error.NetworkUnreachable,
        error.HostUnreachable,
    };

    pub const server = [_]anyerror{
        error.ServerError,
    };
};

test "retry state initialization" {
    var config = Config.default();
    config.max_retries = 3;

    const state = RetryState.init(config);
    try std.testing.expect(state.max_attempts == 4);
    try std.testing.expect(state.canRetry());
}

test "retry state advancement" {
    var config = Config.default();
    config.max_retries = 2;

    var state = RetryState.init(config);
    try std.testing.expect(state.remainingAttempts() == 3);

    try state.nextAttempt();
    try std.testing.expect(state.remainingAttempts() == 2);

    try state.nextAttempt();
    try std.testing.expect(state.remainingAttempts() == 1);
}

test "retry delay calculation" {
    var config = Config.default();
    config.retry_delay_ms = 1000;
    config.exponential_backoff = true;

    var state = RetryState.init(config);
    try std.testing.expect(state.currentDelay() == 0); // First attempt, no delay

    try state.nextAttempt();
    // After first failure, should have some delay
    try std.testing.expect(state.currentDelay() > 0);
}

test "should retry determination" {
    try std.testing.expect(shouldRetry(error.ConnectionFailed));
    try std.testing.expect(shouldRetry(error.ConnectionTimeout));
}
