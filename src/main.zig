// 2025 Taylor Plewe
//
// reverse order of game reviews
// each title of a game is a Markdown h3:
//   ### Halo Infinite
// followed by a score out of 10:
//    8/10
// followed by the body of the review, usually in bullet points:
//    - good music
//    - good graphics
// any content following this and before the next h3 or EOF belongs to this game block
//
// there are also little notes scattered throughout in the format
//    -- got a ps1 --
//
// each element is separated by at least two newlines

const std = @import("std");

const Review = struct {
    title: []const u8,
    score: u8,
    body: []const u8,
};
const Note = []const u8;
const Element = union(enum) {
    Review,
    Note,
};

pub fn main() !void {
    // prep
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const stdOutWriter = std.io.getStdOut().writer();
    const stdErrWriter = std.io.getStdErr().writer();

    const args = try std.process.argsAlloc(arena.allocator());
    if (args.len < 2) {
        try stdErrWriter.print("\x1b[31mERROR: \x1b[0mmust pass filename.\n", .{});
        std.process.exit(1);
    }

    const file = std.fs.cwd().openFile(args[1], .{}) catch {
        try stdErrWriter.print("\x1b[31mERROR:\x1b[0m could not find file.", .{});
        std.process.exit(1);
    };

    var blocks: std.MultiArrayList(Review) = .{};
    const file_reader = file.reader();

    try stdOutWriter.print("\x1b[32mOK:\x1b[0m successfully wrote to game review markdown file.\n", .{});
}
