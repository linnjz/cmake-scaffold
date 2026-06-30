# MSVC + Ninja header dependency tracking.
#
# cl.exe prints /showIncludes lines in the active console output code page,
# but CMake's compiler ID detection decodes the captured output with a fixed
# system code page. When the two differ (UTF-8 terminal on a CP936 system),
# the prefix written to msvc_deps_prefix does not match the bytes Ninja sees
# at build time: every object silently records #deps 0, and header-only edits
# stop rebuilding the translation units that include the header, linking
# objects compiled against stale class layouts.
#
# Re-detect the prefix by dumping the compiler output to a file and reading
# the bytes back verbatim (no pipe transcoding), then pin it on the top level,
# where the Ninja generator picks it up when writing rules.ninja. Configure
# and build must run under the same console code page for the bytes to match.
#
# CMake 4.4 stores the detected value in CMAKE_<LANG>_CL_SHOWINCLUDES_PREFIX;
# the built-in detection lives in CMAKE_DETERMINE_MSVC_SHOWINCLUDES_PREFIX
# (CMakeDetermineCompilerId.cmake), which feeds the same regex used below.
#
# On CMake >= 4.4 this file must do nothing: the built-in detection runs for
# Ninja generators, keeps the value as decoded Unicode (CMakeCXXCompiler.cmake
# stores "注意: 包含文件:  " in UTF-8), and the Ninja writer re-encodes it to
# the local code page when writing rules.ninja, matching cl.exe byte for byte.
# Writing the raw code-page bytes into the variable instead makes it invalid
# UTF-8, and CMake 4.4 silently omits CMakeFiles/rules.ninja (configure still
# exits 0; ninja then dies with "loading 'CMakeFiles/rules.ninja': The system
# cannot find the file specified"). The workaround is only needed for the
# older CMake versions that do not detect the prefix for Ninja themselves.

if(NOT MSVC OR NOT CMAKE_GENERATOR MATCHES "^Ninja")
  return()
endif()

if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4")
  return()
endif()

set(_showincludes_probe_dir "${CMAKE_BINARY_DIR}/CMakeFiles/ShowIncludesPrefix")
file(MAKE_DIRECTORY "${_showincludes_probe_dir}")
file(WRITE "${_showincludes_probe_dir}/probe.h" "\n")
file(WRITE "${_showincludes_probe_dir}/probe.cpp" "#include \"probe.h\"\n")
execute_process(
  COMMAND "${CMAKE_CXX_COMPILER}" /nologo /showIncludes /c probe.cpp /Foprobe.obj
  WORKING_DIRECTORY "${_showincludes_probe_dir}"
  OUTPUT_FILE "${_showincludes_probe_dir}/probe.txt"
  ERROR_FILE "${_showincludes_probe_dir}/probe.txt"
  RESULT_VARIABLE _showincludes_probe_result
)
if(_showincludes_probe_result EQUAL 0)
  file(READ "${_showincludes_probe_dir}/probe.txt" _showincludes_probe_output)
  if("${_showincludes_probe_output}" MATCHES "(^|\n)([^:\n][^:\n]+:[^:\n]*[^: \n][^: \n]:?[ \t]+)([A-Za-z]:\\\\|\\./|\\.\\\\|/)")
    set(_showincludes_probe_prefix "${CMAKE_MATCH_2}")
    set(CMAKE_CL_SHOWINCLUDES_PREFIX "${_showincludes_probe_prefix}")
    set(CMAKE_C_CL_SHOWINCLUDES_PREFIX "${_showincludes_probe_prefix}")
    set(CMAKE_CXX_CL_SHOWINCLUDES_PREFIX "${_showincludes_probe_prefix}")
  endif()
endif()
unset(_showincludes_probe_dir)
unset(_showincludes_probe_result)
unset(_showincludes_probe_output)
unset(_showincludes_probe_prefix)
