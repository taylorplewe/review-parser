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

    const args = try std.process.argsAlloc(arena.allocator());
    if (args.len < 2) {
        printErrorAndExit("must pass filename");
        unreachable;
    }
    const in_file_path: []const u8 = args[1];
    const out_file_path: []const u8 = if (args.len < 3) in_file_path else args[2];

    // open file for writing
    const in_file = std.fs.cwd().openFile(in_file_path, .{}) catch {
        printErrorAndExit("could not find file");
        unreachable;
    };

    var blocks = std.ArrayList(Element).init(arena.allocator());
    var curr_review: ?Review = null;
    var curr_body = std.ArrayList(u8).init(arena.allocator());
    const in_file_reader = in_file.reader();

    // iterate over each line
    var is_parsing_review = false;
    while (try in_file_reader.readUntilDelimiterOrEofAlloc(arena.allocator(), '\n', 65535)) |line| {
        if (is_parsing_review) {
            if (line.len == 0 or line[0] == '\r') {
                is_parsing_review = false;
                curr_review.?.body = try curr_body.toOwnedSlice();
                try blocks.append(Element{ .Review = curr_review.? });
                continue;
            }
            try curr_body.appendSlice(strWithNewline(arena.allocator(), line));
        } else if (line.len > 3 and std.mem.eql(u8, line[0..3], "-- ")) {
            const note: Note = strWithNewline(arena.allocator(), line);
            try blocks.append(Element{ .Note = note });
        } else if (line.len > 4 and std.mem.eql(u8, line[0..4], "### ")) {
            is_parsing_review = true;
            curr_review = .{
                .title = try arena.allocator().dupe(u8, line[4..]),
                .body = "",
            };
        }
    }
    if (is_parsing_review) {
        is_parsing_review = false;
        curr_review.?.body = (try curr_body.clone()).items;
        try blocks.append(Element{ .Review = curr_review.? });
    }
    in_file.close();

    // reverse list
    std.mem.reverse(Element, blocks.items);

    // write new list to file
    const out_file = std.fs.cwd().createFile(out_file_path, .{ .truncate = true }) catch {
        printErrorAndExit("could not create or open file for writing");
        unreachable;
    };
    defer out_file.close();
    try writeToFile(arena.allocator(), blocks.items, out_file);

    // debug
    // for (blocks.items) |block| {
    //     printElement(block);
    // }

    try stdOutWriter.print("\x1b[32mOK:\x1b[0m parse complete.\n", .{});
}

fn printErrorAndExit(msg: []const u8) void {
    const stdErrWriter = std.io.getStdErr().writer();
    stdErrWriter.print("\x1b[31mERROR: \x1b[0m{s}.\n", .{msg}) catch unreachable;
    std.process.exit(1);
}

fn writeToFile(allocator: std.mem.Allocator, els: []Element, file: std.fs.File) !void {
    const writer = file.writer();
    var output = std.ArrayList(u8).init(allocator);
    for (els) |el| {
        try output.appendSlice(switch (el) {
            .Review => try std.fmt.allocPrint(allocator, "### {s}\n{s}\n", .{ el.Review.title, el.Review.body }),
            .Note => try std.fmt.allocPrint(allocator, "{s}\n", .{el.Note}),
        });
    }
    try file.seekTo(0);
    _ = try writer.write("In descending chronological order\n\n");
    _ = try writer.write(output.items);
}

fn printElement(el: Element) void {
    switch (el) {
        .Review => std.debug.print("title: {s}\nbody: {s}\n---\n", .{ el.Review.title, el.Review.body }),
        .Note => std.debug.print("{s}\n---\n", .{el.Note}),
    }
}

fn waitForInput() void {
    var buf: [65536]u8 = undefined;
    _ = std.io.getStdIn().reader().readUntilDelimiter(&buf, '\n') catch unreachable;
}

fn strWithNewline(allocator: std.mem.Allocator, str: []u8) []u8 {
    return std.fmt.allocPrint(allocator, "{s}\n", .{str}) catch unreachable;
}
