//! Checksum verification example.
//!
//! Demonstrates how to verify the integrity of a downloaded file using SHA-256.

const std = @import("std");
const downloader = @import("downloader");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const url = "https://filesamples.com/samples/document/pdf/sample1.pdf";
    const output = "checksum_test.pdf";

    // You would normally get this from a trusted source
    // For this example, we'll use the hash of sample1.pdf
    const expected_sha256 = "6b22904a7de5b77bf40598c37e94e01771485e1b900651b58bf50af7009f8056";

    var config = downloader.Config.default();
    config.expected_checksum = expected_sha256;
    config.checksum_algorithm = .sha256;
    config.file_exists_action = .overwrite;

    var client = try downloader.Client.init(allocator, config);
    defer client.deinit();

    std.debug.print("[*] Downloading with SHA-256 verification...\n", .{});

    const bytes = client.download(url, output, null) catch |err| {
        if (err == error.ChecksumMismatch) {
            std.debug.print("\n[!] SECURITY ALERT: Checksum mismatch! The file may be corrupted or tampered with.\n", .{});
            return;
        }
        return err;
    };

    std.debug.print("[+] Downloaded and verified! ({d} bytes)\n", .{bytes});
}
