#!/usr/bin/env python3
import json
import os
import re
import shutil
import sys
import tomllib
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE_DIR = SCRIPT_DIR / "template"
OUTPUT_DIR: Path = None
TOML_PATH = SCRIPT_DIR / "project.toml"

ALL_COMPILERS = ["msvc", "clang", "gcc", "clang-cl"]
ALL_BUILD_TYPES = ["Debug", "RelWithDebInfo", "Release", "MinSizeRel"]

COMPILER_KEYWORDS = ["msvc", "clang-cl", "clang", "gcc"]

PATH_KEYWORDS = ["llvm", "clang", "msvc", "cmake", "ninja", "windows kits",
                 "windows", "system32", "common7"]


def load_toml():
    try:
        with open(TOML_PATH, "rb") as f:
            return tomllib.load(f)
    except FileNotFoundError:
        print(f"Error: {TOML_PATH} not found")
        sys.exit(1)


def validate(config):
    name = config.get("project", {}).get("name", "")
    if not name.strip():
        print("Error: project.name must not be empty")
        sys.exit(1)


def get_cpu_actual_max():
    try:
        return max(1, len(os.sched_getaffinity(0)))
    except AttributeError:
        return max(1, os.cpu_count() or 1)


def resolve_jobs(config):
    jobs = config.get("project", {}).get("jobs", {})
    if not isinstance(jobs, dict):
        print("Error: project.jobs must be a table, e.g. { type = \"fixed\", size = 0 }")
        sys.exit(1)
    cpu_max = get_cpu_actual_max()
    jtype = jobs.get("type", "fixed")
    if jtype == "fixed":
        size = jobs.get("size", 0)
        if not isinstance(size, int) or isinstance(size, bool):
            print("Error: jobs.size must be an integer when type is 'fixed'")
            sys.exit(1)
        if size <= 0:
            return cpu_max
        return min(size, cpu_max)
    if jtype == "factor":
        try:
            size = float(jobs.get("size", 1.0))
        except (TypeError, ValueError):
            print("Error: jobs.size must be a number when type is 'factor'")
            sys.exit(1)
        if size <= 0.0:
            return cpu_max
        size = min(1.0, size)
        # round, not int truncation: 100 * 0.29 == 28.999999999999996 must resolve to 29
        return max(1, min(round(cpu_max * size), cpu_max))
    print(f"Error: jobs.type '{jtype}' is not supported (use 'fixed' or 'factor')")
    sys.exit(1)


def get_subs(config):
    main_name = config.get("project", {}).get("name", "")
    subs = config.get("project", {}).get("sub", [])
    if not subs:
        subs = [{}]
    result = []
    for sub in subs:
        raw_name = sub.get("name", "").strip()
        if not raw_name:
            dir_name = "src"
            project_name = main_name
        else:
            dir_name = raw_name
            project_name = raw_name
        result.append((dir_name, project_name, sub))
    return result


def replace_placeholders(text, replacements):
    for key, value in replacements.items():
        text = text.replace(f"#{{{key}}}", str(value))
    return text


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write_file(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def detect_compiler(name):
    name_lower = name.lower()
    if "clang-cl" in name_lower:
        return "clang-cl"
    for c in ["msvc", "clang", "gcc"]:
        if name_lower.startswith(c) or f"-{c}" in name_lower or f"_{c}" in name_lower:
            return c
    return None


def detect_build_type(name):
    name_lower = name.lower()
    for bt in ["debug", "relwithdebinfo", "release", "minsizerel"]:
        if name_lower.endswith(f"_{bt}"):
            return bt
    return None


def process_cmake_user_presets(config, replacements):
    src = TEMPLATE_DIR / "CMakeUserPresets.json"
    dest = OUTPUT_DIR / "CMakeUserPresets.json"

    content = replace_placeholders(read_file(src), replacements)
    data = json.loads(content)

    user_cfg = config.get("presets", {}).get("user", {})
    enabled_compilers = [c.lower() for c in user_cfg.get("compilers", [])]
    enabled_build_types = [bt.lower() for bt in user_cfg.get("build_types", [])]
    install_dir_template = user_cfg.get("install_dir", "${sourceDir}/out/install/${presetGroup}")
    arch = replacements.get("ARCHITECTURE", "x64")

    for preset in data.get("configurePresets", []):
        name = preset.get("name", "")
        compiler = detect_compiler(name)
        build_type = detect_build_type(name)

        if build_type:
            hidden = False
            if compiler and compiler not in enabled_compilers:
                hidden = True
            if build_type and build_type not in enabled_build_types:
                hidden = True
            preset["hidden"] = hidden

        if compiler and name.endswith("-local"):
            preset_group = f"{compiler}_{arch}"
            preset["installDir"] = install_dir_template.replace("${presetGroup}", preset_group)

    for preset in data.get("buildPresets", []):
        name = preset.get("name", "")
        compiler = detect_compiler(name)
        build_type = detect_build_type(name)
        if build_type:
            hidden = False
            if compiler and compiler not in enabled_compilers:
                hidden = True
            if build_type and build_type not in enabled_build_types:
                hidden = True
            preset["hidden"] = hidden

    write_file(dest, json.dumps(data, indent=2))


def resolve_penv(value):
    if not isinstance(value, str):
        return value
    def _replace(m):
        return os.environ.get(m.group(1), "").strip()
    return re.sub(r'\$penv\{(\w+)\}', _replace, value)


def process_cmake_presets(config, replacements):
    src = TEMPLATE_DIR / "CMakePresets.json"
    dest = OUTPUT_DIR / "CMakePresets.json"

    content = replace_placeholders(read_file(src), replacements)
    data = json.loads(content)

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

    def filter_path(value):
        parts = value.split(";")
        kept = [p for p in parts if any(kw in p.lower() for kw in PATH_KEYWORDS)]
        return ";".join(kept)

    for preset in data.get("configurePresets", []):
        env = preset.get("environment")
        if not env:
            continue
        for key in list(env.keys()):
            resolved = resolve_penv(env[key])
            if resolved == "":
                del env[key]
            elif key == "PATH":
                env[key] = filter_path(resolved)
            else:
                env[key] = resolved

    write_file(dest, json.dumps(data, indent=2))


def process_root_cmakelists(config, replacements, sub_dirs):
    src = TEMPLATE_DIR / "CMakeLists.txt"
    dest = OUTPUT_DIR / "CMakeLists.txt"

    content = replace_placeholders(read_file(src), replacements)

    qt_enabled = config.get("qt", {}).get("qt_enabled", False)
    qt_sdk = config.get("qt", {}).get("sdk_dir", "D:/Qt/6.6.2/msvc2019_64")
    qt_components = " ".join(config.get("qt", {}).get("components", ["Widgets"]))

    content = content.replace("#{QT_SUPPORT_DEFAULT}", "ON" if qt_enabled else "OFF")
    content = content.replace("#{QT_SDK_DIR}", qt_sdk)
    content = content.replace("#{QT_COMPONENTS}", qt_components)

    add_sub_lines = []
    for sub_dir_name, _, _ in sub_dirs:
        add_sub_lines.append(f"add_subdirectory({sub_dir_name})")
    if add_sub_lines:
        content += "\n\n" + "\n".join(add_sub_lines) + "\n"

    write_file(dest, content)


def process_subs(config, replacements):
    subs = get_subs(config)
    project = config.get("project", {})
    src_txt = TEMPLATE_DIR / "src" / "CMakeLists.txt"
    src_cmake = TEMPLATE_DIR / "src" / "Dependencies.cmake"

    for dir_name, project_name, sub in subs:
        sub_replacements = dict(replacements)
        sub_replacements["SUB_PROJECT_NAME"] = project_name
        sub_replacements["SUB_PROJECT_VERSION"] = sub.get("version") or project.get("version", "1.0.0")
        sub_replacements["SUB_PROJECT_DESCRIPTION"] = sub.get("description") or project.get("description", "")
        sub_replacements["TARGET_TYPE"] = sub.get("target_type", "EXE")
        sub_replacements["MACOS_BUNDLE"] = "ON" if sub.get("macos_bundle", True) else "OFF"
        sub_replacements["WIN32_EXECUTABLE"] = "ON" if sub.get("win32_executable", True) else "OFF"

        sub_dir = OUTPUT_DIR / dir_name
        sub_dir.mkdir(parents=True, exist_ok=True)

        write_file(sub_dir / "CMakeLists.txt", replace_placeholders(read_file(src_txt), sub_replacements))
        write_file(sub_dir / "Dependencies.cmake", replace_placeholders(read_file(src_cmake), sub_replacements))

        for item in (TEMPLATE_DIR / "src").iterdir():
            if item.name in ("CMakeLists.txt", "Dependencies.cmake"):
                continue
            dest = sub_dir / item.name
            if item.is_dir():
                shutil.copytree(item, dest, dirs_exist_ok=True)
            else:
                shutil.copy2(item, dest)


def copy_remaining_root_items():
    for item in TEMPLATE_DIR.iterdir():
        if item.name in ("CMakeLists.txt", "CMakePresets.json", "CMakeUserPresets.json", "cmake", "src"):
            continue
        dest = OUTPUT_DIR / item.name
        if item.is_dir():
            shutil.copytree(item, dest, dirs_exist_ok=True)
        else:
            shutil.copy2(item, dest)


def copy_cmake_dir():
    src = TEMPLATE_DIR / "cmake"
    dest = OUTPUT_DIR / "cmake"
    if src.exists():
        shutil.copytree(src, dest, dirs_exist_ok=True)


def process_vscode_settings(config, replacements):
    dest_dir = OUTPUT_DIR / ".vscode"
    dest_dir.mkdir(parents=True, exist_ok=True)

    cr_cfg = config.get("code_runner", {})
    if not cr_cfg.get("enabled", True):
        return

    user_cfg = config.get("presets", {}).get("user", {})
    compilers = user_cfg.get("compilers", [])
    build_types = user_cfg.get("build_types", [])
    arch = replacements.get("ARCHITECTURE", "x64")

    explicit_preset = cr_cfg.get("default_preset", "")
    if explicit_preset:
        default_preset = explicit_preset
    else:
        first_compiler = compilers[0] if compilers else "msvc"
        first_build = build_types[0] if build_types else "Debug"
        default_preset = f"build-{first_compiler}_{arch}_{first_build}"

    build_cmd = f"cd $workspaceRoot && cmake --build --preset {default_preset}"

    cpp_mode = cr_cfg.get("cpp_mode", "cmake")
    if cpp_mode == "direct":
        compiler = first_compiler
        if compiler in ("gcc",):
            cpp_cmd = f"cd $dir && g++ -std=c++23 $fileName -o $fileNameWithoutExt && $dir$fileNameWithoutExt"
            c_cmd = f"cd $dir && gcc -std=c23 $fileName -o $fileNameWithoutExt && $dir$fileNameWithoutExt"
        elif compiler == "clang":
            cpp_cmd = f"cd $dir && clang++ -std=c++23 $fileName -o $fileNameWithoutExt && $dir$fileNameWithoutExt"
            c_cmd = f"cd $dir && clang -std=c23 $fileName -o $fileNameWithoutExt && $dir$fileNameWithoutExt"
        else:
            cpp_cmd = build_cmd
            c_cmd = build_cmd
    else:
        cpp_cmd = build_cmd
        c_cmd = build_cmd

    settings_jsonc = f'''  // 切换构建模式请使用 CMake 扩展状态栏的预设选择器
  // Switch build mode via CMake Tools status bar preset selector
  "code-runner.executorMapByGlob": {{
    "CMakeLists.txt": {json.dumps(build_cmd)}
  }},
  "code-runner.executorMap": {{
    "cpp": {json.dumps(cpp_cmd)},
    "c": {json.dumps(c_cmd)}
  }}
'''

    src = TEMPLATE_DIR / ".vscode" / "settings.json"
    existing = read_file(src).rstrip()
    if existing.endswith("}"):
        existing = existing[:-1].rstrip().rstrip(",").rstrip()

    write_file(dest_dir / "settings.json", existing + ",\n" + settings_jsonc + "}\n")


def main():
    global OUTPUT_DIR
    config = load_toml()
    validate(config)

    project = config.get("project", {})
    OUTPUT_DIR = SCRIPT_DIR / project["name"]
    presets = config.get("presets", {})
    sub_dirs = get_subs(config)

    replacements = {
        "MAIN_PROJECT_NAME": project.get("name", ""),
        "PROJECT_VERSION": project.get("version", "1.0.0"),
        "PROJECT_DESCRIPTION": project.get("description", ""),
        "PROJECT_HOMEPAGE_URL": project.get("homepage_url", ""),
        "PROJECT_LANGUAGES": " ".join(project.get("languages", ["CXX"])),
        "GENERATOR": presets.get("generator", "Ninja"),
        "BINARY_DIR": presets.get("binary_dir", "${sourceDir}/out/build/${presetName}"),
        "ARCHITECTURE": presets.get("architecture", "x64"),
        "MSVC_RUNTIME_MODE": presets.get("msvc_runtime_mode", "MD"),
        "MSVC_TOOLSET": presets.get("msvc_toolset", "v145"),
        "JOBS": resolve_jobs(config),
    }

    if OUTPUT_DIR.exists():
        try:
            shutil.rmtree(OUTPUT_DIR)
        except PermissionError:
            print(f"Warning: could not remove existing {OUTPUT_DIR} (in use)")

    process_root_cmakelists(config, replacements, sub_dirs)
    process_cmake_presets(config, replacements)
    process_cmake_user_presets(config, replacements)
    process_subs(config, replacements)
    copy_cmake_dir()
    copy_remaining_root_items()
    process_vscode_settings(config, replacements)

    print(f"Project generated in {OUTPUT_DIR}")
    print(f"  Main project: {project.get('name')}")
    print(f"  Subs: {[s[0] for s in sub_dirs]}")


if __name__ == "__main__":
    main()