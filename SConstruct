import os
import sys
import SCons.Script

# Initialize environment
env = SCons.Script.Environment()

# Platform detection with argument override
platform = ARGUMENTS.get("platform", "")
if not platform:
    if sys.platform == "win32":
        platform = "windows"
    elif sys.platform == "darwin":
        platform = "macos"
    else:
        platform = "linux"

env["platform"] = platform

# Set target based on environment variable or default to release
env["target"] = ARGUMENTS.get("target", "release")

# Architecture (for cross-compilation support)
arch = ARGUMENTS.get("arch", "x86_64")

# Path to godot-cpp
godot_cpp_path = "../../godot-cpp"

# Add include paths
env.Append(CPPPATH=[
    godot_cpp_path + "/include/",
    godot_cpp_path + "/gen/include/",
    godot_cpp_path + "/gdextension/",
    "src/fast-wfc/src/include/",
    "src/include/",
    "src/fast-wfc/src/include/.."
])

# Platform-specific settings
if env["platform"] == "windows":
    # Use native Windows tools (MinGW-w64 or MSVC)
    # Check if we're using MinGW-w64 or MSVC
    import platform
    if platform.system() == "Windows":
        # Use native MinGW-w64 on Windows
        env["CXX"] = "g++"
        env["CC"] = "gcc"
        env["AR"] = "ar"
        env["RANLIB"] = "ranlib"
        env["LINK"] = "g++"
    else:
        # Cross-compile for Windows using MinGW-w64 on Linux
        env["CXX"] = "x86_64-w64-mingw32-g++"
        env["CC"] = "x86_64-w64-mingw32-gcc"
        env["AR"] = "x86_64-w64-mingw32-ar"
        env["RANLIB"] = "x86_64-w64-mingw32-ranlib"
        env["LINK"] = "x86_64-w64-mingw32-g++"
    
    # GCC-style flags for MinGW (NOT MSVC flags)
    env.Append(CCFLAGS=["-std=c++17", "-fexceptions"])
    env.Append(LINKFLAGS=["-static-libgcc", "-static-libstdc++", "-static"])
    
    if env["target"] == "debug":
        env.Append(CCFLAGS=["-g", "-O0"])
    else:
        env.Append(CCFLAGS=["-O3"])
    
    # Windows library suffix and extension
    lib_suffix = f".{arch}"
    shared_lib_extension = ".dll"
    
elif env["platform"] == "macos":
    # macOS-specific settings
    env.Append(CCFLAGS=["-std=c++17", "-fexceptions"])
    if env["target"] == "debug":
        env.Append(CCFLAGS=["-g", "-O0"])
    else:
        env.Append(CCFLAGS=["-O3"])
    
    lib_suffix = ""
    shared_lib_extension = ".dylib"
    
else:  # Linux
    # Linux-specific settings
    env.Append(CCFLAGS=["-std=c++17", "-fexceptions", "-fPIC"])
    if env["target"] == "debug":
        env.Append(CCFLAGS=["-g", "-O0"])
    else:
        env.Append(CCFLAGS=["-O3"])
    
    lib_suffix = f".{arch}"
    shared_lib_extension = ".so"

# Add library paths
env.Append(LIBPATH=[godot_cpp_path + "/bin/"])

# Platform-specific library linking
if env["platform"] == "macos":
    lib_suffix_for_linking = ""
else:
    lib_suffix_for_linking = lib_suffix

env.Append(LIBS=[f"godot-cpp.{env['platform']}.template_{env['target']}{lib_suffix_for_linking}"])

# Sources for extension
sources = Glob("src/lib/*.cpp") + Glob("src/fast-wfc/src/lib/*.cpp") + ["src/include/register_types.cpp"]

# Ensure the bin directory exists
if not os.path.exists("bin"):
    os.makedirs("bin")

# Build the extension
if env["platform"] == "macos":
    library = env.SharedLibrary(
        f"bin/libfast_wfc.{env['platform']}.{env['target']}.framework/libfast_wfc.{env['platform']}.{env['target']}",
        source=sources,
    )
else:
    library = env.SharedLibrary(
        f"bin/libfast_wfc{lib_suffix}.{env['platform']}.{env['target']}{shared_lib_extension}",
        source=sources,
    )

Default(library)

# Help text
Help("""
Usage: scons [options]

Options:
  platform=<platform>  Target platform (windows, linux, macos)
  target=<target>       Build target (debug, release) [default: release]
  arch=<architecture>   Target architecture (x86_64, arm64) [default: x86_64]

Examples:
  scons platform=windows target=debug
  scons platform=linux target=release
  scons platform=macos arch=arm64

Cross-compilation requirements:
  Windows: Install mingw-w64 (sudo apt install mingw-w64 g++-mingw-w64)
""")
