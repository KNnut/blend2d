# Blend2D

[Blend2D](https://blend2d.com/) on the [Zig Build System](https://ziglang.org/learn/build-system/).

## Usage

Add this package to `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/KNnut/blend2d
```

And then import `blend2d` in `build.zig` with:

```zig
const blend2d_dep = b.dependency("blend2d", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.linkLibrary(blend2d_dep.artifact("blend2d"));
```
