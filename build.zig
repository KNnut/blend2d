const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "blend2d",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });

    const upstream_dep = b.dependency("blend2d", .{
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addIncludePath(upstream_dep.path(""));
    lib.root_module.addCMacro("BL_STATIC", "");

    switch (target.result.cpu.arch) {
        .x86, .x86_64 => {
            if (target.result.cpu.has(.x86, .sse2))
                lib.root_module.addCMacro("BL_BUILD_OPT_SSE2", "");

            if (target.result.cpu.has(.x86, .sse3))
                lib.root_module.addCMacro("BL_BUILD_OPT_SSE3", "");

            if (target.result.cpu.has(.x86, .ssse3))
                lib.root_module.addCMacro("BL_BUILD_OPT_SSSE3", "");

            if (target.result.cpu.has(.x86, .sse4_1))
                lib.root_module.addCMacro("BL_BUILD_OPT_SSE4_1", "");

            if (target.result.cpu.hasAll(.x86, &.{ .popcnt, .pclmul, .sse4_2 }))
                lib.root_module.addCMacro("BL_BUILD_OPT_SSE4_2", "");

            if (target.result.cpu.hasAll(.x86, &.{ .popcnt, .pclmul, .avx }))
                lib.root_module.addCMacro("BL_BUILD_OPT_AVX", "");

            if (target.result.cpu.hasAll(.x86, &.{ .popcnt, .pclmul, .bmi, .bmi2, .avx2 }))
                lib.root_module.addCMacro("BL_BUILD_OPT_AVX2", "");

            if (target.result.cpu.hasAll(.x86, &.{ .popcnt, .pclmul, .bmi, .bmi2, .avx512f, .avx512bw, .avx512dq, .avx512cd, .avx512vl }))
                lib.root_module.addCMacro("BL_BUILD_OPT_AVX512", "");
        },
        .aarch64 => {
            lib.root_module.addCMacro("BL_BUILD_OPT_ASIMD", "");

            if (target.result.cpu.hasAll(.aarch64, &.{ .aes, .crc, .crypto })) {
                lib.root_module.addCMacro("BL_TARGET_OPT_ASIMD_CRYPTO", "");
                lib.root_module.addCMacro("BL_BUILD_OPT_ASIMD_CRYPTO", "");
            }
        },
        else => {},
    }

    {
        const jit = b.option(bool, "jit", "Enable JIT pipelines generation support") orelse
            switch (target.result.cpu.arch) {
                .aarch64, .x86, .x86_64 => true,
                else => false,
            };
        const jit_logging = b.option(bool, "jit-logging", "Enable JIT pipelines logging support") orelse jit;
        const futex = b.option(bool, "futex", "Enable futex support") orelse true;
        const tls = b.option(bool, "tls", "Enable the use of thread-local storage") orelse true;

        const flags = .{ jit, futex, tls };
        const macros = .{ "JIT", "FUTEX", "TLS" };
        inline for (flags, macros) |flag, macro|
            if (!flag)
                lib.root_module.addCMacro("BL_BUILD_NO_" ++ macro, "");

        if (jit) {
            if (b.lazyDependency("asmjit", .{
                .target = target,
                .optimize = optimize,
                .text = jit_logging,
                .logging = jit_logging,
                .aarch64 = target.result.cpu.arch == .aarch64,
                .x86 = switch (target.result.cpu.arch) {
                    .x86, .x86_64 => true,
                    else => false,
                },
            })) |asmjit_dep|
                lib.root_module.linkLibrary(asmjit_dep.artifact("asmjit"));
            if (!jit_logging)
                lib.root_module.addCMacro("ASMJIT_NO_LOGGING", "");
        }
    }

    {
        const dirs = .{
            "codec",     "compression", "core",         "geometry",
            "opentype",  "pipeline",    "pipeline/jit", "pipeline/reference",
            "pixelops",  "raster",      "support",      "tables",
            "threading", "unicode",
            // "simd",
        };
        const srcs = .{
            codec_srcs,     compression_srcs, core_srcs,         geometry_srcs,
            opentype_srcs,  pipeline_srcs,    pipeline_jit_srcs, pipeline_reference_srcs,
            pixelops_srcs,  raster_srcs,      support_srcs,      tables_srcs,
            threading_srcs, unicode_srcs,
            // simd_srcs,
        };

        var cppflags: std.ArrayList([]const u8) = .empty;
        try cppflags.appendSlice(b.allocator, &.{
            "-fvisibility=hidden",
            "-fno-exceptions",
            "-fno-rtti",
            "-fno-math-errno",
            "-fno-threadsafe-statics",
            "-fno-semantic-interposition",
            "-fno-trapping-math",
            "-fno-finite-math-only",
            "-mllvm",
            "--disable-loop-idiom-all",
        });
        if (optimize != .Debug)
            try cppflags.appendSlice(b.allocator, &.{
                "-fmerge-all-constants",
                "-ftree-vectorize",
            });

        inline for (dirs, srcs) |dir, src|
            lib.root_module.addCSourceFiles(.{
                .language = .cpp,
                .root = upstream_dep.path("blend2d/" ++ dir),
                .files = src,
                .flags = cppflags.items,
            });
    }

    lib.installHeadersDirectory(upstream_dep.path("blend2d"), "blend2d", .{});
    b.installArtifact(lib);
}

// blend2d/core
const core_srcs = &[_][]const u8{
    "api-globals.cpp",
    "api-nocxx.cpp",
    "array.cpp",
    "bitarray.cpp",
    "bitset.cpp",
    "compopinfo.cpp",
    "context.cpp",
    "filesystem.cpp",
    "font.cpp",
    "fontdata.cpp",
    "fontface.cpp",
    "fontfeaturesettings.cpp",
    "fontmanager.cpp",
    "fonttagdataids.cpp",
    "fonttagdatainfo.cpp",
    "fonttagset.cpp",
    "fontvariationsettings.cpp",
    "format.cpp",
    "glyphbuffer.cpp",
    "gradient.cpp",
    "image.cpp",
    "imagecodec.cpp",
    "imagedecoder.cpp",
    "imageencoder.cpp",
    "imagescale.cpp",
    "matrix.cpp",
    "matrix_avx.cpp",
    "matrix_sse2.cpp",
    "object.cpp",
    "path.cpp",
    "pathstroke.cpp",
    "pattern.cpp",
    "pixelconverter.cpp",
    "pixelconverter_avx2.cpp",
    "pixelconverter_sse2.cpp",
    "pixelconverter_ssse3.cpp",
    "random.cpp",
    "runtime.cpp",
    "runtimescope.cpp",
    "string.cpp",
    "trace.cpp",
    "var.cpp",
};

// blend2d/codec
const codec_srcs = &[_][]const u8{
    "bmpcodec.cpp",
    "jpegcodec.cpp",
    "jpeghuffman.cpp",
    "jpegops.cpp",
    "jpegops_sse2.cpp",
    "pngcodec.cpp",
    "pngops.cpp",
    "pngops_asimd.cpp",
    "pngops_avx.cpp",
    "pngops_sse2.cpp",
    "qoicodec.cpp",
};

// blend2d/compression
const compression_srcs = &[_][]const u8{
    "checksum.cpp",
    "checksum_asimd.cpp",
    "checksum_asimd_crypto.cpp",
    "checksum_sse2.cpp",
    "checksum_sse4_2.cpp",
    "deflatedecoder.cpp",
    "deflatedecoderfast.cpp",
    "deflatedecoderfast_avx2.cpp",
    "deflatedecoderutils.cpp",
    "deflatedefs.cpp",
    "deflateencoder.cpp",
};

// blend2d/geometry
const geometry_srcs = &[_][]const u8{
    "sizetable.cpp",
};

// blend2d/opentype
const opentype_srcs = &[_][]const u8{
    "otcff.cpp",
    "otcmap.cpp",
    "otcore.cpp",
    "otface.cpp",
    "otglyf.cpp",
    "otglyf_asimd.cpp",
    "otglyf_avx2.cpp",
    "otglyf_sse4_2.cpp",
    "otglyfsimddata.cpp",
    "otkern.cpp",
    "otlayout.cpp",
    "otmetrics.cpp",
    "otname.cpp",
};

// blend2d/pipeline
const pipeline_srcs = &[_][]const u8{
    "pipedefs.cpp",
    "piperuntime.cpp",
};

// blend2d/pipeline/jit
const pipeline_jit_srcs = &[_][]const u8{
    "compoppart.cpp",
    "fetchgradientpart.cpp",
    "fetchpart.cpp",
    "fetchpatternpart.cpp",
    "fetchpixelptrpart.cpp",
    "fetchsolidpart.cpp",
    "fetchutilscoverage.cpp",
    "fetchutilsinlineloops.cpp",
    "fetchutilspixelaccess.cpp",
    "fetchutilspixelgather.cpp",
    "fillpart.cpp",
    "pipecompiler.cpp",
    "pipecomposer.cpp",
    "pipefunction.cpp",
    "pipeprimitives.cpp",
    "pipegenruntime.cpp",
    "pipepart.cpp",
};

// blend2d/pipeline/reference
const pipeline_reference_srcs = &[_][]const u8{
    "fixedpiperuntime.cpp",
};

// blend2d/pixelops
const pixelops_srcs = &[_][]const u8{
    "interpolation.cpp",
    "interpolation_avx2.cpp",
    "interpolation_sse2.cpp",
    "funcs.cpp",
};

// blend2d/raster
const raster_srcs = &[_][]const u8{
    "rastercontext.cpp",
    "rastercontextops.cpp",
    "renderfetchdata.cpp",
    "rendertargetinfo.cpp",
    "workdata.cpp",
    "workermanager.cpp",
    "workerproc.cpp",
    "workersynchronization.cpp",
};

// // blend2d/simd
// const simd_srcs = &[_][]const u8{};

// blend2d/support
const support_srcs = &[_][]const u8{
    "arenaallocator.cpp",
    "arenahashmap.cpp",
    "math.cpp",
    "scopedallocator.cpp",
    "zeroallocator.cpp",
};

// blend2d/tables
const tables_srcs = &[_][]const u8{
    "tables.cpp",
};

// blend2d/threading
const threading_srcs = &[_][]const u8{
    "futex.cpp",
    "thread.cpp",
    "threadpool.cpp",
    "uniqueidgenerator.cpp",
};

// blend2d/unicode
const unicode_srcs = &[_][]const u8{
    "unicode.cpp",
};
