const std = @import("std");
const Scanner = @import("Scanner.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    switch (args.len) {
        1 => try runPrompt(allocator),
        2 => try runFile(allocator, args[1]),
        else => {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Usage: lox [path]\n", .{});
            std.process.exit(64);
        },
    }
}

fn runPrompt(allocator: std.mem.Allocator) !void {
    const stderr = std.io.getStdErr().writer();
    const stdin = std.io.getStdIn();

    var sourceBuf: [256]u8 = undefined;
    while (true) {
        try stderr.print("> ", .{});
        const amt = try stdin.read(&sourceBuf);
        if (amt == sourceBuf.len) {
            try stderr.print("Input too long.\n", .{});
            continue;
        }
        const source = sourceBuf[0..amt];
        try run(allocator, source);
    }
}

fn runFile(allocator: std.mem.Allocator, path: []const u8) !void {
    const source = try std.fs.cwd().readFileAlloc(allocator, path, 1_000_000);
    defer allocator.free(source);
    try run(allocator, source);
}

fn run(allocator: std.mem.Allocator, source: []const u8) !void {
    var scanner = Scanner.init(allocator, source);
    const tokens = try scanner.scanTokens();
    for (tokens.items) |token| {
        std.debug.print("{} ({s})\n", .{ token.type, token.lexeme });
    }
}
