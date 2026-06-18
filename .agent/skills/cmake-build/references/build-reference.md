# Build Reference

Loaded on demand from SKILL.md. Contains detailed option tables, generated-preset conventions, runtime configuration, and error resolution.

---

## 1. Compiler & Linker Options

### 1.1 MSVC compiler flags (cl.exe)

| Category | cl.exe flag | CMake equivalent | Purpose |
|----------|------------|------------------|---------|
| Standard | `/std:c++latest` | `set(CMAKE_CXX_STANDARD 23)` | Latest C++ standard |
| Encoding | `/utf-8` | `add_compile_options(/utf-8)` | UTF-8 source encoding |
| Conformance | `/permissive-` | `add_compile_options(/permissive-)` | Strict standards conformance |
| Conformance | `/Zc:__cplusplus` | `add_compile_options(/Zc:__cplusplus)` | Correct `__cplusplus` macro |
| Conformance | `/Zc:preprocessor` | `add_compile_options(/Zc:preprocessor)` | Standard preprocessor |
| Warnings | `/W4` | `add_compile_options(/W4)` | Warning level 4 |
| Warnings | `/WX` | `add_compile_options(/WX)` | Treat warnings as errors |
| Parallel | `/MP` | `add_compile_options(/MP)` | Multi-process compilation |
| Instruction set | `/arch:AVX2` | `add_compile_options(/arch:AVX2)` | Enable AVX2 |
| Floating point | `/fp:precise` | `add_compile_options(/fp:precise)` | Precise float model |
| Exception | `/EHsc` | `add_compile_options(/EHsc)` | C++ synchronous exceptions |
| OpenMP | `/openmp:experimental` | `add_compile_options(/openmp:experimental)` | OpenMP 2.0 + SIMD |
| Security | `/sdl` | `add_compile_options(/sdl)` | SDL checks |
| Object format | `/bigobj` | `add_compile_options(/bigobj)` | Large object files |
| Diagnostics | `/diagnostics:column` | `add_compile_options(/diagnostics:column)` | Column-number diagnostics |
| Diagnostics | `/FC` | `add_compile_options(/FC)` | Full source file path |
| Calling conv | `/Gd` | `add_compile_options(/Gd)` | `__cdecl` calling convention |
| Misc | `/nologo` | `add_compile_options(/nologo)` | Suppress copyright banner |

### 1.2 Debug-specific flags

| cl.exe flag | CMake | Purpose |
|------------|-------|---------|
| `/Zi` | `add_compile_options($<$<CONFIG:Debug>:/Zi>)` | Program database |
| `/Od` | `add_compile_options($<$<CONFIG:Debug>:/Od>)` | Disable optimizations |
| `/RTC1` | `add_compile_options($<$<CONFIG:Debug>:/RTC1>)` | Runtime error checks |
| `/JMC` | `add_compile_options($<$<CONFIG:Debug>:/JMC>)` | Just My Code debugging |

### 1.3 Release-specific flags

| cl.exe flag | CMake | Purpose |
|------------|-------|---------|
| `/O2` | `add_compile_options($<$<CONFIG:Release>:/O2>)` | Maximize speed |
| `/Ob2` | `add_compile_options($<$<CONFIG:Release>:/Ob2>)` | Inline any suitable function |
| `/GL` | `add_compile_options($<$<CONFIG:Release>:/GL>)` | Whole program optimization |
| `/GF` | `add_compile_options($<$<CONFIG:Release>:/GF>)` | String pooling |
| `/Gy` | `add_compile_options($<$<CONFIG:Release>:/Gy>)` | Function-level linking |
| `/Oi` | `add_compile_options($<$<CONFIG:Release>:/Oi>)` | Intrinsic functions |
| `/GS` | `add_compile_options($<$<CONFIG:Release>:/GS>)` | Buffer security check |

### 1.4 Linker flags (link.exe)

| flag | CMake | Purpose |
|------|-------|---------|
| `/DEBUG` | `add_link_options(/DEBUG)` | Generate debug symbols |
| `/DEBUG:FULL` | `add_link_options(/DEBUG:FULL)` | Full debug symbols |
| `/DEBUG:NONE` | `add_link_options(/DEBUG:NONE)` | No debug symbols (Release) |
| `/LTCG` | `add_link_options(/LTCG)` | Link-time code generation |
| `/INCREMENTAL` | `add_link_options(/INCREMENTAL)` | Incremental linking |
| `/STACK:4194304` | `add_link_options(/STACK:4194304)` | 4MB stack reserve |
| `/OPT:REF` | `add_link_options(/OPT:REF)` | Remove unused functions |
| `/machine:x64` | `add_link_options(/machine:x64)` | Target architecture |

### 1.5 Generated framework presets

```powershell
cmake --list-presets all -S .
cmake --preset "msvc_x64_debug"
cmake --build --preset "build-msvc_x64_debug"
cmake --install "out/build/msvc_x64_debug"

cmake --preset "qt_msvc_x64_debug"
cmake --build --preset "build-qt_msvc_x64_debug"
cmake --install "out/build/qt_msvc_x64_debug"
```

The cmake-arithmetic generator writes shareable hidden bases to
`CMakePresets.json` and machine-local visible presets to
`CMakeUserPresets.json`.

| File | Typical contents |
|------|------------------|
| `CMakePresets.json` | `base`, `non-qt-base`, `qt-base`, `<compiler>-base` |
| `CMakeUserPresets.json` | `<compiler>_<arch>_<build-type>`, `qt_<compiler>_<arch>_<build-type>`, optional build/test presets |

Generated visible configure preset names:

| Mode | Pattern | Example |
|------|---------|---------|
| Non-Qt | `<compiler>_<arch>_<build-type>` | `msvc_x64_debug` |
| Qt | `qt_<compiler>_<arch>_<build-type>` | `qt_msvc_x64_debug` |

Generated build preset names:

| Mode | Pattern | Example |
|------|---------|---------|
| Non-Qt | `build-<configure-preset>` | `build-msvc_x64_debug` |
| Qt | `build-<configure-preset>` | `build-qt_msvc_x64_debug` |

Prefer these presets over direct `-D` flags. Direct configure flags are only a
fallback for hand-written CMake projects that do not provide presets.

### 1.6 Build tree vs install tree

The generated framework separates developer build noise from consumable
artifacts:

| Path | Purpose |
|------|---------|
| `out/build/<presetName>` | CMake cache, Ninja files, object files, generated files |
| `out/build/<presetName>/artifacts/<BuildType>/<arch>` | Compiler/linker outputs used while developing |
| `out/install/<presetGroup>` | Clean vcpkg-like install root for running, deploying, or importing |

`<presetName>` includes the build type, such as `msvc_x64_debug`.
`<presetGroup>` excludes the build type, such as `msvc_x64` or `qt_msvc_x64`.

Install layout:

| Build type | Runtime destination | Library destination |
|------------|---------------------|---------------------|
| Release | `bin` | `lib` |
| Debug | `debug/bin` | `debug/lib` |
| RelWithDebInfo | `relwithdebinfo/bin` | `relwithdebinfo/lib` |

This mirrors the useful part of vcpkg's installed-triplet layout while adding a
separate RelWithDebInfo lane for projects that ship optimized debug symbols.

---

## 2. MSVC Runtime Library

### 2.1 Runtime mode options

| CMake variable value | cl.exe flag | When to use |
|---------------------|------------|-------------|
| `MultiThreadedDLL` | `/MD` | Dynamic CRT, default for most projects |
| `MultiThreadedDebugDLL` | `/MDd` | Dynamic CRT Debug |
| `MultiThreaded` | `/MT` | Static CRT, no vcpkg redist needed |
| `MultiThreadedDebug` | `/MTd` | Static CRT Debug |

### 2.2 CMake configuration

```cmake
# Dynamic (recommended for most projects)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

# Static
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
```

### 2.3 Critical: all linked libs must use same runtime

Mixing `/MD` and `/MT` across static libraries and the main executable causes **LNK2038**. Ensure all vcpkg packages use the same triplet:
- Dynamic: `x64-windows`
- Static: `x64-windows-static` or `x64-windows-static-md`

### 2.4 Preprocessor definitions

| Definition | Purpose | Set when |
|-----------|---------|----------|
| `_UNICODE` / `UNICODE` | Unicode API | Always for Windows |
| `NOMINMAX` | Suppress min/max macros | Always for Windows |
| `_CRT_SECURE_NO_WARNINGS` | Suppress deprecation warnings | Always |
| `DEBUG` / `_DEBUG` | Debug code paths | Debug build |
| `NDEBUG` | Release code paths | Release build |
| `_SILENCE_ALL_CXX17_DEPRECATION_WARNINGS` | Silence C++17 warnings | Always |

---

## 3. Common Errors

### 3.1 vcpkg: "Could not find a package..."

```powershell
# Check installed packages
vcpkg list

# Install the missing package with correct triplet
vcpkg install <package>:x64-windows-static-md

# Verify triplet matches preset cache variables:
# VCPKG_STATIC_TRIPLET, VCPKG_DYNAMIC_TRIPLET, or VCPKG_TARGET_TRIPLET
```

### 3.2 Qt: "Found Qt, but missing X component"

```powershell
# Verify CMAKE_PREFIX_PATH points to correct Qt SDK
# Must include lib/cmake/Qt6* subdirectory
# Correct preset environment/cache:
# QTDIR="C:/Qt/6.6.2/msvc2019_64"
# QT_SDK_DIR="C:/Qt/6.6.2/msvc2019_64"
# Wrong: parent-only path, e.g. "C:/Qt/6.6.2"

# Verify architecture matches (x64 Qt for x64 build)
```

### 3.3 LNK2038: Runtime library mismatch

```
Error LNK2038: mismatch detected for 'RuntimeLibrary':
  value 'MD_DynamicRelease' doesn't match value 'MT_StaticRelease'
```

**Fix**: Ensure all components use the same runtime:
1. Check `CMAKE_MSVC_RUNTIME_LIBRARY` setting
2. Check vcpkg triplet: dynamic → `x64-windows`, static → `x64-windows-static[-md]`
3. Check all imported .lib files match the chosen mode

### 3.4 LNK2019 / LNK2001: Unresolved external symbol

```powershell
# Find which .lib exports the symbol
dumpbin /exports <library>.lib | findstr <symbol>

# Check if the library is linked in Debug/Release correctly
# Debug libs often have "d" suffix (e.g., MyLibd.lib from DEBUG_POSTFIX)

# Verify .lib path in link command
cmake --build <dir> --verbose
```

### 3.5 Environment: "cl.exe not found"

```powershell
# Method 1: Run vcvarsall.bat first (sets PATH, INCLUDE, LIB)
#   Find VS installation first (adjust year/edition to match your install):
& "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64

# Method 2: Use vswhere to locate VS automatically, then run vcvarsall
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
& "$vsPath\VC\Auxiliary\Build\vcvarsall.bat" x64

# Method 3: Pass compiler path explicitly to CMake (if vcvarsall is unavailable)
cmake -B build -DCMAKE_CXX_COMPILER="<path-to>/cl.exe"
```
