//! Retry Logic and Backoff Strategies
//!
//! Provides configurable retry behavior with exponential backoff,
//! jitter, and circuit breaker patterns for robust downloads.

const std = @import("std");
const config_mod = @import("config.zig");
const Config = config_mod.Config;
const errors = @import("errors.zig");
const DownloadError = errors.DownloadError;

/// Backoff strategy for retries.
pub const BackoffStrategy = enum {
    /// No delay between retries.
    none,
    /// Fixed delay between retries.
    fixed,
    /// Exponential backoff (delay doubles each attempt).
    exponential,
    /// Exponential with random jitter.
    exponential_with_jitter,
    /// Linear backoff (delay increases linearly).
    linear,
};

/// Retry state manager.
///
/// Tracks retry attempts and calculates appropriate delays.
pub const RetryState = struct {
    current_attempt: u32,
    max_attempts: u32,
    base_delay_ms: u64,
    max_delay_ms: u64,
    use_exponential: bool,
    use_jitter: bool,
    last_error: ?DownloadError,
    total_delay_ms: u64,

    /// Random number generator for jitter.
    rng: std.Random.DefaultPrng,

    /// Initialize retry state from configuration.
    pub fn init(config: Config) RetryState {
        return .{
            .current_attempt = 0,
            .max_attempts = config.max_retries + 1, // +1 for initial attempt
            .base_delay_ms = config.retry_delay_ms,
            .max_delay_ms = config.max_retry_delay_ms,
            .use_exponential = config.exponential_backoff,
            .use_jitter = false,
            .last_error = null,
            .total_delay_ms = 0,
            .rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp())),
        };
    }

    /// Initialize with custom settings.
    pub fn initCustom(
        max_attempts: u32,
        base_delay_ms: u64,
        max_delay_ms: u64,
        strategy: BackoffStrategy,
    ) RetryState {
        return .{
            .current_attempt = 0,
            .max_attempts = max_attempts,
            .base_delay_ms = base_delay_ms,
            .max_delay_ms = max_delay_ms,
            .use_exponential = strategy == .exponential or strategy == .exponential_with_jitter,
            .use_jitter = strategy == .exponential_with_jitter,
            .last_error = null,
            .total_delay_ms = 0,
            .rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp())),
        };
    }

    /// Check if more retry attempts are available.
    pub fn canRetry(self: *const RetryState) bool {
        return self.current_attempt < self.max_attempts;
    }

    /// Check if this is the last attempt.
    pub fn isLastAttempt(self: *const RetryState) bool {
        return self.current_attempt >= self.max_attempts - 1;
    }

    /// Get remaining retry attempts.
    pub fn remainingAttempts(self: *const RetryState) u32 {
        if (self.current_attempt >= self.max_attempts) return 0;
        return self.max_attempts - self.current_attempt;
    }

    /// Calculate delay for current attempt.
    pub fn currentDelay(self: *RetryState) u64 {
        if (self.current_attempt == 0) return 0;

        var delay: u64 = self.base_delay_ms;

        if (self.use_exponential) {
            // Exponential backoff: delay = base * 2^(attempt-1)
            const shift = @min(self.current_attempt - 1, 10); // Cap to prevent overflow
            delay = self.base_delay_ms << @intCast(shift);
        }

        // Add jitter (up to 25% of delay)
        if (self.use_jitter and delay > 0) {
            const jitter_range = delay / 4;
            if (jitter_range > 0) {
                const jitter = self.rng.random().uintAtMost(u64, jitter_range);
                delay += jitter;
            }
        }

        // Cap at maximum delay
        return @min(delay, self.max_delay_ms);
    }

    /// Advance to next attempt.
    pub fn nextAttempt(self: *RetryState) !void {
        if (!self.canRetry()) {
            return error.OutOfMemory; // Using OutOfMemory as a placeholder
        }
        self.current_attempt += 1;
    }

    /// Wait for the calculated delay.
    pub fn wait(self: *RetryState) void {
        const delay = self.currentDelay();
        if (delay > 0) {
            self.total_delay_ms += delay;
            std.Thread.sleep(delay * std.time.ns_per_ms);
        }
    }

    /// Record an error from last attempt.
    pub fn recordError(self: *RetryState, err: DownloadError) void {
        self.last_error = err;
    }

    /// Get statistics about retry attempts.
    pub fn stats(self: *const RetryState) RetryStats {
        return .{
            .attempts_made = self.current_attempt,
            .max_attempts = self.max_attempts,
            .total_delay_ms = self.total_delay_ms,
            .last_error = self.last_error,
        };
    }

    /// Reset state for a new download.
    pub fn reset(self: *RetryState) void {
        self.current_attempt = 0;
        self.last_error = null;
        self.total_delay_ms = 0;
    }
};

/// Statistics about retry attempts.
pub const RetryStats = struct {
    attempts_made: u32,
    max_attempts: u32,
    total_delay_ms: u64,
    last_error: ?DownloadError,

    /// Check if any retries were needed.
    pub fn hadRetries(self: RetryStats) bool {
        return self.attempts_made > 1;
    }
};

/// Check if an error should trigger a retry.
pub fn shouldRetry(err: DownloadError) bool {
    return errors.isRetryable(err);
}

/// Get recommended delay for a specific error.
pub fn delayForError(err: DownloadError, base_delay: u64) u64 {
    return switch (err) {
        // Server overloaded - wait longer
        .TooManyRequests => base_delay * 5,
        .ServiceUnavailable => base_delay * 3,

        // Network issues - normal delay
        .ConnectionFailed, .ConnectionReset, .ConnectionTimeout => base_delay,

        // Other - shorter delay
        else => base_delay / 2,
    };
}

/// Circuit breaker state for managing repeated failures.
pub const CircuitBreaker = struct {
    state: State,
    failure_count: u32,
    success_count: u32,
    failure_threshold: u32,
    success_threshold: u32,
    last_failure_time: i64,
    cooldown_ms: u64,

    pub const State = enum {
        closed, // Normal operation
        open, // Failing, reject requests
        half_open, // Testing if service recovered
    };

    /// Initialize circuit breaker with defaults.
    pub fn init() CircuitBreaker {
        return .{
            .state = .closed,
            .failure_count = 0,
            .success_count = 0,
            .failure_threshold = 5,
            .success_threshold = 3,
            .last_failure_time = 0,
            .cooldown_ms = 30000, // 30 seconds
        };
    }

    /// Initialize with custom thresholds.
    pub fn initCustom(
        failure_threshold: u32,
        success_threshold: u32,
        cooldown_ms: u64,
    ) CircuitBreaker {
        return .{
            .state = .closed,
            .failure_count = 0,
            .success_count = 0,
            .failure_threshold = failure_threshold,
            .success_threshold = success_threshold,
            .last_failure_time = 0,
            .cooldown_ms = cooldown_ms,
        };
    }

    /// Check if request should be allowed.
    pub fn allowRequest(self: *CircuitBreaker) bool {
        switch (self.state) {
            .closed => return true,
            .open => {
                // Check if cooldown has passed
                const now = std.time.milliTimestamp();
                if (now - self.last_failure_time >= @as(i64, @intCast(self.cooldown_ms))) {
                    self.state = .half_open;
                    return true;
                }
                return false;
            },
            .half_open => return true,
        }
    }

    /// Record a successful request.
    pub fn recordSuccess(self: *CircuitBreaker) void {
        switch (self.state) {
            .closed => {
                self.failure_count = 0;
            },
            .half_open => {
                self.success_count += 1;
                if (self.success_count >= self.success_threshold) {
                    self.state = .closed;
                    self.failure_count = 0;
                    self.success_count = 0;
                }
            },
            .open => {},
        }
    }

    /// Record a failed request.
    pub fn recordFailure(self: *CircuitBreaker) void {
        self.last_failure_time = std.time.milliTimestamp();
        self.failure_count += 1;

        switch (self.state) {
            .closed => {
                if (self.failure_count >= self.failure_threshold) {
                    self.state = .open;
                }
            },
            .half_open => {
                self.state = .open;
                self.success_count = 0;
            },
            .open => {},
        }
    }

    /// Get current state.
    pub fn getState(self: *const CircuitBreaker) State {
        return self.state;
    }

    /// Reset circuit breaker.
    pub fn reset(self: *CircuitBreaker) void {
        self.state = .closed;
        self.failure_count = 0;
        self.success_count = 0;
    }
};

// Tests
test "retry state init" {
    const config = Config.default();
    const state = RetryState.init(config);
    try std.testing.expect(state.canRetry());
    try std.testing.expect(state.current_attempt == 0);
}

test "retry state exhausted" {
    var state = RetryState.initCustom(2, 100, 1000, .fixed);
    try std.testing.expect(state.canRetry());

    try state.nextAttempt();
    try std.testing.expect(state.canRetry());

    try state.nextAttempt();
    try std.testing.expect(!state.canRetry());
}

test "exponential backoff" {
    var state = RetryState.initCustom(5, 100, 10000, .exponential);

    try state.nextAttempt();
    const delay1 = state.currentDelay();
    try std.testing.expect(delay1 == 100);

    try state.nextAttempt();
    const delay2 = state.currentDelay();
    try std.testing.expect(delay2 == 200);

    try state.nextAttempt();
    const delay3 = state.currentDelay();
    try std.testing.expect(delay3 == 400);
}

test "should retry" {
    try std.testing.expect(shouldRetry(DownloadError.ConnectionFailed));
    try std.testing.expect(shouldRetry(DownloadError.ConnectionTimeout));
    try std.testing.expect(!shouldRetry(DownloadError.NotFound));
    try std.testing.expect(!shouldRetry(DownloadError.Cancelled));
}

test "circuit breaker" {
    var cb = CircuitBreaker.init();
    try std.testing.expect(cb.getState() == .closed);
    try std.testing.expect(cb.allowRequest());

    // Record failures up to threshold
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        cb.recordFailure();
    }

    try std.testing.expect(cb.getState() == .open);
}
