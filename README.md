# cmake-scaffold

**English** | [简体中文](README.zh.md)

A TOML-driven CMake scaffold for modern C++. Edit one `project.toml`, run `python generate.py`, and get a complete, buildable project: portable presets for MSVC / clang-cl / Clang / GCC, a curated compiler-option set, C++23 standard-library modules (`import std;`), optional Qt and vcpkg integration, protobuf/gRPC code generation, and clang / VS Code tooling.

```toml
[project]
name = "MyApp"
```

```powershell
python generate.py
cmake --preset msvc_x64_debug
cmake --build --preset build-msvc_x64_debug
```

`generate.py` renders the skeleton in `template/` into `./<project.name>/`; it never edits anything else in the repository.

## Why

- **One input, reproducible output.** Presets, standards, compiler options and target wiring are generated from `project.toml`, so every machine builds the same way instead of inheriting someone's hand-edited CMake files.
- **Two preset layers.** `CMakePresets.json` (public) holds shareable framework settings and no local paths; `CMakeUserPresets.json` (user) holds the visible compiler × architecture × build-type presets, `installDir` and machine-local choices.
- **No baked-in SDK paths.** Qt is located through `QT_SDK_DIR` → `CMAKE_PREFIX_PATH`; vcpkg is located through the toolchain file / `VCPKG_ROOT`. Nothing assumes `E:/...`.
- **Modern defaults, opt-in extras.** C++23 + `import std;` are on by default; Qt, vcpkg, prebuilt libraries and proto codegen are one uncomment away.

## Quick start

### 1. Edit `project.toml`

The minimum is `[project] name`. The other tables decide which presets exist, which compilers are visible, the build types, the MSVC runtime, Qt and vcpkg behaviour — see the reference below.

### 2. Generate

```powershell
python generate.py
```

Run it from a terminal that already has the selected compiler environment (see *Requirements*). The output directory `./<project.name>/` is **deleted and recreated** on every run.

### 3. Configure, build, install

```powershell
cmake --preset msvc_x64_debug
cmake --build --preset build-msvc_x64_debug
cmake --install out/build/msvc_x64_debug
```

`cmake --list-presets` shows what is visible for this machine. Artifacts land in `out/build/<preset>/artifacts/<Config>/<arch>/{bin,lib,pdb}`.

### 4. Run tests

```powershell
ctest --preset test-msvc_x64_debug
```

Test presets always exist; they only find something once `test_enabled = true` (which injects `include(CTest)` + `enable_testing()`) and tests are registered.

### Qt

```toml
[qt]
qt_enabled = true
sdk_dir = "D:/Qt/6.6.2/msvc2019_64"   # empty = rely on the default Qt search paths
components = ["Widgets"]
```

Then use the same presets. Qt is found before any target is created; `AUTOMOC`/`AUTOUIC`/`AUTORCC` are enabled, Qt6 executables are finalized, and `*.png/jpg/jpeg/svg/ico/ttf/webp/js/json/html` under the subproject directory become Qt resources automatically.

### Linux

The shipped `project.toml` enables `clang-cl`/`msvc`, which do not apply on Linux — select the Linux compilers first:

```toml
[presets.user]
compilers = ["gcc", "clang"]
build_types = ["Debug", "Release"]
```

```bash
python3 generate.py
cmake --preset gcc_x64_debug
cmake --build --preset build-gcc_x64_debug
./out/build/gcc_x64_debug/artifacts/Debug/x64/bin/MyApp
```

`clang_x64_*` presets become visible through the same list. The preset conditions only cover Windows and Linux hosts.

## Requirements and preflight

| Tool | Requirement |
| --- | --- |
| Python | ≥ 3.11 (uses `tomllib`) |
| CMake | ≥ 3.30; **≥ 4.4** for the native `import std` route (older versions use a FILE_SET fallback, clang-cl needs 4.4) |
| Ninja | On `PATH` (or use another generator from `[presets].generator`) |
| Compilers | Whatever is listed in `[presets.user].compilers` |

**The generation terminal and the configure terminal must see the same environment.** The public `base` preset forwards the parent process environment:

```json
"environment": { "INCLUDE": "$penv{INCLUDE}", "LIB": "$penv{LIB}", "PATH": "$penv{PATH}" }
```

`$penv{}` reads the environment of the process that invoked CMake (not the preset's own `environment`, which would be self-referential here). `msvc-base` / `clang-cl-base` use the external-architecture strategy, so `cl.exe` / `clang-cl.exe` need `INCLUDE`/`LIB` for the Windows SDK and `PATH` for `rc.exe`/`mt.exe`/`ninja`. Use a *Developer PowerShell for VS*, `vcvars64.bat`, or a clean system-wide environment.

Before rendering, `generate.py` checks every enabled compiler that applies to this host and **aborts with the log** if one is unusable:

| Compiler | Checks |
| --- | --- |
| `msvc` | `cl.exe` on `PATH`; `INCLUDE` has Windows Kits `ucrt` + `\um` + MSVC `vc\tools\msvc\…\include`; `LIB` has the matching entries and they exist |
| `clang-cl` | `clang-cl.exe` on `PATH`; same Windows SDK checks |
| `clang` | `clang` + `clang++` on `PATH`; `<clang -print-resource-dir>/include` exists; on Windows also the SDK checks |
| `gcc` | `gcc` + `g++` on `PATH`; `g++ -print-file-name=include` exists; `libstdc++.a` resolves |

Enabled compilers that do not apply to the host (e.g. `gcc` on Windows) are reported as `[SKIP]` and do not block generation — their presets stay hidden.

Linux notes: `-fopenmp` needs libomp (e.g. `libomp-19-dev` on Debian); the default `import std` example needs a toolchain that ships a std module (MSVC 14.5x, libc++ 19+ with `-stdlib=libc++`, GCC 15+). GCC 14 has no `bits/std.cc`, so either use a header-based source or a newer toolchain.

**Polluted environment detection.** `INCLUDE`/`LIB` (Windows) and `PATH` values containing `\n`/`\r` or leading/trailing whitespace are carried verbatim through `$penv{}` into compiler command lines and produce confusing errors such as `LNK1104: cannot open file 'MSVCRTD.lib'`. The preflight rejects them and prints a PowerShell fix command for the affected registry scope.

## `project.toml` reference

### `[project]`

| Key | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | string | — (required) | Output directory, CMake `project()` name, and the sub-project name when a sub leaves it empty |
| `version` | string | `"1.0.0"` | `project(VERSION …)`; inherited by subs |
| `description` | string | `""` | `project(DESCRIPTION …)`; inherited by subs |
| `homepage_url` | string | `""` | `project(HOMEPAGE_URL …)` |
| `languages` | array | `["CXX"]` | `project(LANGUAGES …)`, e.g. `["C","CXX"]` |
| `c_standard` | int/string | `"17"` | Preset `CMAKE_C_STANDARD`; also baked into the root `CMakeLists.txt` as a fallback for plain `cmake -G Ninja` |
| `cxx_standard` | int/string | `"23"` | Preset `CMAKE_CXX_STANDARD`; same fallback |
| `jobs` | table | `{type="fixed", size=0}` | Parallelism (see below) |
| `test_enabled` | bool | `false` | Injects `include(CTest)` + `enable_testing()` into the root `CMakeLists.txt` |

`jobs` becomes the integer `JOBS` used by build and test presets:

- `type = "fixed"`: `size <= 0` → all available cores; otherwise `min(size, cores)`.
- `type = "factor"`: `size <= 0` → all cores; otherwise `clamp(round(cores * min(size, 1.0)), 1, cores)`. `round()` avoids `100 * 0.29 == 28.999…` truncating to 28.
- Cores = `sched_getaffinity` on Linux, `os.cpu_count()` elsewhere.
- Outside presets, use the `CMAKE_BUILD_PARALLEL_LEVEL` **environment variable**; it is not a cache variable.

`test_enabled = false` still generates test presets, but without `enable_testing()` `ctest` finds nothing; uncomment the two injected lines if you want tests without the flag.

### `[[project.sub]]`

Omit it to get one empty sub, i.e. a single `src/` directory.

| Key | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | string | `""` | Empty → directory `src/`, sub-project name = main name; otherwise directory = name = sub-project name |
| `version` | string | inherits | Sub `project(VERSION …)` |
| `description` | string | inherits | Sub `project(DESCRIPTION …)` |
| `target_type` | string | `"EXE"` | `EXE` / `STATIC` / `SHARED` |
| `win32_executable` | bool | `true` | `WIN32_EXECUTABLE` (`true` = no console window on Windows) |
| `macos_bundle` | bool | `true` | `MACOSX_BUNDLE` |

Each sub gets `CMakeLists.txt`, `Dependencies.cmake`, and the matching source set: `main.cpp` for `EXE`, `library.cpp` + `library.h` for libraries. `modules/` is copied once as an example and is **not** added to the build.

The shipped `project.toml` overrides two defaults for a friendlier sample: `languages = ["C","CXX"]` and `win32_executable = false` / `macos_bundle = false`, so the example keeps its console output.

### `[presets]`

| Key | Default | Purpose |
| --- | --- | --- |
| `binary_dir` | `${sourceDir}/out/build/${presetName}` | `base` `binaryDir`; must be relative, free of `..`, and contain `${presetName}` |
| `architecture` | `"x64"` | `x64` / `x86` / `arm` / `arm64`; used in preset names, `architecture.value` and IntelliSense modes |
| `generator` | `"Ninja"` | A known CMake generator name or `Visual Studio <n> <yyyy>` |
| `msvc_runtime_mode` | `"MD"` | `MD` (dynamic CRT) / `MT` (static CRT); also picks the vcpkg static triplet |
| `msvc_toolset` | `"v145"` | `msvc-base` toolset (use `v143` for VS 2022) |
| `use_sanitizers` | `false` | `USE_SANITIZERS=ON/OFF` in every preset (Clang/GCC only) |

### `[presets.user]`

| Key | Default | Purpose |
| --- | --- | --- |
| `compilers` | — | Subset of `msvc`, `clang-cl`, `clang`, `gcc`; decides which compiler presets are visible |
| `build_types` | — | Subset of `Debug`, `RelWithDebInfo`, `Release`, `MinSizeRel`; decides which build types are visible |
| `install_dir` | `${sourceDir}/out/install/${presetGroup}` | `installDir` of the hidden `-local` presets; `${presetGroup}` = `<compiler>_<arch>` |

### `[qt]`

| Key | Default | Purpose |
| --- | --- | --- |
| `qt_enabled` | `false` | Default of `option(QT_SUPPORT …)`; also enables the Qt Creator vendor blocks |
| `sdk_dir` | `""` (empty) | Default of `QT_SDK_DIR`; appended to `CMAKE_PREFIX_PATH`. The shipped `project.toml` carries an example path |
| `components` | `["Widgets"]` | `find_package(Qt … COMPONENTS …)` |
| `presets_checksum` | `""` | Root-level `qt-project.org/Presets` vendor checksum; empty = omit the block |
| `qt_checksum` | `""` | `qt-project.org/Qt` vendor checksum inside `base`; empty = omit the block |

The checksums are bookkeeping written by Qt Creator for the local Qt installation; update or clear them when switching machines. Both are ignored while `qt_enabled = false`.

## Generated project layout

```
MyApp/
├── CMakeLists.txt              # root: module includes, project(), CTest wiring, subdirectories
├── CMakePresets.json           # public preset layer (shareable)
├── CMakeUserPresets.json       # user preset layer (visible presets, installDir)
├── cmake/
│   ├── CompilerId.cmake        # compiler family flags + MSVC_RUNTIME_MODE
│   ├── Platform.cmake          # OS / arch, imported-config mapping, default build type
│   ├── CompilerOptions.cmake   # scaffold_configure_target(): flags, per-config options
│   ├── OutputLayout.cmake      # artifacts/<config>/<arch>/{bin,lib,pdb}
│   ├── TargetUtils.cmake       # CopyTargetDependentLibs(), IMPORTED_LIBRARY()
│   ├── Vcpkg.cmake             # root/triplet detection + FindVcpkgPackage()   (opt-in)
│   ├── PrebuiltLibraries.cmake # scaffold_add_prebuilt_library()              (opt-in)
│   ├── QtSupport.cmake         # QT_SUPPORT, SDK path, find_package(Qt6/Qt5)
│   ├── ImportStd.cmake         # import std; (pre-project UUIDs, scanning fixups)
│   ├── ProjectTarget.cmake     # target creation / Qt resources / finalize / install
│   ├── ProtoGen.cmake          # scaffold_protobuf_generate() (C++/C#/Java/Python)
│   └── ShowIncludesPrefix.cmake# MSVC+Ninja dependency prefix (CMake < 4.4 only)
├── .clang-format  .clang-tidy  .clangd
├── .vscode/                    # launch.json, settings.json, semantic-rules.json
├── .gitignore
├── modules/                    # example C++ module library (math.cppm + math.cpp), opt-in
│   ├── CMakeLists.txt
│   ├── math.cppm
│   └── math.cpp
└── src/
    ├── CMakeLists.txt          # project() + target + options + install
    ├── Dependencies.cmake      # third-party recipes (8 sections)
    └── main.cpp                # EXE entry point; uses import std;
```

The example target is a C++23 executable that starts with `import std;`. The `math` module library is only built after you add `add_subdirectory(modules)` to the root `CMakeLists.txt` and uncomment the `target_link_libraries(... math)` line in `src/CMakeLists.txt`.

## Template internals (`cmake/`)

The root `CMakeLists.txt` is a short skeleton:

```cmake
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(ImportStd)        # must run before project(): sets the import-std UUID
project(...)
include(CompilerId Platform ShowIncludesPrefix OutputLayout TargetUtils QtSupport ProtoGen)
# include(Vcpkg) / include(PrebuiltLibraries)  # opt-in
```

| Module | What it does |
| --- | --- |
| `CompilerId` | Defines `COMPILER_MSVC`, `COMPILER_CLANG`, `COMPILER_CLANG_CL`, `COMPILER_GCC`, `COMPILER_MSVC_LIKE`; maps `MSVC_RUNTIME_MODE` (MD/MT) to `CMAKE_MSVC_RUNTIME_LIBRARY` |
| `Platform` | `PLATFORM_NAME`, `LIB_SUFFIX`, `SHARED_LIB_SUFFIX`, `PLATFORM_SUFFIX` (`x64`/`x86`/`arm`/`arm64`); maps RelWithDebInfo/MinSizeRel imported configs to Release; defaults `CMAKE_BUILD_TYPE=Debug` for single-config generators without touching `CMAKE_CONFIGURATION_TYPES` |
| `CompilerOptions` | `scaffold_configure_target(<target>)`: MSVC option set (`/std:c++latest /utf-8 /permissive- /W4 /arch:AVX2 /openmp:experimental /bigobj …`) or GCC/Clang set (`-std=c++… -Wall -Wextra -Werror -mavx2 -mfma -fopenmp …`); per-config Debug/Release/RelWithDebInfo options via `$<CONFIG:…>`; 4 MiB stack; sanitizers; ccache (GCC/Clang); `DEBUG_POSTFIX d` and PDB names for MSVC-like compilers |
| `OutputLayout` | Runtime/library/archive/PDB outputs under `artifacts/$<CONFIG>/$<arch>/…`, so multi-config generators get one tree per configuration |
| `TargetUtils` | `CopyTargetDependentLibs(target names release_dir [debug_dir])` copies runtime DLLs next to the binary (tries `<name>d.dll` first in Debug, versioned `.so` on Linux); `IMPORTED_LIBRARY(target base dir)` wraps a hand-shipped shared library |
| `Vcpkg` | Detects `VCPKG_ROOT` (toolchain file → cache/env → platform conventions), sets `VCPKG_STATIC_TRIPLET` (`<arch>-windows-static[-md]` following `MSVC_RUNTIME_MODE`), exposes `VCPKG_*_PATH`, and provides `FindVcpkgPackage()` |
| `PrebuiltLibraries` | `scaffold_add_prebuilt_library(<target> [STATIC] INCLUDE_DIR … [DEBUG_LOCATION/IMPLIB] [RELEASE_LOCATION/IMPLIB] …)` creates an `IMPORTED GLOBAL` target plus a `<name>::<name>` alias; single-config libraries fall back to a generic location. A `THIRD_PARTY_ROOT`-driven sample is included |
| `QtSupport` | `option(QT_SUPPORT …)`, `AUTOMOC/AUTOUIC/AUTORCC`, `QT_SDK_DIR` → `CMAKE_PREFIX_PATH`, `find_package(Qt6/Qt5 …)` |
| `ImportStd` | Sets `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` per CMake version before `project()`; `scaffold_enable_import_std(<target>)` uses `CXX_MODULE_STD` on CMake ≥ 4.4 and a `FILE_SET std` fallback below 4.4 (only one target may use the fallback); `scaffold_mark_sources_for_module_scanning()` re-enables scanning for non-generated sources |
| `ProjectTarget` | `scaffold_add_project_target()` (EXE/STATIC/SHARED, Qt5/6 variants), `scaffold_add_qt_resources()`, `scaffold_finalize_project_target()` (Qt6 executables + module-scanning fixups), `scaffold_install_project_target()` |
| `ProtoGen` | `scaffold_protobuf_generate()` for protobuf/gRPC |
| `ShowIncludesPrefix` | Re-detects the localized `/showIncludes` prefix on CMake < 4.4 with MSVC + Ninja; on ≥ 4.4 it returns immediately because CMake does this itself (writing raw code-page bytes there silently breaks `rules.ninja`) |

### `import std;` notes

- CMake ≥ 4.4 provisions the std module itself; `scaffold_enable_import_std()` only sets `CXX_MODULE_STD`.
- CMake < 4.4 adds the compiler's std module source as a `FILE_SET std`; only one target per build may do that, and clang-cl aborts with an explicit error (use MSVC/Clang or upgrade CMake).
- Targets containing `GENERATED` sources (Qt AUTOMOC, proto codegen) are compiled with unscanned module rules by default, which breaks `import std;`. Both `ProjectTarget` and `ProtoGen` re-mark the affected sources with `CXX_SCAN_FOR_MODULES ON`.
- `OutputLayout` is load-bearing on CMake ≥ 4.4 + Ninja: it keeps the synthetic std provider library out of the build root, otherwise `@cmake_cxx_std.lib` is mistaken for a response file by `vs_link_exe` and the link fails with `LNK2001`.

### `scaffold_protobuf_generate()`

```cmake
scaffold_protobuf_generate(echo_proto
    PROTO_FILES "${CMAKE_CURRENT_SOURCE_DIR}/proto/echo.proto"
    LANGUAGES CPP                 # CPP | CSHARP | JAVA | PYTHON (default CPP)
    GRPC                          # also generate service stubs
    TARGET ${PROJECT_NAME}        # attach generated C++ sources
)
target_link_libraries(${PROJECT_NAME} PRIVATE protobuf::libprotobuf gRPC::grpc++)
```

- Outputs default to `${CMAKE_BINARY_DIR}/generated/proto/{cpp,csharp,java,python}`.
- C++ outputs are real build rules (incremental, missing files regenerate); other languages use one stamp file per language because their file names depend on package/message names. The custom target is `ALL`, so a plain build produces every requested language.
- Tools: explicit argument → `SCAFFOLD_*` cache variable → imported targets (`protobuf::protoc`, `gRPC::grpc_cpp_plugin`, `gRPC::grpc_csharp_plugin`) → `<VCPKG_ROOT>/installed/*/tools/{protobuf,grpc}` → `PATH`. `protoc-gen-grpc-java` must be downloaded separately.
- Exports `<name>_SOURCES`, `<name>_INCLUDE_DIRS`, `<name>_OUTPUT_DIR` to the caller.

## Preset model and naming

Public layer (`CMakePresets.json`):

- `base`: standards, generator, `binaryDir`, external architecture, `$penv{}` environment, `CMAKE_EXPORT_COMPILE_COMMANDS`, `CMAKE_FIND_PACKAGE_PREFER_CONFIG`
- `msvc-base` / `clang-cl-base` / `clang-base` / `gcc-base`: compiler variables, toolset, host `condition`, IntelliSense vendor settings
- `build-base`: `jobs`; `test-base`: `outputOnFailure` + `execution.jobs`

User layer (`CMakeUserPresets.json`):

- `<compiler>-<arch>-local`: hidden, carries `installDir`
- `<compiler>_<arch>_<buildtype>`: visible configure preset (e.g. `msvc_x64_debug`)
- `build-<compiler>_<arch>_<buildtype>` and `test-<compiler>_<arch>_<buildtype>`

Visibility is rewritten consistently across configure/build/test presets: a preset is hidden when its compiler is not in `compilers` or its build type is not in `build_types`.

## Placeholders `#{…}`

`generate.py` performs a single regex pass over template files:

- Global: `MAIN_PROJECT_NAME`, `PROJECT_VERSION`, `PROJECT_DESCRIPTION`, `PROJECT_HOMEPAGE_URL`, `PROJECT_LANGUAGES`, `C_STANDARD`, `CXX_STANDARD`, `GENERATOR`, `BINARY_DIR`, `ARCHITECTURE`, `MSVC_RUNTIME_MODE`, `MSVC_TOOLSET`, `JOBS`, `INSTALL_DIR`
- Per sub: `SUB_PROJECT_NAME`, `SUB_PROJECT_VERSION`, `SUB_PROJECT_DESCRIPTION`, `TARGET_TYPE`, `MACOS_BUNDLE`, `WIN32_EXECUTABLE`
- Root `CMakeLists.txt`: `QT_SUPPORT_DEFAULT`, `QT_SDK_DIR`, `QT_COMPONENTS`, `TESTING_SETUP`
- Presets: `QT_VENDOR_BASE`, `QT_VENDOR_ROOT` (expand to nothing when the matching checksum is empty; the leading comma keeps the JSON valid)
- Every `cmake/*.cmake` file is rendered too, so module defaults can carry placeholders

Semantics: single pass (a value containing `#{OTHER}` is not expanded again); CMake-quoted values (`*_DESCRIPTION`, `homepage_url`, `sdk_dir`) escape `\`, `"`, `;` and control characters; JSON values are JSON-escaped; an unknown placeholder is a fatal error; after generation the output tree is scanned and any leftover `#{…}` is reported.

## Input validation

`generate.py` validates `project.toml` before writing anything and exits with `Error: …` (code 1) instead of failing inside CMake:

| Location | Rule |
| --- | --- |
| `project.name` | Single path segment (`[A-Za-z_][A-Za-z0-9._+-]*`, no trailing dot); the output directory must stay inside the repository |
| `project.version` | Single token (no whitespace, quotes, backslashes, `;`, `#`, braces) |
| `project.languages` | Non-empty array of single tokens |
| `project.homepage_url` | No newline |
| `project.jobs` | `type` ∈ `fixed`/`factor`; `size` integer (fixed) or number (factor); booleans/strings rejected |
| `[[project.sub]].name` | Same as `project.name`; unique (case-insensitive); may not be `cmake` or `modules` |
| `[[project.sub]].target_type` | `EXE` / `STATIC` / `SHARED` |
| `[[project.sub]].win32_executable` / `macos_bundle` | Booleans |
| `[presets]` | `architecture`, `generator`, `msvc_runtime_mode`, `msvc_toolset`, `binary_dir` |
| `[presets.user]` | `compilers` / `build_types` must be known names (case-insensitive) |
| `[qt].components` | Non-empty array of single tokens |

`project.toml` may carry a UTF-8 BOM; TOML/JSON errors name the file and reason.

## Extending

**New build type** → add configure/build/test presets for it in `template/CMakeUserPresets.json`, register the name in `ALL_BUILD_TYPES` in `generate.py`, then list it in `[presets.user].build_types`.

**New compiler** → keep three places in sync: `template/CMakePresets.json` (`<comp>-base`), `template/CMakeUserPresets.json` (`<comp>-<arch>-local` + presets per build type), `generate.py` (`ALL_COMPILERS`, `COMPILER_KEYWORDS` with more specific names first, `COMPILER_CHECKS`, `HOST_COMPILERS`).

**New generator** → add it to `KNOWN_GENERATORS` in `generate.py` (Visual Studio names are accepted by pattern).

**Third-party library** → edit the generated `src/Dependencies.cmake` (or `template/src/Dependencies.cmake`): vcpkg (`include(Vcpkg)` + `FindVcpkgPackage(...)`), `find_package`, or `scaffold_add_prebuilt_library(...)`. `CopyTargetDependentLibs()` handles runtime DLL copying.

**Proto code** → call `scaffold_protobuf_generate()` in `src/Dependencies.cmake` or `src/CMakeLists.txt`; see the recipe in section 8 of the generated `Dependencies.cmake`.

## Known limitations

- **No tests are shipped.** `template/` has no `add_test()`; enable `test_enabled` and register tests yourself.
- **`import std;` depends on the toolchain.** MSVC 14.5x works; CMake < 4.4 needs a compiler-shipped std module and allows only one std FILE_SET target; clang-cl requires CMake ≥ 4.4; Clang needs libc++ (or a libstdc++ that ships a std module); GCC needs 15+.
- **Preset conditions cover Windows and Linux only.** `msvc`/`clang-cl` presets require Windows, `gcc` requires Linux, and `clang` presets are conditioned on Windows or Linux; macOS is not wired up.
- **x86-64 baseline.** `CompilerOptions.cmake` hard-codes `/arch:AVX2` / `-mavx2 -mfma`; ARM presets need that block adjusted.
- **GCC/Clang build with `-Werror`.** A warning stops the build; relax it in `CompilerOptions.cmake` if that is too strict for your code.
- **`modules/` is an opt-in example.** Add `add_subdirectory(modules)` and uncomment the link line to build it.
- **Regeneration deletes the output directory.** Keep hand-written files outside it (or outside `[[project.sub]]`); a locked directory aborts generation instead of writing into the old tree.
- **Do not put literal `#{…}` in `project.toml` values** — the leftover assertion will fail.
- **vcpkg Debug + gRPC troubleshooting.** If linking gRPC-generated code fails with `LNK1000: Internal error during LIB::Search` in Debug while Release works, reproduce it in a minimal project without this scaffold; it points at the vcpkg Debug library set / linker, not at the template.

## Repository layout

```
generate.py          # generator
project.toml         # generation input
quick-generate.bat   # python generate.py
template/            # skeleton rendered by generate.py
docs/                # clangd / clang-tidy / VS Code / theme-color guides; docs/prompt/
.agent/skills/       # AI-assisted workflow skills
LICENSE
README.md            # English documentation (this file)
README.zh.md         # Chinese documentation
```
