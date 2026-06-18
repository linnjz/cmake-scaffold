cmake_minimum_required(VERSION 3.30)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "f35a9ac6-8463-4d38-8eec-5d6008153e7d")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.3.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "451f2fe2-a8a2-47c3-bc32-94786d8fc91b")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0.3")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "a9e1cf81-9932-4810-974b-6eccaf14e457")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "3.31.8")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "3.30.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "0e5b6991-d74f-4b3d-a41c-cf096e0b2508")
endif()

# CMake 4.4+ supports clang-cl; on earlier versions comment it out and fall back to manual scanning via CxxModules.cmake
# Otherwise module scanning is force-enabled during the probe phase; CMake 4.3 does not recognize the clang-cl scanner, so generation fails and configure dies right at the start
#"CMAKE_CXX_SCAN_FOR_MODULES": "ON", 

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(#{MAIN_PROJECT_NAME}
    VERSION #{PROJECT_VERSION}
    DESCRIPTION "#{PROJECT_DESCRIPTION}"
    HOMEPAGE_URL "#{PROJECT_HOMEPAGE_URL}"
    LANGUAGES #{PROJECT_LANGUAGES}
)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

# Must run after project(): pins the localized /showIncludes prefix that the
# compiler ID detection registers per language (see the file for the details).
include(CMake/ShowIncludesPrefix.cmake)

list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)
include(cmake/PlatformConfig.cmake)
include(cmake/PackageUtils.cmake)
#include(cmake/GlobalThirdParty.cmake)
# Comes with third-party libraries and vcpkg management; whichever is added to the search path first will be found first.
#include(cmake/VcpkgConfig.cmake) # vcpkg 3rdparty
#include(cmake/CompilerFlags.cmake)

# 0 means build with the maximum number of threads; precedence: -j/--parallel (command line) > CMAKE_BUILD_PARALLEL_LEVEL (env var) > preset "jobs" > ninja default (all cores)
set(CMAKE_BUILD_PARALLEL_LEVEL #{JOBS} CACHE STRING "Number of parallel compile threads")

set(PROJECT_BUILD_ARTIFACT_DIR "${CMAKE_BINARY_DIR}/artifacts/${CMAKE_BUILD_TYPE}/${PLATFORM_SUFFIX}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/bin" CACHE PATH "Runtime output directory")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/lib" CACHE PATH "Library output directory")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/lib" CACHE PATH "Archive output directory")
set(CMAKE_PCH_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/pch" CACHE PATH "Precompiled header output directory")
set(CMAKE_ASM_LISTING_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/asm" CACHE PATH "Assembly listing output directory")
set(CMAKE_CXX_MODULE_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/modules" CACHE PATH "C++ module output directory")
if (COMPILER_MSVC)
  set(CMAKE_COMPILE_PDB_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/pdb" CACHE PATH "PDB compile output directory")
  set(CMAKE_PDB_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/pdb" CACHE PATH "PDB output directory")
endif()

option(QT_SUPPORT "Enable Qt framework support" #{QT_SUPPORT_DEFAULT})
if(QT_SUPPORT)
	set(CMAKE_AUTOUIC ON)
	set(CMAKE_AUTOMOC ON)
	set(CMAKE_AUTORCC ON)
	# generate.py replaces #{QT_SDK_DIR} when [qt] is configured in project.toml
	# For manual setup, set QT_SDK_DIR in CMake cache or via cmake -D
	if(NOT QT_SDK_DIR)
		set(QT_SDK_DIR "#{QT_SDK_DIR}" CACHE PATH "Path to Qt SDK (e.g. D:/Qt/6.6.2/msvc2019_64)")
	endif()
	message(STATUS "QT_SDK_DIR: ${QT_SDK_DIR}")
	list(APPEND CMAKE_PREFIX_PATH ${QT_SDK_DIR})

	find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS #{QT_COMPONENTS})
	find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS #{QT_COMPONENTS})

	if (${QT_VERSION} VERSION_LESS 6.1.0)
		set(BUNDLE_ID_OPTION MACOSX_BUNDLE_GUI_IDENTIFIER com.example.#{MAIN_PROJECT_NAME})
	endif()
endif()

