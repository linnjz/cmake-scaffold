# Protobuf / gRPC code generation for multiple languages.
#
# Included from the root CMakeLists.txt. Nothing is discovered or executed at
# include time: protoc and the gRPC plugins are located lazily inside the
# function, so projects that never call it do not need any of the tools.
#
# Usage (call from a directory that also holds the consumer target):
#
#   scaffold_protobuf_generate(<name>
#       PROTO_FILES <file.proto>...
#       [TARGET <target>]                 # attach the generated C++ sources
#       [LANGUAGES CPP|CSHARP|JAVA|PYTHON ...]   # default: CPP
#       [GRPC]                            # also generate service stubs
#       [PROTO_PATH <dir>...]             # protoc --proto_path roots
#       [IMPORT_DIRS <dir>...]            # additional --proto_path roots
#       [OUTPUT_DIR <dir>]                # default: <build>/generated/proto
#       [DEPENDS <file>...]               # extra rebuild triggers
#       [PROTOC <path>]
#       [GRPC_CPP_PLUGIN <path>]
#       [GRPC_CSHARP_PLUGIN <path>]
#       [GRPC_JAVA_PLUGIN <path>]
#       [GRPC_PYTHON_PLUGIN <path>]
#   )
#
# Layout produced under OUTPUT_DIR: cpp/, csharp/, java/, python/. C++ headers
# are included the way protoc names them, relative to the --proto_path root,
# e.g. `#include "pkg/echo.pb.h"` for <root>/pkg/echo.proto.
#
# The C++ outputs are real build rules (custom command OUTPUT), so the consumer
# target only recompiles when a .proto changes. The other languages cannot
# enumerate their outputs (C#/Java file names depend on package/message names),
# hence one stamp file per language: regenerated when a .proto or the tools
# change, and available via `cmake --build --target <name>`.
#
# C++ consumers must link the runtime themselves, e.g.
#   target_link_libraries(<target> PRIVATE protobuf::libprotobuf gRPC::grpc++)
#
# Tools are searched in this order: the call argument, the SCAFFOLD_* cache
# entry, a `protobuf::protoc` imported target (protoc only), then
# <VCPKG_ROOT>/installed/*/tools/{protobuf,grpc} and finally PATH.
#
# On CMake >= 4.4 the generated .cc files are marked for module scanning when
# the consumer target uses `import std;`: generated sources flip the whole
# target to the unscanned rules, which would break `import std;` in the
# hand-written sources (same effect Qt AUTOMOC has).

include_guard(GLOBAL)

# Resolve one tool executable: explicit value > cache entry > find_program over
# the supplied HINTS (vcpkg tool dirs) and PATH. The result is returned through
# the first argument (PARENT_SCOPE) so callers keep locale-free local names.
function(_scaffold_protogen_find_tool out_var explicit_value cache_var)
    cmake_parse_arguments(PARSE_ARGV 3 TOOL "" "" "NAMES;HINTS")

    if(explicit_value)
        set(${out_var} "${explicit_value}" PARENT_SCOPE)
        return()
    endif()
    if(DEFINED ${cache_var} AND NOT "${${cache_var}}" STREQUAL "")
        set(${out_var} "${${cache_var}}" PARENT_SCOPE)
        return()
    endif()

    # An empty HINTS list would leave a dangling keyword, so only emit it when
    # vcpkg tool dirs were actually discovered.
    set(_hint_keywords "")
    if(TOOL_HINTS)
        list(APPEND _hint_keywords HINTS ${TOOL_HINTS})
    endif()
    find_program(${cache_var} NAMES ${TOOL_NAMES} ${_hint_keywords})
    if(${cache_var})
        set(${out_var} "${${cache_var}}" PARENT_SCOPE)
    else()
        set(${out_var} "" PARENT_SCOPE)
    endif()
endfunction()

function(scaffold_protobuf_generate name)
    cmake_parse_arguments(PARSE_ARGV 1 ARG
        "GRPC"
        "TARGET;OUTPUT_DIR;PROTOC;GRPC_CPP_PLUGIN;GRPC_CSHARP_PLUGIN;GRPC_JAVA_PLUGIN;GRPC_PYTHON_PLUGIN"
        "PROTO_FILES;PROTO_PATH;IMPORT_DIRS;LANGUAGES;DEPENDS")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "scaffold_protobuf_generate(${name}): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_PROTO_FILES)
        message(FATAL_ERROR "scaffold_protobuf_generate(${name}): PROTO_FILES is required")
    endif()
    if(TARGET ${name})
        message(FATAL_ERROR
            "scaffold_protobuf_generate(${name}): a target with that name already exists")
    endif()
    if(ARG_TARGET AND NOT TARGET ${ARG_TARGET})
        message(FATAL_ERROR
            "scaffold_protobuf_generate(${name}): TARGET '${ARG_TARGET}' does not exist")
    endif()

    if(NOT ARG_LANGUAGES)
        set(ARG_LANGUAGES CPP)
    endif()
    set(_languages "")
    foreach(_language IN LISTS ARG_LANGUAGES)
        string(TOUPPER "${_language}" _language)
        if(NOT _language MATCHES "^(CPP|CSHARP|JAVA|PYTHON)$")
            message(FATAL_ERROR
                "scaffold_protobuf_generate(${name}): unsupported language '${_language}' "
                "(supported: CPP, CSHARP, JAVA, PYTHON)")
        endif()
        list(APPEND _languages "${_language}")
    endforeach()
    list(REMOVE_DUPLICATES _languages)

    set(_out "${ARG_OUTPUT_DIR}")
    if(NOT _out)
        # Single well-known location so the files for every language are easy to
        # pick up (packaging, IDE, other toolchains).
        set(_out "${CMAKE_BINARY_DIR}/generated/proto")
    elseif(NOT IS_ABSOLUTE "${_out}")
        set(_out "${CMAKE_BINARY_DIR}/${_out}")
    endif()

    # -------------------------------------------------------------------------
    # Normalize --proto_path roots and compute each proto's import path. protoc
    # derives the output layout from the import path, so the C++ output names
    # below must use the same "longest matching root wins" rule protoc applies.
    # -------------------------------------------------------------------------
    set(_roots "")
    foreach(_dir IN LISTS ARG_PROTO_PATH IMPORT_DIRS)
        if(NOT IS_ABSOLUTE "${_dir}")
            set(_dir "${CMAKE_CURRENT_SOURCE_DIR}/${_dir}")
        endif()
        if(NOT EXISTS "${_dir}")
            message(FATAL_ERROR
                "scaffold_protobuf_generate(${name}): proto path does not exist: ${_dir}")
        endif()
        file(REAL_PATH "${_dir}" _dir)
        list(APPEND _roots "${_dir}")
    endforeach()
    list(REMOVE_DUPLICATES _roots)

    set(_proto_files "")
    set(_import_paths "")
    foreach(_proto IN LISTS ARG_PROTO_FILES)
        if(NOT IS_ABSOLUTE "${_proto}")
            set(_proto "${CMAKE_CURRENT_SOURCE_DIR}/${_proto}")
        endif()
        if(NOT EXISTS "${_proto}")
            message(FATAL_ERROR
                "scaffold_protobuf_generate(${name}): proto file does not exist: ${_proto}")
        endif()
        file(REAL_PATH "${_proto}" _proto)

        set(_rel "")
        set(_best_root_length -1)
        foreach(_root IN LISTS _roots)
            file(RELATIVE_PATH _candidate "${_root}" "${_proto}")
            if(NOT _candidate MATCHES "^\\.\\.")
                string(LENGTH "${_root}" _root_length)
                if(_root_length GREATER _best_root_length)
                    set(_best_root_length ${_root_length})
                    set(_rel "${_candidate}")
                endif()
            endif()
        endforeach()
        if(_best_root_length LESS 0)
            # Not below any given root: the file's own directory becomes the root,
            # so it is generated without an extra path prefix.
            get_filename_component(_parent "${_proto}" DIRECTORY)
            list(APPEND _roots "${_parent}")
            get_filename_component(_rel "${_proto}" NAME)
        endif()

        list(APPEND _proto_files "${_proto}")
        list(APPEND _import_paths "${_rel}")
    endforeach()

    set(_proto_path_args "")
    foreach(_root IN LISTS _roots)
        list(APPEND _proto_path_args "--proto_path=${_root}")
    endforeach()

    # -------------------------------------------------------------------------
    # Tool discovery. VCPKG_ROOT may come from Vcpkg.cmake or the environment.
    # -------------------------------------------------------------------------
    set(_vcpkg_root "${VCPKG_ROOT}")
    if(NOT _vcpkg_root AND DEFINED ENV{VCPKG_ROOT} AND NOT "$ENV{VCPKG_ROOT}" STREQUAL "")
        set(_vcpkg_root "$ENV{VCPKG_ROOT}")
    endif()
    set(_protoc_hints "")
    set(_grpc_hints "")
    if(_vcpkg_root AND EXISTS "${_vcpkg_root}/installed")
        file(GLOB _protoc_hints LIST_DIRECTORIES TRUE
            "${_vcpkg_root}/installed/*/tools/protobuf")
        file(GLOB _grpc_hints LIST_DIRECTORIES TRUE
            "${_vcpkg_root}/installed/*/tools/grpc")
    endif()

    if(NOT ARG_PROTOC AND TARGET protobuf::protoc)
        # The imported target knows the exact protoc that matches the linked
        # protobuf version, which beats any PATH match.
        set(_protoc "$<TARGET_FILE:protobuf::protoc>")
    else()
        _scaffold_protogen_find_tool(_protoc "${ARG_PROTOC}" SCAFFOLD_PROTOC_EXECUTABLE
            NAMES protoc HINTS ${_protoc_hints})
    endif()
    if(NOT _protoc)
        message(FATAL_ERROR
            "scaffold_protobuf_generate(${name}): protoc not found. Install protobuf "
            "and its tools (e.g. vcpkg install protobuf), put protoc on PATH, or pass "
            "-DSCAFFOLD_PROTOC_EXECUTABLE=<path>.")
    endif()

    set(_deps ${_proto_files} ${ARG_DEPENDS})
    # Keep the build in sync with the generators themselves, not only the .proto
    # inputs. protobuf::protoc is referenced as a target dependency because
    # $<TARGET_FILE:...> cannot be a file dependency of a custom command.
    if(_protoc MATCHES "^\\$<TARGET_FILE:")
        list(APPEND _deps protobuf::protoc)
    elseif(EXISTS "${_protoc}")
        list(APPEND _deps "${_protoc}")
    endif()

    set(_all_outputs "")
    set(_cpp_sources "")

    # -------------------------------------------------------------------------
    # C++: real output files, so the consumer target recompiles exactly when the
    # generated code changes. gRPC adds the .grpc.pb.{cc,h} pair.
    # -------------------------------------------------------------------------
    list(FIND _languages CPP _has_cpp)
    if(NOT _has_cpp EQUAL -1)
        set(_cpp_dir "${_out}/cpp")
        set(_cpp_outputs "")
        foreach(_import_path IN LISTS _import_paths)
            get_filename_component(_stem "${_import_path}" NAME_WE)
            get_filename_component(_dir "${_import_path}" DIRECTORY)
            if(_dir)
                set(_prefix "${_dir}/")
            else()
                set(_prefix "")
            endif()
            list(APPEND _cpp_outputs
                "${_cpp_dir}/${_prefix}${_stem}.pb.cc"
                "${_cpp_dir}/${_prefix}${_stem}.pb.h")
            list(APPEND _cpp_sources "${_cpp_dir}/${_prefix}${_stem}.pb.cc")
            if(ARG_GRPC)
                list(APPEND _cpp_outputs
                    "${_cpp_dir}/${_prefix}${_stem}.grpc.pb.cc"
                    "${_cpp_dir}/${_prefix}${_stem}.grpc.pb.h")
                list(APPEND _cpp_sources "${_cpp_dir}/${_prefix}${_stem}.grpc.pb.cc")
            endif()
        endforeach()

        set(_grpc_args "")
        if(ARG_GRPC)
            if(NOT ARG_GRPC_CPP_PLUGIN AND TARGET gRPC::grpc_cpp_plugin)
                # vcpkg's gRPC package exports the plugin as an imported executable
                # target, which is guaranteed to match the linked gRPC version.
                set(_grpc_cpp_plugin "$<TARGET_FILE:gRPC::grpc_cpp_plugin>")
            else()
                _scaffold_protogen_find_tool(_grpc_cpp_plugin "${ARG_GRPC_CPP_PLUGIN}" SCAFFOLD_GRPC_CPP_PLUGIN
                    NAMES grpc_cpp_plugin HINTS ${_grpc_hints})
            endif()
            if(NOT _grpc_cpp_plugin)
                message(FATAL_ERROR
                    "scaffold_protobuf_generate(${name}): grpc_cpp_plugin not found. "
                    "Install the gRPC tools, put grpc_cpp_plugin on PATH, or pass "
                    "-DSCAFFOLD_GRPC_CPP_PLUGIN=<path> / GRPC_CPP_PLUGIN.")
            endif()
            list(APPEND _grpc_args
                "--grpc_out=${_cpp_dir}"
                "--plugin=protoc-gen-grpc=${_grpc_cpp_plugin}")
            if(EXISTS "${_grpc_cpp_plugin}")
                list(APPEND _deps "${_grpc_cpp_plugin}")
            endif()
        endif()

        add_custom_command(
            OUTPUT ${_cpp_outputs}
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_cpp_dir}"
            COMMAND ${_protoc} ${_proto_path_args} "--cpp_out=${_cpp_dir}" ${_grpc_args} ${_proto_files}
            DEPENDS ${_deps}
            COMMENT "Generating C++ protobuf/gRPC sources for ${name}"
            VERBATIM
        )
        list(APPEND _all_outputs ${_cpp_outputs})
    endif()

    # -------------------------------------------------------------------------
    # Other languages: file names depend on package/message names, so the outputs
    # cannot be listed up front. A stamp file keeps the rule incremental and lets
    # `cmake --build --target <name>` emit the files.
    # -------------------------------------------------------------------------
    list(FIND _languages CSHARP _has_csharp)
    if(NOT _has_csharp EQUAL -1)
        set(_csharp_dir "${_out}/csharp")
        set(_csharp_grpc_args "")
        if(ARG_GRPC)
            if(NOT ARG_GRPC_CSHARP_PLUGIN AND TARGET gRPC::grpc_csharp_plugin)
                set(_grpc_csharp_plugin "$<TARGET_FILE:gRPC::grpc_csharp_plugin>")
            else()
                _scaffold_protogen_find_tool(_grpc_csharp_plugin "${ARG_GRPC_CSHARP_PLUGIN}" SCAFFOLD_GRPC_CSHARP_PLUGIN
                    NAMES grpc_csharp_plugin HINTS ${_grpc_hints})
            endif()
            if(NOT _grpc_csharp_plugin)
                message(FATAL_ERROR
                    "scaffold_protobuf_generate(${name}): grpc_csharp_plugin not found. "
                    "Install the gRPC tools, put grpc_csharp_plugin on PATH, or pass "
                    "-DSCAFFOLD_GRPC_CSHARP_PLUGIN=<path> / GRPC_CSHARP_PLUGIN.")
            endif()
            list(APPEND _csharp_grpc_args
                "--grpc_out=${_csharp_dir}"
                "--plugin=protoc-gen-grpc=${_grpc_csharp_plugin}")
            if(EXISTS "${_grpc_csharp_plugin}")
                list(APPEND _deps "${_grpc_csharp_plugin}")
            endif()
        endif()

        set(_csharp_stamp "${CMAKE_CURRENT_BINARY_DIR}/${name}.csharp.stamp")
        add_custom_command(
            OUTPUT "${_csharp_stamp}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_csharp_dir}"
            COMMAND ${_protoc} ${_proto_path_args} "--csharp_out=${_csharp_dir}" ${_csharp_grpc_args} ${_proto_files}
            COMMAND ${CMAKE_COMMAND} -E touch "${_csharp_stamp}"
            DEPENDS ${_deps}
            COMMENT "Generating C# protobuf/gRPC sources for ${name}"
            VERBATIM
        )
        list(APPEND _all_outputs "${_csharp_stamp}")
    endif()

    list(FIND _languages JAVA _has_java)
    if(NOT _has_java EQUAL -1)
        set(_java_dir "${_out}/java")
        set(_java_grpc_args "")
        if(ARG_GRPC)
            # protoc's Java gRPC support is a separate download (protoc-gen-grpc-java),
            # it does not ship with vcpkg's grpc tools.
            _scaffold_protogen_find_tool(_grpc_java_plugin "${ARG_GRPC_JAVA_PLUGIN}" SCAFFOLD_GRPC_JAVA_PLUGIN
                NAMES protoc-gen-grpc-java grpc_java_plugin HINTS ${_grpc_hints})
            if(NOT _grpc_java_plugin)
                message(FATAL_ERROR
                    "scaffold_protobuf_generate(${name}): protoc-gen-grpc-java not found. "
                    "Download it from https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/ "
                    "or pass -DSCAFFOLD_GRPC_JAVA_PLUGIN=<path> / GRPC_JAVA_PLUGIN.")
            endif()
            list(APPEND _java_grpc_args
                "--grpc-java_out=${_java_dir}"
                "--plugin=protoc-gen-grpc-java=${_grpc_java_plugin}")
            if(EXISTS "${_grpc_java_plugin}")
                list(APPEND _deps "${_grpc_java_plugin}")
            endif()
        endif()

        set(_java_stamp "${CMAKE_CURRENT_BINARY_DIR}/${name}.java.stamp")
        add_custom_command(
            OUTPUT "${_java_stamp}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_java_dir}"
            COMMAND ${_protoc} ${_proto_path_args} "--java_out=${_java_dir}" ${_java_grpc_args} ${_proto_files}
            COMMAND ${CMAKE_COMMAND} -E touch "${_java_stamp}"
            DEPENDS ${_deps}
            COMMENT "Generating Java protobuf/gRPC sources for ${name}"
            VERBATIM
        )
        list(APPEND _all_outputs "${_java_stamp}")
    endif()

    list(FIND _languages PYTHON _has_python)
    if(NOT _has_python EQUAL -1)
        set(_python_dir "${_out}/python")
        set(_python_grpc_args "")
        if(ARG_GRPC)
            # Provided by grpcio-tools (python -m grpc_tools.protoc also bundles it).
            _scaffold_protogen_find_tool(_grpc_python_plugin "${ARG_GRPC_PYTHON_PLUGIN}" SCAFFOLD_GRPC_PYTHON_PLUGIN
                NAMES grpc_python_plugin protoc-gen-grpc_python HINTS ${_grpc_hints})
            if(NOT _grpc_python_plugin)
                message(FATAL_ERROR
                    "scaffold_protobuf_generate(${name}): grpc_python_plugin not found. "
                    "Install grpcio-tools, put grpc_python_plugin on PATH, or pass "
                    "-DSCAFFOLD_GRPC_PYTHON_PLUGIN=<path> / GRPC_PYTHON_PLUGIN.")
            endif()
            list(APPEND _python_grpc_args
                "--grpc_python_out=${_python_dir}"
                "--plugin=protoc-gen-grpc_python=${_grpc_python_plugin}")
            if(EXISTS "${_grpc_python_plugin}")
                list(APPEND _deps "${_grpc_python_plugin}")
            endif()
        endif()

        set(_python_stamp "${CMAKE_CURRENT_BINARY_DIR}/${name}.python.stamp")
        add_custom_command(
            OUTPUT "${_python_stamp}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_python_dir}"
            COMMAND ${_protoc} ${_proto_path_args} "--python_out=${_python_dir}" ${_python_grpc_args} ${_proto_files}
            COMMAND ${CMAKE_COMMAND} -E touch "${_python_stamp}"
            DEPENDS ${_deps}
            COMMENT "Generating Python protobuf/gRPC sources for ${name}"
            VERBATIM
        )
        list(APPEND _all_outputs "${_python_stamp}")
    endif()

    # ALL: non-C++ outputs are not attached to any compile rule, so without it the
    # files would only appear when the target is built explicitly.
    add_custom_target(${name} ALL DEPENDS ${_all_outputs})

    # -------------------------------------------------------------------------
    # Attach the C++ generation to the consumer target.
    # -------------------------------------------------------------------------
    if(ARG_TARGET AND _cpp_sources)
        target_sources(${ARG_TARGET} PRIVATE ${_cpp_sources})
        target_include_directories(${ARG_TARGET} PRIVATE "${_out}/cpp")
        add_dependencies(${ARG_TARGET} ${name})

        # A target containing GENERATED sources is compiled with the unscanned
        # module rules, which breaks `import std;` in the hand-written sources
        # (C2230). Re-enable scanning for these plain .cc files when the target
        # actually uses import std. ProjectTarget.cmake applies the same logic to
        # non-generated sources; it deliberately skips GENERATED ones (Qt AUTOMOC
        # output is not scannable), so this must be done here.
        get_target_property(_std_module ${ARG_TARGET} CXX_MODULE_STD)
        get_target_property(_import_std_enabled ${ARG_TARGET} SCAFFOLD_IMPORT_STD_ENABLED)
        if(_std_module OR _import_std_enabled)
            set_source_files_properties(${_cpp_sources} PROPERTIES CXX_SCAN_FOR_MODULES ON)
        endif()
    endif()

    if(ARG_TARGET AND NOT _cpp_sources)
        message(WARNING
            "scaffold_protobuf_generate(${name}): TARGET '${ARG_TARGET}' was given but "
            "LANGUAGES contains no CPP; nothing is attached to it")
    endif()

    set(${name}_SOURCES "${_cpp_sources}" PARENT_SCOPE)
    set(${name}_INCLUDE_DIRS "${_out}/cpp" PARENT_SCOPE)
    set(${name}_OUTPUT_DIR "${_out}" PARENT_SCOPE)
endfunction()
