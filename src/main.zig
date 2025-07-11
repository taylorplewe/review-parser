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
    body: []u8,
};
const Note = []const u8;
const Element = union(enum) {
    Review: Review,
    Note: Note,
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

    var blocks = std.ArrayList(Element).init(arena.allocator());
    var currReview: ?Review = null;
    const file_reader = file.reader();

    // iterate over each line
    while (try file_reader.readUntilDelimiterOrEofAlloc(arena.allocator(), '\n', 65536)) |line| {
        if (line.len > 2 and std.mem.eql(u8, line[0..2], "--")) {
            const note: Note = try arena.allocator().dupe(u8, line);
            try blocks.append(Element{ .Note = note });
        } else if (line.len > 4 and std.mem.eql(u8, line[0..4], "### ")) {
            currReview = .{
                .title = try arena.allocator().dupe(u8, line[4..]),
                .score = 0,
                .body = "",
            };
        }
    }

    try stdOutWriter.print("\x1b[32mOK:\x1b[0m successfully wrote to game review markdown file.\n", .{});
}
