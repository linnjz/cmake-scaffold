# cmake-arithmetic

**English** | [简体中文](README.zh.md)

TOML-driven CMake project generator for modern C++. From a single `project.toml` it renders the `template/` skeleton into a buildable C++ project: portable presets, multi-compiler support (MSVC, Clang, GCC, clang-cl), optional Qt and vcpkg, C++ modules, and clang tooling — while keeping shareable framework settings separate from machine-specific paths.

---

## What it does

`generate.py` reads the `project.toml` next to it and renders the skeleton in `template/` into a directly buildable C++ project under `./<project.name>/`.

CMake presets are split into two layers:

- **`CMakePresets.json` (public / framework layer)** — compiler base presets, language standards, toolsets, architecture strategy: everything **shareable**, with no machine-specific paths.
- **`CMakeUserPresets.json` (user / machine layer)** — the visible compiler × architecture × build-type presets, `installDir`, and machine-local settings. These may differ per machine.

`generate.py` only performs **placeholder substitution + preset-visibility toggling** based on `project.toml`; it never bakes local SDK paths into the public presets.

## Quick start

```powershell
# 1. Edit project.toml
# 2. Generate (run from a terminal that already has the selected compiler environment; see below)
python generate.py
# 3. Build / install
cmake --preset msvc_x64_debug
cmake --build --preset build-msvc_x64_debug
cmake --install out/build/msvc_x64_debug
# 4. Test (requires test_enabled = true in [project])
ctest --preset test-msvc_x64_debug
```

After generation, `./MyApp/` is a complete project. Re-running `generate.py` after editing `project.toml` **deletes the old output directory first** and recreates it. If the directory cannot be deleted (locked, read-only, …) generation aborts with an error instead of writing into the stale tree.

## Requirements and pre-flight checks

**Toolchain**: Python ≥ 3.11 (uses `tomllib`), CMake ≥ 3.30, Ninja, and whichever compilers are enabled in `[presets.user].compilers`.

**Key rule: public presets never bake machine-specific paths.** The `base` preset in `CMakePresets.json` references the parent process environment:

```json
"environment": {
  "INCLUDE": "$penv{INCLUDE}",
  "LIB": "$penv{LIB}",
  "PATH": "$penv{PATH}"
}
```

- `$penv{}` is read **at configure time** from the process that invoked CMake, and does **not** see values defined in the same preset's `environment` (that is `$env{}` behavior). Because these very variables (`INCLUDE`/`LIB`/`PATH`) are being redefined here, using `$env{}` would create a self-reference — hence `$penv{}` is required.
- Why these three: `msvc-base` / `clang-cl-base` use `"architecture": {"strategy": "external"}` with an external toolset, so CMake/Ninja invoke `cl.exe`/`clang-cl.exe` directly. The compiler then needs `INCLUDE`/`LIB`/`PATH` from the environment to locate the Windows SDK. (`PATH` must also provide `rc.exe`, `mt.exe` and `ninja`.)

Consequently, **`python generate.py` and `cmake --preset …` must run in the same kind of environment** — e.g. a "Developer PowerShell for VS", after `vcvars64.bat`, or with clean `INCLUDE`/`LIB`/`PATH` persisted system-wide.

Before generating, `generate.py` runs a pre-flight check. If any enabled compiler that applies to this platform is unusable, it **aborts and prints the log** (`exit 1`):

| Compiler | Checks |
| -------- | ------ |
| `msvc` | `cl.exe` on `PATH`; `INCLUDE` contains Windows Kits `ucrt` + `\um` + MSVC `vc\tools\msvc\…\include`; `LIB` contains the matching `ucrt`/`\um`/`lib` entries, and those directories must exist |
| `clang-cl` | `clang-cl.exe` on `PATH`; same Windows SDK checks as above |
| `clang` | `clang` and `clang++` on `PATH`; `include` under `clang -print-resource-dir` exists; on Windows also the SDK checks |
| `gcc` | `gcc` and `g++` on `PATH`; `g++ -print-file-name=include` exists; `libstdc++.a` resolves |

Enabled compilers that do not apply to this platform (e.g. `gcc` enabled on Windows) are only reported as `[SKIP]` and do not block generation — their presets already carry a `condition` that hides them in CMake.

**Polluted-environment detection**: environment variables containing `\n`/`\r` or leading/trailing whitespace are carried verbatim through `$penv{}` into compiler command lines, causing odd errors such as `LNK1104: cannot open file 'MSVCRTD.lib'`. The pre-flight check rejects them and prints a fix command:

```
Environment check: polluted environment variable(s) detected:
  - LIB: 含换行符 (LF/CR)        # "contains a newline (LF/CR)"; pre-flight messages are currently Chinese
This breaks $penv{} expansion; the linker receives a path that carries a newline.
Fix in an elevated PowerShell, then restart the terminal:
  [Environment]::SetEnvironmentVariable('LIB', ([Environment]::GetEnvironmentVariable('LIB','Machine') -split ';' | ForEach-Object {($_ -replace '\r|\n','').Trim()} | Where-Object {$_}) -join ';', 'Machine')
```

## `project.toml` reference

### `[project]`

| Key | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | string | — (required, non-empty) | Output directory name, CMake `project()` name, and the sub-project name when a `sub` leaves it empty |
| `version` | string | `"1.0.0"` | `project(VERSION …)`; inherited by subs without their own version |
| `description` | string | `""` | `project(DESCRIPTION …)`; inherited by subs without their own description |
| `homepage_url` | string | `""` | `project(HOMEPAGE_URL …)` |
| `languages` | array | `["CXX"]` | `project(LANGUAGES …)`, e.g. `["C","CXX"]` |
| `c_standard` | int/string | `"17"` | Preset `CMAKE_C_STANDARD` |
| `cxx_standard` | int/string | `"23"` | Preset `CMAKE_CXX_STANDARD` |
| `jobs` | table | `{type="fixed", size=0}` | Parallelism, see below |
| `test_enabled` | bool | `false` | When `true`, injects `include(CTest)` + `enable_testing()` into the root `CMakeLists.txt`, see below |

`jobs` resolves to the integer `JOBS`, used both for `set(CMAKE_BUILD_PARALLEL_LEVEL #{JOBS})` and for the build presets' `"jobs"`:

- `type = "fixed"`: `size <= 0` → all available cores; otherwise `min(size, cores)`.
- `type = "factor"`: `size <= 0` → all cores; otherwise `clamp(round(cores * min(size, 1.0)), 1, cores)`. `round()` is used instead of truncation so that `100 * 0.29 == 28.999…` resolves to 29, not 28.
- Core count = `sched_getaffinity` on Linux, `os.cpu_count()` elsewhere.

`test_enabled`: when `true`, `include(CTest)` + `enable_testing()` are injected into the root `CMakeLists.txt`; when `false`, a commented-out hint is injected instead. `testPresets` are **always generated regardless of this flag**; with the flag off, the root `CMakeLists.txt` has no `enable_testing()`, so `ctest --preset …` finds no tests — you can uncomment those two lines there if you want tests without the generator flag.

### `[[project.sub]]`

Array of tables; **omitting** `[[project.sub]]` is equivalent to one empty `{}`, i.e. a single `src/` subdirectory.

| Key | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | string | `""` | Empty → directory `src/` and sub-project name = main project name; non-empty → directory = name = sub-project name |
| `version` | string | inherits `project.version` | Sub `project(VERSION …)` |
| `description` | string | inherits `project.description` | Sub `project(DESCRIPTION …)` |
| `target_type` | string | `"EXE"` | `EXE`/`STATIC`/`SHARED`; selects `add_executable` or `add_library` |
| `win32_executable` | bool | `true` | Target `WIN32_EXECUTABLE` (`true` = no console window on Windows) |
| `macos_bundle` | bool | `true` | Target `MACOSX_BUNDLE` |

Each sub receives `CMakeLists.txt`, `Dependencies.cmake`, and a copy of the remaining files under `template/src/` (`main.cpp`, …). `modules/` comes from `template/modules/` and is copied once into the output root as an **example**; it is not added to the build (see below).

### `[presets]`

| Key | Default | Purpose |
| --- | --- | --- |
| `binary_dir` | `${sourceDir}/out/build/${presetName}` | `base` preset `binaryDir`; must be relative, free of `..`, and contain `${presetName}` (otherwise all presets share one build tree) |
| `architecture` | `"x64"` | Architecture value used in preset names, `architecture.value` and `intelliSenseMode` (`windows-msvc-<arch>`); accepts only `"x64"`, `"x86"`, `"arm"`, `"arm64"` (CMake `-A` aliases, case-insensitive) |
| `generator` | `"Ninja"` | Generator; must be one of `KNOWN_GENERATORS`, or of the form `Visual Studio <n> <yyyy>` |
| `msvc_runtime_mode` | `"MD"` | `MSVC_RUNTIME_MODE` cache variable (`MD`/`MT`, see `cmake/VcpkgConfig.cmake`) |
| `msvc_toolset` | `"v145"` | `msvc-base`'s `toolset.value` (clang-cl is fixed to `ClangCL`) |
| `use_sanitizers` | `false` | `USE_SANITIZERS` = `ON`/`OFF` in every preset |

### `[presets.user]`

| Key | Default | Purpose |
| --- | --- | --- |
| `compilers` | — | Array of `msvc`/`clang`/`gcc`/`clang-cl`; decides which compiler presets are **visible** (the rest become `hidden`) |
| `build_types` | — | Array of `Debug`/`RelWithDebInfo`/`Release`/`MinSizeRel`; decides which build types are **visible** |
| `install_dir` | `${sourceDir}/out/install/${presetGroup}` | `installDir` of the `-local` presets; `${presetGroup}` = `<compiler>_<arch>` |

### `[qt]`

| Key | Default | Purpose |
| --- | --- | --- |
| `qt_enabled` | `false` | Default of `option(QT_SUPPORT …)` in the root `CMakeLists.txt` (`ON`/`OFF`), and whether the two Qt Creator vendor placeholders are injected into `CMakePresets.json` |
| `sdk_dir` | `D:/Qt/6.6.2/msvc2019_64` | Default of the `QT_SDK_DIR` cache variable; only used when `QT_SUPPORT=ON` |
| `components` | `["Widgets"]` | Component list for `find_package(Qt … COMPONENTS …)` |
| `presets_checksum` | `""` | `checksum` of the root-level vendor `qt-project.org/Presets`; empty = block is not generated |
| `qt_checksum` | `""` | `checksum` of the vendor `qt-project.org/Qt` inside `base`; empty = block is not generated |

> There are **no** `qt-base` / `non-qt-base` presets anymore; the Qt switch is the default value of `option(QT_SUPPORT …)`. Qt is located by appending `sdk_dir` (as `QT_SDK_DIR`) to `CMAKE_PREFIX_PATH` in the root `CMakeLists.txt`; it does not rely on the `QTDIR` environment variable (verified: Qt targets configure and build with `QTDIR` unset).
>
> The two `checksum` values are bookkeeping written by Qt Creator into the presets and are tied to the local Qt installation. The `project.toml` shipped in this repository carries values measured on the author's machine; after switching machines or upgrading Qt, update them to what Creator writes, or leave them empty to stop generating that vendor block.

## Generated layout

```
MyApp/
├── CMakeLists.txt              # rendered from template/CMakeLists.txt (CTest wiring per test_enabled + add_subdirectory(<sub>…))
├── CMakePresets.json           # public layer (framework / shareable)
├── CMakeUserPresets.json       # user layer (visible presets for this machine)
├── cmake/                      # PlatformConfig / TargetCompilerFlags / CxxModules / VcpkgConfig …
├── .clang-format .clang-tidy .clangd
├── .vscode/                    # copied verbatim from template (launch.json, settings.json, semantic-rules.json)
├── .vs/settings.json
├── .gitignore
├── modules/                    # example C++ module library (math: math.cppm interface + math.cpp implementation)
│   ├── CMakeLists.txt          # project(math) + add_library(math STATIC) + CXX_MODULES file set
│   ├── math.cppm
│   └── math.cpp
└── src/                        # one directory per sub
    ├── CMakeLists.txt          # project() + add_executable/library + install
    ├── Dependencies.cmake      # third-party integration point
    └── main.cpp
```

`modules/` is only an **example** and is **not** wired into the build: the root `CMakeLists.txt` does not call `add_subdirectory(modules)`, and the `target_link_libraries(${PROJECT_NAME} PRIVATE math)` line in `src/CMakeLists.txt` is commented out. To use it, add `add_subdirectory(modules)` to the root `CMakeLists.txt` and uncomment that link line. The example library does **not** `import std;` (it only uses `#include <cmath>`), so it never competes with the main target for the same std module.

## Preset model and naming

**Public layer** (`CMakePresets.json`):

- `base`: standards / generator / `binaryDir` / `architecture` (external strategy) / `environment` (`$penv{}`)
- `msvc-base` / `clang-cl-base` / `clang-base` / `gcc-base`: compiler and toolset, each with a `condition` hiding it on other host OSes
- `build-base`: `"jobs"`
- `test-base`: `output.outputOnFailure` + `execution.jobs`

**User layer** (`CMakeUserPresets.json`):

- `<compiler>-<arch>-local`: hidden, carries `installDir`, inherits `<compiler>-base`
- `<compiler>_<arch>_<buildtype>`: visible configure presets (`buildtype` lower-case, e.g. `msvc_x64_debug`)
- `build-<compiler>_<arch>_<buildtype>`: the corresponding build presets
- `test-<compiler>_<arch>_<buildtype>`: the corresponding test presets (inherit `test-base`, `configurePreset` points at the configure preset of the same name)

`generate.py` rewrites `hidden` consistently for every **build-type-bearing** preset across `configurePresets` / `buildPresets` / `testPresets`: a preset is hidden when its compiler is not in `compilers` or its build type is not in `build_types`, so visibility stays in sync across all three layers. (Actually running test presets additionally requires `[project] test_enabled = true`.)

## Placeholders `#{…}`

`generate.py` performs a **single pass** of regex substitution over template files (`#{KEY}` → value):

- Global: `MAIN_PROJECT_NAME`, `PROJECT_VERSION`, `PROJECT_DESCRIPTION`, `PROJECT_HOMEPAGE_URL`, `PROJECT_LANGUAGES`, `GENERATOR`, `BINARY_DIR`, `ARCHITECTURE`, `MSVC_RUNTIME_MODE`, `MSVC_TOOLSET`, `JOBS`
- Per sub: `SUB_PROJECT_NAME`, `SUB_PROJECT_VERSION`, `SUB_PROJECT_DESCRIPTION`, `TARGET_TYPE`, `MACOS_BUNDLE`, `WIN32_EXECUTABLE`
- Root `CMakeLists.txt`: `#{QT_SUPPORT_DEFAULT}`, `#{QT_SDK_DIR}`, `#{QT_COMPONENTS}`, `#{TESTING_SETUP}`
- `CMakePresets.json`: `#{QT_VENDOR_BASE}` (inside `base`), `#{QT_VENDOR_ROOT}` (root level); the Qt Creator vendor blocks are injected only when `qt_enabled` is true and the matching `[qt]` `checksum` is non-empty, otherwise they expand to nothing (the placeholders carry a leading comma, so the JSON stays valid when empty)
- `CMakeUserPresets.json`: `#{INSTALL_DIR}` is seeded from `[presets.user].install_dir`; afterwards every `<compiler>-<arch>-local` preset gets the concrete path with `${presetGroup}` expanded (falling back to the preset name itself when the compiler cannot be recognized)

Substitution semantics (unlike the usual per-key `str.replace`):

- **Single pass**: a value containing `#{OTHER}` is not expanded again.
- **Context-aware escaping**: values injected into CMake quoted arguments (`*_DESCRIPTION`, `homepage_url`, `sdk_dir`) escape `\`, `"`, `;` and newlines; values injected into JSON go through JSON escaping.
- **Unknown placeholders are fatal**: a `#{…}` in a template that is not in the replacement table (typo in the key) raises `Error: unknown placeholder(s) …` and aborts instead of silently leaving it behind.
- **Post-generation leftover assertion**: after generation the output tree is scanned; any remaining `#{…}` (e.g. a literal `#{…}` inside a `project.toml` value) is reported with the offending file.

## Input validation

`generate.py` applies an allow-list validation to `project.toml`. On failure it prints a single `Error: …` line and exits with code 1 instead of letting the problem surface inside CMake:

| Location | Validation |
| --- | --- |
| `project.name` | Single path segment: `[A-Za-z_][A-Za-z0-9._+-]*`, must not end with `.` (no `..`, `/`, `\`, drive letters); the output directory is additionally asserted to be inside the repository |
| `project.version` | Single token (no whitespace, quotes, backslashes, `;`, `#` or braces) |
| `project.languages` | Non-empty array; every entry must be a single token |
| `project.homepage_url` | Must not contain a newline |
| `project.jobs` | `type` ∈ `fixed`/`factor`; `size` must be an integer (fixed) or a number (factor); `bool`/strings are rejected |
| `[[project.sub]].name` | Same as `project.name`; must be unique (case-insensitive); must not take `cmake`/`modules` (root directories the generator writes) |
| `[[project.sub]].target_type` | `EXE`/`STATIC`/`SHARED` |
| `[[project.sub]].win32_executable` / `macos_bundle` | Must be booleans |
| `[presets]` | See the table above: `architecture` / `generator` / `msvc_runtime_mode` / `msvc_toolset` / `binary_dir` |
| `[presets.user].compilers` / `build_types` | Must be subsets of `ALL_COMPILERS` / `ALL_BUILD_TYPES` (case-insensitive) |
| `[qt].components` | Non-empty array; every entry must be a single token |

`project.toml` may carry a UTF-8 BOM (stripped on read); TOML/JSON parse failures report the file name and reason instead of raising a bare traceback.

## Extending

**Add a build type** → add a group of configure/build/test presets per compiler in `template/CMakeUserPresets.json`, register the name in `ALL_BUILD_TYPES` in `generate.py` (unregistered names are rejected by validation), then add it to `[presets.user].build_types` to make it visible.

**Add a compiler** → four places must stay in sync:

1. `template/CMakePresets.json`: add `<comp>-base` (compiler variables, toolset, `condition`).
2. `template/CMakeUserPresets.json`: add `<comp>-<arch>-local` plus the configure/build/test presets for every build type.
3. `generate.py`: register the name in `ALL_COMPILERS` (validation), add a keyword to `COMPILER_KEYWORDS` (preset name → compiler; more specific keywords such as `clang-cl` must come first), register a probe in `COMPILER_CHECKS`, mark supported hosts in `HOST_COMPILERS`; add new environment variables to `required_env_vars()` if needed.

**Add a CMake generator** → add the name to `KNOWN_GENERATORS` in `generate.py`.

**Integrate a third-party library** → edit the generated `src/Dependencies.cmake`, or `template/src/Dependencies.cmake` to make it the default for future projects; vcpkg specifics live in `cmake/VcpkgConfig.cmake`.

## Known limitations

- **The template ships no tests**: `template/` contains no `add_test()`. Even with `[project] test_enabled = true` (`include(CTest)` + `enable_testing()` injected), `ctest --preset …` still prints `No tests were found!!!` (exit code 0) until tests are registered.
- **Qt / code generation needs a module-scanning compensation**: generated sources such as the autogen `mocs_compilation.cpp` from `qt_add_executable` carry the `GENERATED` property, which makes CMake disable module scanning for that target by default, and `import std;` in a normal source then fails with `C2230/C2039`. `cmake/CxxModules.cmake` explicitly re-enables `CXX_SCAN_FOR_MODULES` for non-generated sources (only there; the detection stage is untouched).
- **`modules/` is an opt-in example**: the generated project ships a `math` static library (`math.cppm` + `math.cpp`), but neither `add_subdirectory(modules)` nor the link line is enabled. Enable both to build it; configure/build of the example were verified on this machine with MSVC and clang-cl (on GCC / Clang the flags come from `cmake/TargetCompilerFlags.cmake`: `-fmodules-ts` / `-fmodules`; **the Linux + gcc preset has not been verified on this machine**).
- **Do not put literal `#{…}` in values**: if any `project.toml` value contains `#{…}`, the post-generation leftover assertion fails (better to abort than to silently ship a placeholder).
- Regeneration **deletes** the output directory; back up any hand-written files inside it, or keep them in a separate library directory outside `[[project.sub]]`. If deletion fails (locked/read-only), generation aborts with an error instead of continuing to write into the old tree.

## Repository layout

```
generate.py          # generator
project.toml         # generation input
template/            # project skeleton (placeholders + presets + cmake modules + VS Code config)
docs/                # clangd / clang-tidy / VS Code / theme-color guides; docs/prompt/ (commit convention, ADR, prompt review)
.agent/skills/       # skill library for AI-assisted work
README.md            # English documentation (this file)
README.zh.md         # Chinese documentation
```
