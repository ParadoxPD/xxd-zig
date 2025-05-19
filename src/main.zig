const std = @import("std");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const raw_args = try std.process.argsAlloc(allocator);
    defer allocator.free(raw_args);

    var args = try allocator.alloc([]const u8, raw_args.len);
    defer allocator.free(args);

    for (raw_args, 0..) |cstr, i| {
        args[i] = std.mem.sliceTo(cstr, 0);
    }

    var parsed_args = try parse_commandline(args);
    defer parsed_args.deinit();

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    const writer = list.writer();

    if (parsed_args.get("-t")) |value| {
        //try stdout.print("Value : {s}\n", .{value});
        try hex_dump(writer, value);

        const hex_str = try list.toOwnedSlice();
        defer allocator.free(hex_str);
        try stdout.print("{s}\n", .{hex_str});
    }
    if (parsed_args.get("-i")) |value| {
        //try stdout.print("Value : {s}\n", .{value});
        try hex_dump_file(writer, value);

        const hex_str = try list.toOwnedSlice();
        defer allocator.free(hex_str);
        try stdout.print("{s}\n", .{hex_str});
    }
}

fn parse_commandline(args: [][]const u8) !std.StringHashMap([]const u8) {
    var help_flag = false;
    const alloc = std.heap.page_allocator;

    var parsed_args = std.StringHashMap([]const u8).init(alloc);
    //defer parsed_args.deinit();

    var i: usize = 1;
    while (i < args.len) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-i")) {
            i += 1;
            if (i < args.len) {
                try parsed_args.put("-i", args[i]);
            } else {
                return error.MissingInputFile;
            }
        } else if (std.mem.eql(u8, arg, "-o")) {
            i += 1;
            if (i < args.len) {
                try parsed_args.put("-o", args[i]);
            } else {
                return error.MissingOutputFile;
            }
        } else if (std.mem.eql(u8, arg, "-t")) {
            i += 1;
            if (i < args.len) {
                try parsed_args.put("-t", args[i]);
            } else {
                return error.MissingInputText;
            }
        } else if (std.mem.eql(u8, arg, "-h")) {
            help_flag = true;
        } else {
            try stdout.print("Unknown argument: {s}\n", .{arg});
            return error.UnknownArgument;
        }
        i += 1;
    }

    if (help_flag) {
        try show_help();
    }

    // Enforce exclusive use of -i or -t
    if (parsed_args.contains("-t") and parsed_args.contains("-i")) {
        try stdout.print("Error: You can use either -i or -t, but not both.\n", .{});
        return error.ConflictingInputSources;
    }

    return parsed_args;
}

fn show_help() !void {
    try stdout.print(
        \\Usage: zig run main.zig -- [-i <input_file>] [-o <output_file>] [-t <input_text>] [-h]
        \\  -i  Input file path
        \\  -o  Output file path
        \\  -t  Input data as a string
        \\  -h  Show help
        \\Note: Use only one of -i or -t
        \\
    , .{});
}

fn hex_dump(writer: anytype, data: []const u8) !void {
    var offset: usize = 0;
    const buffer_size = 16;
    var buffer: [buffer_size]u8 = undefined;

    while (offset < data.len) {
        const remaining = data.len - offset;
        const chunk_len = if (remaining < buffer_size) remaining else buffer_size;
        const slice = data[offset .. offset + chunk_len];

        std.mem.copyForwards(u8, buffer[0..chunk_len], slice);

        try writer.print("{x:0>8}: ", .{offset});

        // Print hex bytes
        for (buffer[0..chunk_len], 0..) |byte, i| {
            try writer.print("{x:0>2} ", .{byte});
            if (i == 7) try writer.print(" ", .{}); // extra space after 8 bytes
        }

        // Pad hex bytes if less than 16
        if (chunk_len < buffer_size) {
            for (chunk_len..buffer_size) |i| {
                try writer.print("   ", .{});
                if (i == 7) try writer.print(" ", .{});
            }
        }

        // Print ASCII representation
        try writer.print(" |", .{});
        for (buffer[0..chunk_len]) |byte| {
            const c = if (std.ascii.isPrint(byte)) byte else '.';
            try writer.print("{c}", .{c});
        }

        try writer.print("\n", .{});
        offset += chunk_len;
    }
}

const chunk_size = 4096;

fn hex_dump_file(writer: anytype, file_path: []const u8) !void {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buffer: [chunk_size]u8 = undefined;

    while (true) {
        const read_bytes = try file.read(&buffer);

        if (read_bytes == 0) break;

        try hex_dump(writer, buffer[0..read_bytes]);
    }
}
