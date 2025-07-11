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
    body: []const u8,
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
    var curr_review: ?Review = null;
    var curr_body = std.ArrayList(u8).init(arena.allocator());
    const file_reader = file.reader();

    // iterate over each line
    var is_parsing_review = false;
    while (try file_reader.readUntilDelimiterOrEofAlloc(arena.allocator(), '\n', 65535)) |line| {
        if (is_parsing_review) {
            if (line.len == 0) {
                is_parsing_review = false;
                curr_review.?.body = (try curr_body.clone()).items;
                try blocks.append(Element{ .Review = curr_review.? });
                // printElement(Element{ .Review = curr_review.? });
                // try waitForInput();
                continue;
            }
            try curr_body.appendSlice(try std.mem.concat(arena.allocator(), u8, &[_][]const u8{ line, "\n" }));
        } else if (line.len > 3 and std.mem.eql(u8, line[0..3], "-- ")) {
            const note: Note = try arena.allocator().dupe(u8, line);
            try blocks.append(Element{ .Note = note });
        } else if (line.len > 4 and std.mem.eql(u8, line[0..4], "### ")) {
            is_parsing_review = true;
            curr_review = .{
                .title = try arena.allocator().dupe(u8, line[4..]),
                .body = "",
            };
            curr_body.clearRetainingCapacity();
        }
    }

    for (blocks.items) |block| {
        printElement(block);
    }

    try stdOutWriter.print("\x1b[32mOK:\x1b[0m parse complete.\n", .{});
}

fn printElement(el: Element) void {
    if (el == .Review) {
        std.debug.print("title: {s}\nbody: {s}\n\n", .{ el.Review.title, el.Review.body });
    }
}

fn waitForInput() !void {
    var buf: [65536]u8 = undefined;
    _ = try std.io.getStdIn().reader().readUntilDelimiter(&buf, '\n');
}
