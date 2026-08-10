const c = @cImport({
    @cInclude("rtl-sdr.h");
});

const std = @import("std");

const CENTER_FREQ = 1035_000_00;
const SAMPLE_RATE = 2_000_000;
const BUFFER_SIZE = 262144;
var buffer: [BUFFER_SIZE]u8 = undefined;
var n_read: c_int = 0;

var dev: ?*c.rtlsdr_dev_t = null;
var devname: ?[*c]const u8 = null;

pub fn sleep(t: u8) void {
    var ts: std.posix.timespec = .{ .sec = t, .nsec = 0 };
    _ = std.posix.system.nanosleep(&ts, &ts);
}

pub fn main(init: std.process.Init) !void {
    // C-style

    const io = init.io;

    const devicecount = c.rtlsdr_get_device_count();
    if (devicecount < 0) {
        std.debug.print("Error: {d}\n", .{devicecount});
        return;
    } else {
        std.debug.print("Found {d} devices\n", .{devicecount});
        devname = c.rtlsdr_get_device_name(0);

        std.debug.print("device name is {s}\n", .{devname.?});

        if (c.rtlsdr_open(&dev, 0) == 0) {
            std.debug.print("Device open successfully...\n", .{});

            _ = c.rtlsdr_set_center_freq(dev, CENTER_FREQ);
            _ = c.rtlsdr_set_sample_rate(dev, SAMPLE_RATE);
            _ = c.rtlsdr_set_tuner_gain_mode(dev, 0);
            _ = c.rtlsdr_reset_buffer(dev);

            sleep(3);

            while (true) {
                const ret: c_int = c.rtlsdr_read_sync(dev, &buffer, BUFFER_SIZE, &n_read);
                if (ret == 0) {
                    const bytes = buffer[0..@intCast(n_read)];

                    var pcm_buffer = try std.heap.page_allocator.alloc(i16, bytes.len / 2);

                    defer std.heap.page_allocator.free(pcm_buffer);

                    var i: usize = 0;
                    var last_phase: f32 = 0.0;

                    while (i < bytes.len) : (i += 2) {
                        const sample_i = (@as(f32, @floatFromInt(bytes[i])) - 127.5) / 127.5;
                        const sample_q = (@as(f32, @floatFromInt(bytes[i + 1])) - 127.5) / 127.5;
                        const current_phase = std.math.atan2(sample_q, sample_i);

                        var phase_delta = current_phase - last_phase;
                        last_phase = current_phase;

                        // Normalize phase wrapping anomalies (-PI to +PI boundaries)
                        if (phase_delta > std.math.pi) {
                            phase_delta -= 2.0 * std.math.pi;
                        } else if (phase_delta < -std.math.pi) {
                            phase_delta += 2.0 * std.math.pi;
                        }
                        pcm_buffer[i / 2] = @intFromFloat(phase_delta * 10000.0);
                    }
                    const pcm_bytes = std.mem.sliceAsBytes(pcm_buffer);
                    try std.Io.File.stdout().writeStreamingAll(io, pcm_bytes);
                } else {
                    std.debug.print("error....", .{});
                    break;
                }
            }

            defer _ = c.rtlsdr_close(dev);
            std.debug.print("Device closed successfully...\n", .{});
        }
    }
}
