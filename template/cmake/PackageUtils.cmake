# ==============================================================================
# FindVcpkgPackage
#
# 在 vcpkg 安装目录中查找指定的包，并调用 find_package。
# 此函数封装了 vcpkg 特有的路径构造逻辑，并支持 find_package 的绝大多数参数，
# 允许以统一的方式管理 vcpkg 包的查找。
#
# 使用方式：
#   FindVcpkgPackage(<PackageName>
#       [LINKAGE <STATIC|DYNAMIC|AUTO>]          # 链接类型，与 TRIPLET 互斥
#       [TRIPLET <triplet>]                      # 直接指定 vcpkg triplet
#       [VERSION <version>]                       # 所需版本
#       [EXACT]                                   # 版本必须精确匹配
#       [REQUIRED]                                 # 包必须找到
#       [QUIET]                                    # 静默模式
#       [CONFIG]                                   # 强制使用 Config 模式
#       [MODULE]                                   # 强制使用 Module 模式
#       [NO_MODULE]                                # 禁用 Module 模式
#       [NO_POLICY_SCOPE]                          # 不应用策略范围
#       [GLOBAL]                                    # 将目标导入为全局
#       [BYPASS_PROVIDER]                           # 绕过包提供者（CMake 3.24+）
#       [COMPONENTS <components...>]                # 必需组件
#       [OPTIONAL_COMPONENTS <components...>]       # 可选组件
#       [NAMES <name1> <name2>...]                  # 备选包名
#       [HINTS <path>...]                            # 额外提示路径
#       [PATHS <path>...]                             # 额外搜索路径
#       [PATH_SUFFIXES <suffix>...]                   # 附加路径后缀
#       [INSTALLED_DIR <dir>]                         # 覆盖 VCPKG_INSTALLED_DIR
#       [REGISTRY_VIEW <view>]                        # 注册表视图（Windows）
#       [ALLOW_DEFAULT_PATH]                           # 允许回退到系统默认路径
#       [NO_DEFAULT_PATH]                              # 禁用默认路径（包括 vcpkg 路径？实际由 ALLOW_DEFAULT_PATH 控制）
#       [NO_PACKAGE_ROOT_PATH ...]                     # 以下为 find_package 路径控制标志，全部支持
#       [NO_CMAKE_PATH]
#       [NO_CMAKE_ENVIRONMENT_PATH]
#       [NO_SYSTEM_ENVIRONMENT_PATH]
#       [NO_CMAKE_PACKAGE_REGISTRY]
#       [NO_CMAKE_BUILDS_PATH]
#       [NO_CMAKE_SYSTEM_PATH]
#       [NO_CMAKE_INSTALL_PREFIX]
#       [NO_CMAKE_SYSTEM_PACKAGE_REGISTRY]
#       [CMAKE_FIND_ROOT_PATH_BOTH]
#       [ONLY_CMAKE_FIND_ROOT_PATH]
#       [NO_CMAKE_FIND_ROOT_PATH]
#       [KEEP_PACKAGE_DIR]                            # 不清除 <Package>_DIR 缓存
#       [KEEP_PACKAGE_ROOT]                            # 不清除 <Package>_ROOT 缓存
#       [KEEP_VCPKG_CACHE]                              # 不更新 VCPKG_INSTALLED_DIR 和 VCPKG_TARGET_TRIPLET 缓存
#   )
#
# 依赖的外部变量（可通过缓存或环境变量设置）：
#   VCPKG_ROOT                     - vcpkg 根目录（必须设置或由 INSTALLED_DIR 替代）
#   VCPKG_INSTALLED_DIR            - 覆盖 installed 目录（默认为 ${VCPKG_ROOT}/installed）
#   VCPKG_STATIC_TRIPLET           - 静态链接使用的 triplet（例如 x64-windows-static）
#   VCPKG_DYNAMIC_TRIPLET          - 动态链接使用的 triplet（例如 x64-windows）
#   VCPKG_TARGET_TRIPLET           - 目标 triplet（当 LINKAGE=AUTO 时使用）
#
# 注意：
#   - TRIPLET 参数优先级高于 LINKAGE，若同时指定则忽略 LINKAGE。
#   - 默认情况下，函数会清除 <Package>_DIR 和 <Package>_ROOT 缓存，以确保每次重新查找。
#   - 默认禁用系统默认路径（相当于 NO_DEFAULT_PATH），除非显式指定 ALLOW_DEFAULT_PATH。
#   - 支持 find_package 的所有标准参数，只需在调用时传入即可。
#
# 示例：
#   # 查找静态 OpenSSL，使用 Config 模式，必需
#   FindVcpkgPackage(OpenSSL LINKAGE STATIC REQUIRED CONFIG)
#
#   # 查找动态 absl，并指定组件
#   FindVcpkgPackage(absl LINKAGE DYNAMIC REQUIRED CONFIG COMPONENTS base strings)
#
#   # 直接指定 triplet，忽略 LINKAGE
#   FindVcpkgPackage(protobuf TRIPLET arm64-linux REQUIRED)
#
#   # 允许搜索系统默认路径，并保留缓存变量
#   FindVcpkgPackage(zlib LINKAGE STATIC ALLOW_DEFAULT_PATH KEEP_PACKAGE_DIR)
# ==============================================================================
function(FindVcpkgPackage package_name)
    # 定义函数支持的所有选项标志（布尔参数）
    set(options
        REQUIRED
        QUIET
        CONFIG
        EXACT
        MODULE
        NO_MODULE
        NO_POLICY_SCOPE
        GLOBAL
        BYPASS_PROVIDER
        NO_DEFAULT_PATH
        NO_PACKAGE_ROOT_PATH
        NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_PACKAGE_REGISTRY
        NO_CMAKE_BUILDS_PATH
        NO_CMAKE_SYSTEM_PATH
        NO_CMAKE_INSTALL_PREFIX
        NO_CMAKE_SYSTEM_PACKAGE_REGISTRY
        CMAKE_FIND_ROOT_PATH_BOTH
        ONLY_CMAKE_FIND_ROOT_PATH
        NO_CMAKE_FIND_ROOT_PATH
        ALLOW_DEFAULT_PATH          # 允许回退到系统默认路径（与 NO_DEFAULT_PATH 互斥）
        KEEP_PACKAGE_DIR             # 保留 <Package>_DIR 缓存不清除
        KEEP_PACKAGE_ROOT            # 保留 <Package>_ROOT 缓存不清除
        KEEP_VCPKG_CACHE             # 不更新 VCPKG_INSTALLED_DIR 和 VCPKG_TARGET_TRIPLET 缓存
    )
    # 定义单值参数（带一个值的参数）
    set(one_value_args LINKAGE VERSION TRIPLET INSTALLED_DIR REGISTRY_VIEW)
    # 定义多值参数（可带多个值的参数）
    set(multi_value_args COMPONENTS OPTIONAL_COMPONENTS NAMES HINTS PATHS PATH_SUFFIXES)
    # 解析传入的参数
    cmake_parse_arguments(FVP "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    # ====== 参数合法性检查 ======
    if(FVP_EXACT AND NOT FVP_VERSION)
        message(FATAL_ERROR "FindVcpkgPackage(${package_name}): EXACT requires VERSION.")
    endif()
    if(FVP_MODULE AND (FVP_CONFIG OR FVP_NO_MODULE))
        message(FATAL_ERROR "FindVcpkgPackage(${package_name}): MODULE cannot be combined with CONFIG or NO_MODULE.")
    endif()
    if(FVP_ALLOW_DEFAULT_PATH AND FVP_NO_DEFAULT_PATH)
        message(FATAL_ERROR "FindVcpkgPackage(${package_name}): ALLOW_DEFAULT_PATH conflicts with NO_DEFAULT_PATH.")
    endif()

    # 检查根路径查找模式是否互斥
    set(_fvp_root_mode_count 0)
    foreach(_fvp_mode IN ITEMS CMAKE_FIND_ROOT_PATH_BOTH ONLY_CMAKE_FIND_ROOT_PATH NO_CMAKE_FIND_ROOT_PATH)
        if(FVP_${_fvp_mode})
            math(EXPR _fvp_root_mode_count "${_fvp_root_mode_count} + 1")
        endif()
    endforeach()
    if(_fvp_root_mode_count GREATER 1)
        message(FATAL_ERROR "FindVcpkgPackage(${package_name}): CMAKE_FIND_ROOT_PATH_BOTH/ONLY_CMAKE_FIND_ROOT_PATH/NO_CMAKE_FIND_ROOT_PATH are mutually exclusive.")
    endif()

    # ====== 确定 vcpkg triplet ======
    if(FVP_TRIPLET)
        # 直接使用用户指定的 triplet
        set(vcpkg_triplet "${FVP_TRIPLET}")
    else()
        # 根据 LINKAGE 推断 triplet
        if(NOT FVP_LINKAGE)
            set(FVP_LINKAGE "DYNAMIC")
        endif()
        string(TOUPPER "${FVP_LINKAGE}" linkage_mode)
        if(linkage_mode STREQUAL "STATIC")
            if(NOT DEFINED VCPKG_STATIC_TRIPLET OR VCPKG_STATIC_TRIPLET STREQUAL "")
                message(FATAL_ERROR "FindVcpkgPackage(${package_name}): VCPKG_STATIC_TRIPLET is not set.")
            endif()
            set(vcpkg_triplet "${VCPKG_STATIC_TRIPLET}")
        elseif(linkage_mode STREQUAL "DYNAMIC")
            if(NOT DEFINED VCPKG_DYNAMIC_TRIPLET OR VCPKG_DYNAMIC_TRIPLET STREQUAL "")
                message(FATAL_ERROR "FindVcpkgPackage(${package_name}): VCPKG_DYNAMIC_TRIPLET is not set.")
            endif()
            set(vcpkg_triplet "${VCPKG_DYNAMIC_TRIPLET}")
        elseif(linkage_mode STREQUAL "AUTO")
            # 自动模式：优先使用 VCPKG_TARGET_TRIPLET，其次使用 VCPKG_DYNAMIC_TRIPLET
            if(DEFINED VCPKG_TARGET_TRIPLET AND NOT VCPKG_TARGET_TRIPLET STREQUAL "")
                set(vcpkg_triplet "${VCPKG_TARGET_TRIPLET}")
            elseif(DEFINED VCPKG_DYNAMIC_TRIPLET AND NOT VCPKG_DYNAMIC_TRIPLET STREQUAL "")
                set(vcpkg_triplet "${VCPKG_DYNAMIC_TRIPLET}")
            else()
                message(FATAL_ERROR "FindVcpkgPackage(${package_name}): LINKAGE AUTO requires VCPKG_TARGET_TRIPLET or VCPKG_DYNAMIC_TRIPLET.")
            endif()
        else()
            message(FATAL_ERROR "FindVcpkgPackage(${package_name}): unsupported LINKAGE '${FVP_LINKAGE}'. Allowed values: STATIC, DYNAMIC, AUTO.")
        endif()
    endif()

    # ====== 确定 vcpkg installed 目录 ======
    if(FVP_INSTALLED_DIR)
        set(vcpkg_installed_dir "${FVP_INSTALLED_DIR}")
    elseif(DEFINED VCPKG_INSTALLED_DIR AND NOT VCPKG_INSTALLED_DIR STREQUAL "")
        set(vcpkg_installed_dir "${VCPKG_INSTALLED_DIR}")
    elseif(DEFINED VCPKG_ROOT AND NOT VCPKG_ROOT STREQUAL "")
        set(vcpkg_installed_dir "${VCPKG_ROOT}/installed")
    else()
        message(FATAL_ERROR "FindVcpkgPackage(${package_name}): VCPKG_ROOT or INSTALLED_DIR must be set.")
    endif()
    # 转换为绝对路径
    get_filename_component(vcpkg_installed_dir "${vcpkg_installed_dir}" ABSOLUTE)

    # 构造 triplet 根目录和 share 目录
    set(vcpkg_triplet_root "${vcpkg_installed_dir}/${vcpkg_triplet}")
    set(vcpkg_share_path "${vcpkg_triplet_root}/share")

    # Provide vcpkg context variables for package config/wrapper scripts
    # when CMake is not driven by the official vcpkg toolchain.
    set(VCPKG_INSTALLED_DIR "${vcpkg_installed_dir}")
    set(VCPKG_TARGET_TRIPLET "${vcpkg_triplet}")
    set(_VCPKG_INSTALLED_DIR "${vcpkg_installed_dir}")

    # ====== 可选：更新 vcpkg 相关缓存变量 ======
    if(NOT FVP_KEEP_VCPKG_CACHE)
        set(VCPKG_INSTALLED_DIR "${vcpkg_installed_dir}" CACHE PATH "Vcpkg installed directory" FORCE)
        set(VCPKG_TARGET_TRIPLET "${vcpkg_triplet}" CACHE STRING "Vcpkg target triplet" FORCE)
        set(_VCPKG_INSTALLED_DIR "${vcpkg_installed_dir}" CACHE INTERNAL "Vcpkg installed directory (wrapper compatibility)" FORCE)
    endif()

    # ====== 构建 HINTS 列表 ======
    set(find_hints "${vcpkg_triplet_root}" "${vcpkg_share_path}")
    if(FVP_HINTS)
        list(APPEND find_hints ${FVP_HINTS})
    endif()
    list(REMOVE_DUPLICATES find_hints)

    # ====== 检查 triplet 路径是否存在 ======
    if(NOT EXISTS "${vcpkg_triplet_root}")
        if(FVP_ALLOW_DEFAULT_PATH)
            if(NOT FVP_QUIET)
                message(WARNING "FindVcpkgPackage(${package_name}): Vcpkg triplet path not found, fallback to default search paths: ${vcpkg_triplet_root}")
            endif()
        else()
            message(FATAL_ERROR "FindVcpkgPackage(${package_name}): Vcpkg triplet path not found: ${vcpkg_triplet_root}")
        endif()
    endif()

    # ====== 构建最终传递给 find_package 的参数列表 ======
    set(find_args "${package_name}")

    # 版本相关
    if(FVP_VERSION)
        list(APPEND find_args "${FVP_VERSION}")
        if(FVP_EXACT)
            list(APPEND find_args EXACT)
        endif()
    endif()

    # 基本控制标志
    if(FVP_REQUIRED)
        list(APPEND find_args REQUIRED)
    endif()
    if(FVP_QUIET)
        list(APPEND find_args QUIET)
    endif()
    if(FVP_CONFIG)
        list(APPEND find_args CONFIG)
    endif()
    if(FVP_MODULE)
        list(APPEND find_args MODULE)
    endif()
    if(FVP_NO_MODULE)
        list(APPEND find_args NO_MODULE)
    endif()
    if(FVP_NO_POLICY_SCOPE)
        list(APPEND find_args NO_POLICY_SCOPE)
    endif()
    if(FVP_GLOBAL)
        list(APPEND find_args GLOBAL)
    endif()
    if(FVP_BYPASS_PROVIDER)
        list(APPEND find_args BYPASS_PROVIDER)
    endif()
    if(FVP_REGISTRY_VIEW)
        list(APPEND find_args REGISTRY_VIEW "${FVP_REGISTRY_VIEW}")
    endif()

    # 组件
    if(FVP_COMPONENTS)
        list(APPEND find_args COMPONENTS ${FVP_COMPONENTS})
    endif()
    if(FVP_OPTIONAL_COMPONENTS)
        list(APPEND find_args OPTIONAL_COMPONENTS ${FVP_OPTIONAL_COMPONENTS})
    endif()

    # 包名别名
    if(FVP_NAMES)
        list(APPEND find_args NAMES ${FVP_NAMES})
    endif()

    # 搜索路径提示
    if(find_hints)
        list(APPEND find_args HINTS ${find_hints})
    endif()
    if(FVP_PATHS)
        list(APPEND find_args PATHS ${FVP_PATHS})
    endif()
    if(FVP_PATH_SUFFIXES)
        list(APPEND find_args PATH_SUFFIXES ${FVP_PATH_SUFFIXES})
    endif()

    # 默认路径控制：默认禁用系统默认路径，除非显式允许
    if(FVP_NO_DEFAULT_PATH OR NOT FVP_ALLOW_DEFAULT_PATH)
        list(APPEND find_args NO_DEFAULT_PATH)
    endif()

    # 所有其他 find_package 路径控制标志（直接添加）
    foreach(_fvp_flag IN ITEMS
        NO_PACKAGE_ROOT_PATH
        NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_PACKAGE_REGISTRY
        NO_CMAKE_BUILDS_PATH
        NO_CMAKE_SYSTEM_PATH
        NO_CMAKE_INSTALL_PREFIX
        NO_CMAKE_SYSTEM_PACKAGE_REGISTRY
        CMAKE_FIND_ROOT_PATH_BOTH
        ONLY_CMAKE_FIND_ROOT_PATH
        NO_CMAKE_FIND_ROOT_PATH
    )
        if(FVP_${_fvp_flag})
            list(APPEND find_args ${_fvp_flag})
        endif()
    endforeach()

    # 添加任何未解析的参数（作为后备）
    if(FVP_UNPARSED_ARGUMENTS)
        list(APPEND find_args ${FVP_UNPARSED_ARGUMENTS})
    endif()

    # ====== 清理可能干扰的缓存变量 ======
    if(NOT FVP_KEEP_PACKAGE_DIR)
        unset(${package_name}_DIR CACHE)
        string(TOUPPER "${package_name}" package_name_upper)
        unset(${package_name_upper}_DIR CACHE)
    endif()
    if(NOT FVP_KEEP_PACKAGE_ROOT)
        unset(${package_name}_ROOT CACHE)
        string(TOUPPER "${package_name}" package_name_upper)
        unset(${package_name_upper}_ROOT CACHE)
    endif()

    # ====== 调用真正的 find_package ======
    find_package(${find_args})
endfunction()

function(CopyTargetDependentLibs target_name lib_base_names release_lib_path)
    if(NOT TARGET ${target_name})
        message(WARNING "Target ${target_name} does not exist, skipping library copy")
        return()
    endif()

    set(debug_lib_path "${ARGV3}")
    if(NOT debug_lib_path)
        set(debug_lib_path "${release_lib_path}")
    endif()

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(search_path "${debug_lib_path}")
    else()
        set(search_path "${release_lib_path}")
    endif()

    if(NOT EXISTS "${search_path}")
        message(WARNING "Library search path does not exist: ${search_path}")
        return()
    endif()

    # Process each library
    foreach(LIB_BASE_NAME ${lib_base_names})
        # Platform-specific file pattern (handle versioned .so on Linux)
        if(UNIX AND NOT APPLE)  # Linux: match .so, .so.1, .so.1.2.3 etc.
            set(LIB_PATTERN "${LIB_BASE_NAME}${SHARED_LIB_SUFFIX}*")
        else()  # Windows/macOS: exact suffix match (no version wildcard)
            set(LIB_PATTERN "${LIB_BASE_NAME}${SHARED_LIB_SUFFIX}")
        endif()

        # Find all matching library files
        file(GLOB LIB_FILES 
            "${search_path}/${LIB_PATTERN}"
            LIST_DIRECTORIES false  # Exclude directories from results
        )

        unset(FOUND_LIBS)
        # Filter out invalid files (only keep regular files)
        foreach(LIB_FILE ${LIB_FILES})
            if(EXISTS "${LIB_FILE}" AND NOT IS_DIRECTORY "${LIB_FILE}")
                get_filename_component(FILE_EXT "${LIB_FILE}" LAST_EXT)
                if(FILE_EXT MATCHES "\\.(dll|so|dylib|lib|a)$" OR 
                   (WIN32 AND (NOT FILE_EXT OR FILE_EXT STREQUAL ".dll")))
                    # Copy library to target output directory (only if different)
                    add_custom_command(TARGET ${target_name} POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                            "${LIB_FILE}"
                            $<TARGET_FILE_DIR:${target_name}>
                        COMMENT "Copying ${LIB_FILE} to output directory"
                    )
                    list(APPEND FOUND_LIBS "${LIB_FILE}")
                endif()
            endif()
        endforeach()

        if(NOT FOUND_LIBS)
            message(WARNING "No shared library files found for pattern: ${search_path}/${LIB_PATTERN}")
        else()
            message(STATUS "Copied libraries for ${LIB_BASE_NAME}: ${FOUND_LIBS}")
        endif()
    endforeach()
endfunction()

function(SetTargetRuntimeDependencyPath target_name)
  if(WIN32)
    # For Visual Studio, set debug environment path
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(vcpkg_bin_path "${VCPKG_DEBUG_BIN_PATH}")
    else()
      set(vcpkg_bin_path "${VCPKG_BIN_PATH}")
    endif()

    set_target_properties(${target_name} PROPERTIES
      VS_DEBUGGER_ENVIRONMENT "PATH=${vcpkg_bin_path};$ENV{PATH}"
    )
  else()
    # # For Unix-like (Linux/macOS), set RPATH
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(rpath "${VCPKG_DEBUG_BIN_PATH}:${VCPKG_DEBUG_BIN_PATH}/../lib")
    else()
      set(rpath "${VCPKG_BIN_PATH}:${VCPKG_BIN_PATH}/../lib")
    endif()
        
    set_target_properties(${target_name} PROPERTIES
      BUILD_WITH_INSTALL_RPATH TRUE
      INSTALL_RPATH "${rpath}"
    )
  endif()
endfunction()


function(IMPORTED_LIBRARY target_name lib_base_name library_dir)
    if(TARGET ${target_name})
        return()
    endif()

    set(lib_path "${library_dir}/${lib_base_name}${LIB_SUFFIX}")
    set(shared_lib_base "${library_dir}/${lib_base_name}${SHARED_LIB_SUFFIX}")

    # Handle wildcard for versioned .so files (Linux only)
    set(shared_lib_path "${shared_lib_base}")
    if(UNIX AND NOT APPLE)
        # Use glob to find any versioned .so (e.g., .so, .so.3, .so.3.3.0)
        file(GLOB versioned_libs "${shared_lib_base}*")
        if(versioned_libs)
            # Pick the first matched library (prioritize full version if exists)
            list(SORT versioned_libs COMPARE NATURAL ORDER DESCENDING)
            list(GET versioned_libs 0 shared_lib_path)
        endif()
    endif()

    if(NOT EXISTS "${shared_lib_path}")
        message(WARNING "❌ Shared library not found: ${shared_lib_base}*")
        return()
    endif()

    # Create imported target
    add_library(${target_name} SHARED IMPORTED)
    
    # Set platform-specific properties
    if(WIN32)
        set_target_properties(${target_name} PROPERTIES
            IMPORTED_LOCATION "${shared_lib_path}"
            IMPORTED_IMPLIB "${lib_path}"
            IMPORTED_LOCATION_DEBUG "${shared_lib_path}"
            IMPORTED_IMPLIB_DEBUG "${lib_path}"
            IMPORTED_LOCATION_RELEASE "${shared_lib_path}"
            IMPORTED_IMPLIB_RELEASE "${lib_path}"
            IMPORTED_LOCATION_RELWITHDEBINFO "${shared_lib_path}"
            IMPORTED_IMPLIB_RELWITHDEBINFO "${lib_path}"
            IMPORTED_LOCATION_MINSIZEREL "${shared_lib_path}"
            IMPORTED_IMPLIB_MINSIZEREL "${lib_path}"
        )
    else()
        set_target_properties(${target_name} PROPERTIES
            IMPORTED_LOCATION "${shared_lib_path}"  # .so/.dylib path
        )
    endif()

    message(STATUS "✅ Found library: ${shared_lib_path}")
endfunction()
