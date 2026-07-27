### Godot Fast WFC

This is a wrapper of a C++ version of a WFC algorithm. This plugin includes three quick demos as well as the sample data used in the repo of the core algorithm.

The authors of the core algorithm provide much more detail on their project page.

https://github.com/mxgmn/WaveFunctionCollapse

https://github.com/math-fehr/fast-wfc

### Building

You should have [godot-cpp](github.com/godotengine/godot-cpp/) cloned next to this repository's folder. Ensure that you have built the templates for linking to your specified platform/target/arch before you attempt to build the addon.

```zsh
scons platform=... arch=...
```
```
Options:
  platform=<platform>  Target platform (windows, linux, macos)
  target=<target>       Build target (debug, release) [default: release]
  arch=<architecture>   Target architecture (x86_64, arm64) [default: x86_64]

Examples:
  scons platform=windows target=debug
  scons platform=linux target=release
  scons platform=macos
```

*Note: Targeting MacOS will always build universal binaries.*
