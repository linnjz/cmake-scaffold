#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

try:
    import winreg
except ImportError:
    winreg = None

SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE_DIR = SCRIPT_DIR / "template"
OUTPUT_DIR: Path = None
TOML_PATH = SCRIPT_DIR / "project.toml"

ALL_COMPILERS = ["msvc", "clang-cl", "clang", "gcc"]
ALL_BUILD_TYPES = ["Debug", "RelWithDebInfo", "Release", "MinSizeRel"]
ALL_TARGET_TYPES = ["EXE", "STATIC", "SHARED"]
ALL_ARCHITECTURES = ["x64", "x86", "arm", "arm64"]
ALL_MSVC_RUNTIME_MODES = ["MD", "MT"]

# Order matters: the more specific keyword has to win, "clang-cl" before "clang".
COMPILER_KEYWORDS = ["clang-cl", "msvc", "clang", "gcc"]

KNOWN_GENERATORS = [
    "Ninja",
    "Ninja Multi-Config",
    "Unix Makefiles",
    "MinGW Makefiles",
    "NMake Makefiles",
    "NMake Makefiles JOM",
    "Xcode",
    "Green Hills MULTI",
]

# Sub directory names the generator itself owns in the output root; a [[project.sub]] using one of
# them would silently merge with the copied template directory (duplicate add_subdirectory/target).
RESERVED_SUB_DIR_NAMES = {"cmake", "modules", "tests", "benchmarks"}

PLACEHOLDER_RE = re.compile(r"#\{([A-Za-z_][A-Za-z0-9_]*)\}")
# Values injected into CMake quoted arguments, where a raw '"', '\', ';' or newline would either
# break the syntax or silently turn one string into a list.
CMAKE_QUOTED_KEYS = frozenset(
    {"PROJECT_DESCRIPTION", "PROJECT_HOMEPAGE_URL", "SUB_PROJECT_DESCRIPTION", "QT_SDK_DIR"}
)
# Values that are JSON fragments assembled by this script (already escaped, comma-prefixed).
JSON_FRAGMENT_KEYS = frozenset({"QT_VENDOR_BASE", "QT_VENDOR_ROOT"})

NAME_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9._+-]*\Z")
TOKEN_PATTERN = re.compile(r"[^\s\"\\;#{}]+\Z")


def fail(message):
    print(f"Error: {message}")
    sys.exit(1)


def safe_dir_name(value, what):
    value = str(value).strip()
    if not value:
        fail(f"{what} must not be empty")
    if not NAME_PATTERN.match(value) or value.endswith("."):
        fail(
            f"{what} '{value}' is not a safe directory name; "
            "allowed: letters, digits, '_', '.', '+', '-' (no path separators, no trailing dot)"
        )
    return value


def require_token(value, what):
    value = str(value).strip()
    if not TOKEN_PATTERN.match(value):
        fail(
            f"{what} '{value}' must be a single token "
            "(no whitespace, quote, backslash, ';', '#' or brace)"
        )
    return value


def canonical_choice(value, allowed, what):
    for choice in allowed:
        if str(value).strip().lower() == choice.lower():
            return choice
    fail(f"{what} '{value}' is not supported; use one of: {', '.join(allowed)}")


def check_subset(values, allowed, what):
    for item in values:
        if not any(str(item).strip().lower() == a.lower() for a in allowed):
            fail(f"{what} contains '{item}'; allowed: {', '.join(allowed)}")


def cmake_quoted(value):
    # CMake interprets escapes inside quoted arguments as well, so every metacharacter has to be
    # escaped or a description like a"b / a;b would change meaning.
    out = []
    for ch in str(value):
        if ch in '\\"':
            out.append("\\" + ch)
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ch == ";":
            out.append("\\;")
        else:
            out.append(ch)
    return "".join(out)


def json_quoted(value):
    return json.dumps(str(value), ensure_ascii=False)[1:-1]


def for_cmake(values):
    return {k: (cmake_quoted(v) if k in CMAKE_QUOTED_KEYS else str(v)) for k, v in values.items()}


def for_json(values):
    return {
        k: (str(v) if k in JSON_FRAGMENT_KEYS else json_quoted(v))
        for k, v in values.items()
    }


def qt_vendor_json(vendor_key, checksum):
    # Prepended comma is what allows #{QT_VENDOR_BASE} / #{QT_VENDOR_ROOT} to expand to nothing and
    # still leave valid JSON; the value is re-serialized by json.dumps afterwards, so no formatting
    # is needed here.
    if not checksum:
        return ""
    return ',"vendor": ' + json.dumps({vendor_key: {"checksum": checksum}})


def load_toml():
    try:
        raw = TOML_PATH.read_bytes()
    except FileNotFoundError:
        fail(f"{TOML_PATH} not found")
    except OSError as exc:
        fail(f"could not read {TOML_PATH}: {exc}")
    if raw.startswith(b"\xef\xbb\xbf"):
        # tomllib rejects a BOM with a bare TOMLDecodeError "Invalid statement".
        raw = raw[3:]
    try:
        return tomllib.loads(raw.decode("utf-8"))
    except UnicodeDecodeError as exc:
        fail(f"{TOML_PATH} is not valid UTF-8: {exc}")
    except tomllib.TOMLDecodeError as exc:
        fail(f"{TOML_PATH} is not valid TOML: {exc}")


def parse_json(text, label):
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        fail(f"{label} did not render to valid JSON ({exc}); check the template and project.toml values")


def validate(config):
    project = config.get("project", {})
    presets = config.get("presets", {})
    user_cfg = presets.get("user", {})
    qt_cfg = config.get("qt", {})

    safe_dir_name(project.get("name", ""), "project.name")
    if project.get("version"):
        require_token(project.get("version"), "project.version")
    if project.get("homepage_url") and "\n" in str(project["homepage_url"]):
        fail("project.homepage_url must not contain a newline")
    languages = project.get("languages", ["CXX"])
    if not isinstance(languages, list) or not languages:
        fail("project.languages must be a non-empty array, e.g. [\"C\", \"CXX\"]")
    for language in languages:
        require_token(language, "project.languages entry")

    for flag in ("test_enabled", "benchmark_enabled"):
        if flag in project and not isinstance(project[flag], bool):
            fail(f"project.{flag} must be a boolean")

    check_subset(user_cfg.get("compilers", []), ALL_COMPILERS, "presets.user.compilers")
    check_subset(user_cfg.get("build_types", []), ALL_BUILD_TYPES, "presets.user.build_types")

    canonical_choice(presets.get("architecture", "x64"), ALL_ARCHITECTURES, "presets.architecture")
    canonical_choice(
        presets.get("msvc_runtime_mode", "MD"), ALL_MSVC_RUNTIME_MODES, "presets.msvc_runtime_mode"
    )
    require_token(presets.get("msvc_toolset", "v145"), "presets.msvc_toolset")

    generator = presets.get("generator", "Ninja")
    require_token(generator, "presets.generator")
    if str(generator).strip() not in KNOWN_GENERATORS and not re.match(
        r"Visual Studio \d+ \d{4}\Z", str(generator).strip()
    ):
        fail(
            f"presets.generator '{generator}' is unknown; add it to KNOWN_GENERATORS in generate.py "
            "if it is a legitimate CMake generator"
        )

    binary_dir = str(presets.get("binary_dir", "${sourceDir}/out/build/${presetName}"))
    if not binary_dir.strip():
        fail("presets.binary_dir must not be empty")
    if "${presetName}" not in binary_dir:
        fail("presets.binary_dir must contain '${presetName}', otherwise every preset shares one build tree")
    if re.match(r"([A-Za-z]:|[\\/])", binary_dir) or ".." in re.split(r"[\\/]", binary_dir):
        fail(f"presets.binary_dir '{binary_dir}' must be a relative path without '..'")

    components = qt_cfg.get("components", ["Widgets"])
    if not isinstance(components, list) or not components:
        fail("[qt].components must be a non-empty array, e.g. [\"Widgets\"]")
    for component in components:
        require_token(component, "[qt].components entry")

    subs = project.get("sub", [])
    if not isinstance(subs, list):
        fail("[[project.sub]] must be an array of tables")
    for sub in subs:
        if sub.get("name"):
            safe_dir_name(sub.get("name"), "[[project.sub]].name")
        canonical_choice(sub.get("target_type", "EXE"), ALL_TARGET_TYPES, "[[project.sub]].target_type")
        for flag in ("win32_executable", "macos_bundle"):
            if flag in sub and not isinstance(sub[flag], bool):
                fail(f"[[project.sub]].{flag} must be a boolean")


def get_cpu_actual_max():
    try:
        return max(1, len(os.sched_getaffinity(0)))
    except AttributeError:
        return max(1, os.cpu_count() or 1)


def resolve_jobs(config):
    jobs = config.get("project", {}).get("jobs", {})
    if not isinstance(jobs, dict):
        fail("project.jobs must be a table, e.g. { type = \"fixed\", size = 0 }")
    cpu_max = get_cpu_actual_max()
    jtype = jobs.get("type", "fixed")
    if jtype == "fixed":
        size = jobs.get("size", 0)
        if isinstance(size, bool) or not isinstance(size, int):
            fail("jobs.size must be an integer when jobs.type is 'fixed'")
        if size <= 0:
            return cpu_max
        return min(size, cpu_max)
    if jtype == "factor":
        size = jobs.get("size", 1.0)
        if isinstance(size, bool) or not isinstance(size, (int, float)):
            fail("jobs.size must be a number when jobs.type is 'factor'")
        if size <= 0.0:
            return cpu_max
        size = min(1.0, float(size))
        # round, not int truncation: 100 * 0.29 == 28.999999999999996 must resolve to 29
        return max(1, min(round(cpu_max * size), cpu_max))
    fail(f"jobs.type '{jtype}' is not supported (use 'fixed' or 'factor')")


def get_subs(config):
    project = config.get("project", {})
    main_name = project.get("name", "")
    subs = project.get("sub", [])
    if not subs:
        subs = [{}]
    result = []
    seen = {}
    for index, sub in enumerate(subs):
        raw_name = str(sub.get("name", "")).strip()
        if not raw_name:
            dir_name = "src"
            project_name = main_name
        else:
            dir_name = safe_dir_name(raw_name, f"[[project.sub]] #{index + 1} name")
            project_name = dir_name
            if dir_name.lower() in RESERVED_SUB_DIR_NAMES:
                fail(
                    f"[[project.sub]] name '{dir_name}' collides with the '{dir_name}' entry the "
                    "generator already writes into the output root"
                )
        key = dir_name.lower()
        if key in seen:
            fail(
                f"[[project.sub]] #{seen[key] + 1} and #{index + 1} both map to the directory "
                f"'{dir_name}' (duplicate add_subdirectory)"
            )
        seen[key] = index
        result.append((dir_name, project_name, sub))
    return result


def replace_placeholders(text, replacements, where=""):
    unknown = set()

    def expand(match):
        key = match.group(1)
        if key in replacements:
            return str(replacements[key])
        unknown.add(key)
        return match.group(0)

    # Single pass: a value that happens to contain "#{OTHER}" must not be expanded again.
    result = PLACEHOLDER_RE.sub(expand, text)
    if unknown:
        fail(f"unknown placeholder(s) {', '.join(sorted(unknown))} in {where or 'template'}")
    return result


def read_file(path):
    # utf-8-sig: several template files are stored with a UTF-8 BOM. Reading it as plain utf-8 would
    # carry the BOM into the rendered file, where strict parsers (JSON) reject it.
    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            return f.read()
    except UnicodeDecodeError as exc:
        fail(f"{path} is not valid UTF-8: {exc}")


def write_file(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def copy_file(src, dest):
    data = Path(src).read_bytes()
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    Path(dest).parent.mkdir(parents=True, exist_ok=True)
    Path(dest).write_bytes(data)


def copy_tree(src, dest):
    shutil.copytree(src, dest, dirs_exist_ok=True, copy_function=copy_file)


def verify_no_placeholders():
    for path in OUTPUT_DIR.rglob("*"):
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for match in PLACEHOLDER_RE.finditer(text):
            fail(
                f"unresolved placeholder {match.group(0)} left in {path.relative_to(OUTPUT_DIR)}; "
                "either the template has a typo or a project.toml value contains a literal '#{...}'"
            )


def detect_compiler(name):
    name_lower = name.lower()
    if "clang-cl" in name_lower:
        return "clang-cl"
    for c in COMPILER_KEYWORDS:
        if c == "clang-cl":
            continue
        if name_lower.startswith(c) or f"-{c}" in name_lower or f"_{c}" in name_lower:
            return c
    return None


def detect_build_type(name):
    name_lower = name.lower()
    for bt in ALL_BUILD_TYPES:
        if name_lower.endswith(f"_{bt.lower()}"):
            return bt
    return None


def hide_disabled_presets(presets, enabled_compilers, enabled_build_types):
    for preset in presets:
        name = preset.get("name", "")
        compiler = detect_compiler(name)
        build_type = detect_build_type(name)
        if build_type:
            hidden = False
            # detect_* return canonical names ("Debug"), the enabled lists are lower-cased.
            if compiler and compiler.lower() not in enabled_compilers:
                hidden = True
            if build_type.lower() not in enabled_build_types:
                hidden = True
            preset["hidden"] = hidden


def process_cmake_user_presets(config, values):
    src = TEMPLATE_DIR / "CMakeUserPresets.json"
    dest = OUTPUT_DIR / "CMakeUserPresets.json"

    data = parse_json(replace_placeholders(read_file(src), for_json(values), src.name), src.name)

    user_cfg = config.get("presets", {}).get("user", {})
    enabled_compilers = [c.lower() for c in user_cfg.get("compilers", [])]
    enabled_build_types = [bt.lower() for bt in user_cfg.get("build_types", [])]
    install_dir_template = user_cfg.get("install_dir", "${sourceDir}/out/install/${presetGroup}")
    arch = values.get("ARCHITECTURE", "x64")

    hide_disabled_presets(data.get("configurePresets", []), enabled_compilers, enabled_build_types)
    hide_disabled_presets(data.get("buildPresets", []), enabled_compilers, enabled_build_types)
    hide_disabled_presets(data.get("testPresets", []), enabled_compilers, enabled_build_types)

    # Every "-local" preset gets a concrete installDir, even when its compiler is not recognised:
    # otherwise the literal "#{INSTALL_DIR}" would end up in the generated file.
    for preset in data.get("configurePresets", []):
        name = preset.get("name", "")
        if not name.endswith("-local"):
            continue
        compiler = detect_compiler(name)
        preset_group = f"{compiler}_{arch}" if compiler else name[: -len("-local")]
        preset["installDir"] = install_dir_template.replace("${presetGroup}", preset_group)

    write_file(dest, json.dumps(data, indent=2))


def process_cmake_presets(config, values):
    src = TEMPLATE_DIR / "CMakePresets.json"
    dest = OUTPUT_DIR / "CMakePresets.json"

    data = parse_json(replace_placeholders(read_file(src), for_json(values), src.name), src.name)

    use_sanitizers = config.get("presets", {}).get("use_sanitizers", False)
    sanitizers_value = "ON" if use_sanitizers else "OFF"

    for preset in data.get("configurePresets", []):
        cache_vars = preset.get("cacheVariables", {})
        if "USE_SANITIZERS" in cache_vars:
            cache_vars["USE_SANITIZERS"] = sanitizers_value

    c_std = str(config.get("project", {}).get("c_standard", "17"))
    cxx_std = str(config.get("project", {}).get("cxx_standard", "23"))
    for preset in data.get("configurePresets", []):
        cache_vars = preset.get("cacheVariables", {})
        if "CMAKE_C_STANDARD" in cache_vars:
            cache_vars["CMAKE_C_STANDARD"] = c_std
        if "CMAKE_CXX_STANDARD" in cache_vars:
            cache_vars["CMAKE_CXX_STANDARD"] = cxx_std

    write_file(dest, json.dumps(data, indent=2))


def process_root_cmakelists(config, values, sub_dirs):
    src = TEMPLATE_DIR / "CMakeLists.txt"
    dest = OUTPUT_DIR / "CMakeLists.txt"

    content = replace_placeholders(read_file(src), for_cmake(values), src.name)

    project = config.get("project", {})
    add_sub_lines = [f"add_subdirectory({sub_dir_name})" for sub_dir_name, _, _ in sub_dirs]
    # Auxiliary directories are opt-in: they are copied only when enabled, so
    # the add_subdirectory() call would otherwise point at a missing directory.
    if project.get("test_enabled", False):
        add_sub_lines.append("add_subdirectory(tests)")
    if project.get("benchmark_enabled", False):
        add_sub_lines.append("add_subdirectory(benchmarks)")
    if add_sub_lines:
        content += "\n\n" + "\n".join(add_sub_lines) + "\n"

    write_file(dest, content)


def process_subs(config, values):
    subs = get_subs(config)
    project = config.get("project", {})
    src_txt = TEMPLATE_DIR / "src" / "CMakeLists.txt"
    src_cmake = TEMPLATE_DIR / "src" / "Dependencies.cmake"

    for dir_name, project_name, sub in subs:
        sub_values = dict(values)
        sub_values["SUB_PROJECT_NAME"] = project_name
        sub_values["SUB_PROJECT_VERSION"] = require_token(
            sub.get("version") or project.get("version") or "1.0.0", f"[[project.sub]] '{dir_name}' version"
        )
        sub_values["SUB_PROJECT_DESCRIPTION"] = sub.get("description") or project.get("description", "")
        target_type = canonical_choice(
            sub.get("target_type", "EXE"), ALL_TARGET_TYPES, "[[project.sub]].target_type"
        )
        sub_values["TARGET_TYPE"] = target_type
        sub_values["MACOS_BUNDLE"] = "ON" if sub.get("macos_bundle", True) else "OFF"
        sub_values["WIN32_EXECUTABLE"] = "ON" if sub.get("win32_executable", True) else "OFF"

        sub_dir = OUTPUT_DIR / dir_name
        sub_dir.mkdir(parents=True, exist_ok=True)
        cmake_values = for_cmake(sub_values)

        write_file(
            sub_dir / "CMakeLists.txt",
            replace_placeholders(read_file(src_txt), cmake_values, src_txt.name),
        )
        write_file(
            sub_dir / "Dependencies.cmake",
            replace_placeholders(read_file(src_cmake), cmake_values, src_cmake.name),
        )

        # Only the default source set for the target type is copied: an EXE
        # subproject must not carry library.cpp/library.h and vice versa.
        skipped_sources = {"library.cpp", "library.h"} if target_type == "EXE" else {"main.cpp"}
        for item in (TEMPLATE_DIR / "src").iterdir():
            if item.name in ("CMakeLists.txt", "Dependencies.cmake") or item.name in skipped_sources:
                continue
            dest = sub_dir / item.name
            if item.is_dir():
                copy_tree(item, dest)
            else:
                copy_file(item, dest)


def copy_aux_dir(name):
    src = TEMPLATE_DIR / name
    if not src.is_dir():
        fail(f"{src} is missing; cannot enable {name}")
    copy_tree(src, OUTPUT_DIR / name)


def copy_remaining_root_items():
    for item in TEMPLATE_DIR.iterdir():
        if item.name in (
            "CMakeLists.txt",
            "CMakePresets.json",
            "CMakeUserPresets.json",
            "cmake",
            "src",
            "tests",
            "benchmarks",
        ):
            continue
        dest = OUTPUT_DIR / item.name
        if item.is_dir():
            copy_tree(item, dest)
        else:
            copy_file(item, dest)


def copy_cmake_dir(values):
    src = TEMPLATE_DIR / "cmake"
    dest = OUTPUT_DIR / "cmake"
    if not src.exists():
        return
    cmake_values = for_cmake(values)
    for item in src.rglob("*"):
        rel = item.relative_to(src)
        if item.is_dir():
            (dest / rel).mkdir(parents=True, exist_ok=True)
        elif item.suffix == ".cmake":
            # cmake/*.cmake may carry #{} placeholders (e.g. QtSupport.cmake);
            # render them like the root CMakeLists.txt instead of copying raw.
            write_file(
                dest / rel,
                replace_placeholders(read_file(item), cmake_values, str(rel)),
            )
        else:
            copy_file(item, dest / rel)


HOST_COMPILERS = {
    "nt": {"msvc", "clang-cl", "clang"},
    "linux": {"gcc", "clang"},
}


def current_host_key():
    if os.name == "nt":
        return "nt"
    if sys.platform.startswith("linux"):
        return "linux"
    return "other"


def split_env_paths(value):
    return [p.strip() for p in value.split(os.pathsep) if p.strip()]


def find_env_entries(paths, *needles):
    return [p for p in paths if all(n in p.lower().replace("/", "\\") for n in needles)]


def env_pollution(name):
    value = os.environ.get(name)
    if value is None:
        return None
    if "\n" in value or "\r" in value:
        return "contains a line break (LF/CR)"
    if value != value.strip():
        return "has leading/trailing whitespace"
    return None


def polluted_scopes(name):
    if winreg is None:
        return ["Machine"]
    scopes = []
    for scope, root, sub_key in (
        ("Machine", winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"),
        ("User", winreg.HKEY_CURRENT_USER, "Environment"),
    ):
        try:
            with winreg.OpenKey(root, sub_key) as key:
                value, _ = winreg.QueryValueEx(key, name)
        except OSError:
            continue
        if isinstance(value, str) and ("\n" in value or "\r" in value or value != value.strip()):
            scopes.append(scope)
    return scopes or ["Machine"]


def env_fix_command(name, scope):
    cleaned = f"([Environment]::GetEnvironmentVariable('{name}','{scope}') -split ';' | ForEach-Object {{($_ -replace '\\r|\\n','').Trim()}} | Where-Object {{$_}}) -join ';'"
    return f"[Environment]::SetEnvironmentVariable('{name}', {cleaned}, '{scope}')"


def probe(exe, args):
    try:
        result = subprocess.run([exe, *args], capture_output=True, text=True, timeout=20)
    except Exception:
        return ""
    return (result.stdout or result.stderr or "").strip()


def check_windows_sdk():
    problems = []
    include = split_env_paths(os.environ.get("INCLUDE", ""))
    lib = split_env_paths(os.environ.get("LIB", ""))

    if not include:
        problems.append("INCLUDE is not set; Windows SDK / MSVC header paths are missing")
    else:
        for label, needles in (
            ("Windows SDK ucrt header directory", ("windows kits", "ucrt")),
            ("Windows SDK um header directory", ("windows kits", "\\um")),
            ("MSVC C++ header directory", ("vc\\tools\\msvc", "include")),
        ):
            hits = find_env_entries(include, *needles)
            if not hits:
                problems.append(f"INCLUDE is missing the {label}")
            elif not os.path.isdir(hits[0]):
                problems.append(f"{label} does not exist: {hits[0]}")

    if not lib:
        problems.append("LIB is not set; Windows SDK / MSVC library paths are missing")
    else:
        for label, needles in (
            ("Windows SDK ucrt library directory", ("windows kits", "ucrt")),
            ("Windows SDK um library directory", ("windows kits", "\\um")),
            ("MSVC library directory", ("vc\\tools\\msvc", "lib")),
        ):
            hits = find_env_entries(lib, *needles)
            if not hits:
                problems.append(f"LIB is missing the {label}")
            elif not os.path.isdir(hits[0]):
                problems.append(f"{label} does not exist: {hits[0]}")
    return problems


def check_msvc():
    problems = []
    if not shutil.which("cl.exe") and not shutil.which("cl"):
        problems.append("cl.exe (MSVC compiler) was not found on PATH")
    return problems + check_windows_sdk()


def check_clang_cl():
    problems = []
    if not shutil.which("clang-cl.exe") and not shutil.which("clang-cl"):
        problems.append("clang-cl.exe was not found on PATH")
    return problems + check_windows_sdk()


def check_clang():
    problems = []
    clang = shutil.which("clang") or shutil.which("clang.exe")
    clangxx = shutil.which("clang++") or shutil.which("clang++.exe")
    if not clang:
        problems.append("clang was not found on PATH")
    if not clangxx:
        problems.append("clang++ was not found on PATH")
    if clang:
        resource = probe(clang, ["-print-resource-dir"])
        if not resource:
            problems.append("could not determine the clang resource directory (clang -print-resource-dir)")
        elif not os.path.isdir(os.path.join(resource, "include")):
            problems.append(f"clang include directory does not exist: {os.path.join(resource, 'include')}")
    if os.name == "nt":
        problems += check_windows_sdk()
    return problems


def check_gcc():
    problems = []
    gcc = shutil.which("gcc")
    gxx = shutil.which("g++")
    if not gcc:
        problems.append("gcc was not found on PATH")
    if not gxx:
        problems.append("g++ was not found on PATH")
    if gxx:
        include_dir = probe(gxx, ["-print-file-name=include"])
        if include_dir and not os.path.isdir(include_dir):
            problems.append(f"gcc include directory does not exist: {include_dir}")
        libstdcxx = probe(gxx, ["-print-file-name=libstdc++.a"])
        if libstdcxx == "libstdc++.a":
            problems.append("libstdc++ was not found")
    return problems


COMPILER_CHECKS = {
    "msvc": check_msvc,
    "clang-cl": check_clang_cl,
    "clang": check_clang,
    "gcc": check_gcc,
}


def required_env_vars(applicable_enabled, host):
    if not applicable_enabled:
        return []
    if host == "nt":
        return ["INCLUDE", "LIB", "PATH"]
    return ["PATH"]


def check_environment(config):
    compilers = [c.lower() for c in config.get("presets", {}).get("user", {}).get("compilers", [])]
    if not compilers:
        print("Environment check: no compiler enabled in project.toml, skipped.")
        return

    host = current_host_key()
    applicable = HOST_COMPILERS.get(host, set())
    applicable_enabled = [c for c in compilers if c in applicable]

    print("Environment check:")
    failed = []
    for comp in compilers:
        check = COMPILER_CHECKS.get(comp)
        if check is None:
            print(f"  [SKIP] {comp}: unknown compiler")
            continue
        problems = check()
        if not problems:
            print(f"  [ OK ] {comp}")
            continue
        if comp in applicable:
            print(f"  [FAIL] {comp}")
            for problem in problems:
                print(f"         - {problem}")
            failed.append(comp)
        else:
            print(f"  [SKIP] {comp}: not applicable on this platform (presets hidden by condition)")

    polluted = []
    for name in required_env_vars(applicable_enabled, host):
        reason = env_pollution(name)
        if reason:
            polluted.append((name, reason))

    if polluted:
        print("\nEnvironment check: polluted environment variable(s) detected:")
        for name, reason in polluted:
            print(f"  - {name}: {reason}")
        print("This breaks $penv{} expansion; the linker receives a path that carries a newline.")
        print("Fix in an elevated PowerShell, then restart the terminal:")
        for name, _ in polluted:
            for scope in polluted_scopes(name):
                print(f"  {env_fix_command(name, scope)}")

    if failed or polluted:
        print("\nEnvironment check failed; generation aborted.")
        print("Run from a VS developer environment (vcvars64.bat) or persist clean INCLUDE/LIB/PATH.")
        sys.exit(1)

    print("Environment check passed.")


def testing_setup(project):
    if project.get("test_enabled", False):
        return "include(CTest)\nenable_testing()"
    return ("# Tests are disabled: set test_enabled = true in [project] of project.toml,\n"
            "# or uncomment the two lines below; otherwise ctest finds no tests.\n"
            "# include(CTest)\n"
            "# enable_testing()")


def build_values(config):
    project = config.get("project", {})
    presets = config.get("presets", {})
    user_cfg = presets.get("user", {})
    qt_cfg = config.get("qt", {})
    qt_enabled = qt_cfg.get("qt_enabled", False)
    qt_checksum = qt_cfg.get("qt_checksum", "") if qt_enabled else ""
    presets_checksum = qt_cfg.get("presets_checksum", "") if qt_enabled else ""

    return {
        "MAIN_PROJECT_NAME": project.get("name", ""),
        "PROJECT_VERSION": project.get("version") or "1.0.0",
        "PROJECT_DESCRIPTION": project.get("description", ""),
        "PROJECT_HOMEPAGE_URL": project.get("homepage_url", ""),
        "PROJECT_LANGUAGES": " ".join(project.get("languages", ["CXX"])),
        "C_STANDARD": str(project.get("c_standard", "17")),
        "CXX_STANDARD": str(project.get("cxx_standard", "23")),
        "GENERATOR": presets.get("generator", "Ninja"),
        "BINARY_DIR": presets.get("binary_dir", "${sourceDir}/out/build/${presetName}"),
        "ARCHITECTURE": canonical_choice(
            presets.get("architecture", "x64"), ALL_ARCHITECTURES, "presets.architecture"
        ),
        "MSVC_RUNTIME_MODE": canonical_choice(
            presets.get("msvc_runtime_mode", "MD"), ALL_MSVC_RUNTIME_MODES, "presets.msvc_runtime_mode"
        ),
        "MSVC_TOOLSET": presets.get("msvc_toolset", "v145"),
        "JOBS": resolve_jobs(config),
        "INSTALL_DIR": user_cfg.get("install_dir", "${sourceDir}/out/install/${presetGroup}"),
        "QT_SUPPORT_DEFAULT": "ON" if qt_enabled else "OFF",
        # Empty default: the compiler's find_package() locates a system-visible Qt
        # on its own; baking a personal SDK path into the template would make the
        # example fail on every machine except that one.
        "QT_SDK_DIR": qt_cfg.get("sdk_dir", ""),
        "QT_COMPONENTS": " ".join(qt_cfg.get("components", ["Widgets"])),
        "QT_VENDOR_BASE": qt_vendor_json("qt-project.org/Qt", qt_checksum),
        "QT_VENDOR_ROOT": qt_vendor_json("qt-project.org/Presets", presets_checksum),
        "TESTING_SETUP": testing_setup(project),
    }


def main():
    global OUTPUT_DIR
    config = load_toml()
    validate(config)
    check_environment(config)

    project = config.get("project", {})
    OUTPUT_DIR = SCRIPT_DIR / project["name"]
    sub_dirs = get_subs(config)
    values = build_values(config)

    # The name is validated as a single directory segment, this is the second line of defence: the
    # output directory is deleted and recreated on every run.
    if SCRIPT_DIR.resolve() not in OUTPUT_DIR.resolve().parents:
        fail(f"refusing to write to {OUTPUT_DIR.resolve()}: it is outside {SCRIPT_DIR.resolve()}")

    if OUTPUT_DIR.exists():
        try:
            shutil.rmtree(OUTPUT_DIR)
        except OSError as exc:
            fail(
                f"could not remove existing {OUTPUT_DIR}: {exc}\n"
                "Close editors/terminals and any running build using that directory, then retry."
            )

    process_root_cmakelists(config, values, sub_dirs)
    process_cmake_presets(config, values)
    process_cmake_user_presets(config, values)
    process_subs(config, values)
    if project.get("test_enabled", False):
        copy_aux_dir("tests")
    if project.get("benchmark_enabled", False):
        copy_aux_dir("benchmarks")
    copy_cmake_dir(values)
    copy_remaining_root_items()
    verify_no_placeholders()

    print(f"Project generated in {OUTPUT_DIR}")
    print(f"  Main project: {project.get('name')}")
    print(f"  Subs: {[s[0] for s in sub_dirs]}")


if __name__ == "__main__":
    main()