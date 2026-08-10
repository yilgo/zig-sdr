const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig_sdr",
        .root_module = exe_mod,
    });

    // 1. Extract the fetched C repository path
    const zig_sdr_dep = b.dependency("rtl_sdr", .{});

    // 2. Enable C compilation support
    exe_mod.link_libc = true;

    // 3. Add the library's header directories
    exe_mod.addIncludePath(zig_sdr_dep.path("include"));
    exe_mod.addIncludePath(zig_sdr_dep.path("src"));

    // rtl-sdr talks to devices over libusb
    exe_mod.linkSystemLibrary("usb-1.0", .{});

    // 4. Compile the specific C source files directly into your project
    exe_mod.addCSourceFiles(.{
        .root = zig_sdr_dep.path("src"),
        .files = &.{
            "librtlsdr.c",
            "tuner_e4k.c",
            "tuner_fc0012.c",
            "tuner_fc0013.c",
            "tuner_fc2580.c",
            "tuner_r82xx.c",
        },
        .flags = &.{ "-std=c99", "-D_DEFAULT_SOURCE", "-O3" },
    });

    b.installArtifact(exe);
}
