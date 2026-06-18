cmake_minimum_required(VERSION 3.30)

project(math
    VERSION 1.0.0
    DESCRIPTION ""
    HOMEPAGE_URL ""
    LANGUAGES C CXX
)

# 1. 文件包含
# 1.1 新增文件、删除文件、重命名文件、移动文件夹等操作，不会刷新，需要重新生成构建系统。
# FILE(GLOB Src *.cpp *.h *.hpp *.ixx)
# FILE(GLOB Module module/*.cpp module/*.h module/*.hpp)
# FILE(GLOB UI
#      "UI/App/*.h"
#      "UI/App/*.cpp"
#      "UI/MVD/*.h"
#      "UI/MVD/*.cpp"
#      "UI/PanelWidgets/*.h"
#      "UI/PanelWidgets/*.cpp"
#      "UI/PanelWidgets/**/*.h"
#      "UI/PanelWidgets/**/*.cpp"
# )

# 1.2 文件分组, 告诉 IDE “在界面上怎么摆放这些文件”, 可选的，只影响开发体验
# source_group(Src FILES ${Src})
# source_group(Module FILES ${Module})
# source_group(UI FILES ${UI})

set(PROJECT_SOURCES
    ${Src}
    ${Module}
    ${UI}
)

# 2. 添加项目 输出模式 add_executable/add_library
if(QT_SUPPORT)
	if (${QT_VERSION_MAJOR} GREATER_EQUAL 6)
        if(NOT "EXE" STREQUAL "EXE")
            add_library(${PROJECT_NAME} EXE ${PROJECT_SOURCES})
        else()
            qt_add_executable(${PROJECT_NAME} MANUAL_FINALIZATION ${PROJECT_SOURCES})
        endif()

        # 收集并添加资源文件（目标已存在）
        file(GLOB_RECURSE RES_PATHS *.png *.jpg *.svg *.ico *.ttf *.webp *.js *.json *.html)
        foreach (filepath ${RES_PATHS})
            string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" filename ${filepath})
            list(APPEND resource_files ${filename})
        endforeach (filepath)

        qt_add_resources(${PROJECT_NAME} "${PROJECT_NAME}"
            RESOURCES PREFIX "/"
            FILES ${resource_files}
        )
    else ()
        if(NOT "EXE" STREQUAL "EXE")
            qt5_add_big_resources(PROJECT_SOURCES ${PROJECT_NAME}.qrc)
            add_library(${PROJECT_NAME} EXE ${PROJECT_SOURCES})
        else()
            qt5_add_big_resources(PROJECT_SOURCES ${PROJECT_NAME}.qrc)
            add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})
        endif()
    endif ()
else ()
	if(NOT "EXE" STREQUAL "STATIC")
		add_library(${PROJECT_NAME} STATIC ${PROJECT_SOURCES})
	else()
		add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})
	endif()
endif ()

# 1.1 自动刷新修改，推荐使用
target_sources(${PROJECT_NAME} PRIVATE
     math.cpp
)
# 2.1 模块依赖 — math 是库，由主目标 MyApp 统一编译 std.ixx
# 这里不 include CxxModules.cmake，避免重复编译 std 模块
include(../cmake/TargetCompilerFlags.cmake)

target_sources(${PROJECT_NAME} PRIVATE
     FILE_SET ${PROJECT_NAME}
     TYPE CXX_MODULES
     BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}"
     FILES "math.cppm"
)

# 3. 包含路径
# target_include_directories(${PROJECT_NAME} PRIVATE
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/UI>
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Module>
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Src>
# )

# 5. 修改或添加目标（target）属性的命令。它的作用是让你在创建目标（如通过 add_executable 或 add_library）之后，单独调整该目标的编译、链接、调试等行为
set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE OFF
    WIN32_EXECUTABLE OFF # ON close console
    LINK_WHAT_YOU_USE ON
	# 仅使用 Visual Studio 生成器时生效，默认Ninja 不生效
    # VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>"
    # VS_DEBUGGER_COMMAND "$<TARGET_FILE:${PROJECT_NAME}>"
)

# qt 用于显式执行针对特定平台（如Android、iOS）的最终收尾任务，例如生成Android部署文件或iOS应用bundle
if(QT_SUPPORT)
	if (QT_VERSION_MAJOR EQUAL 6)
		qt_finalize_executable(${PROJECT_NAME})
	endif ()
endif ()

set(PROJECT_INSTALL_RUNTIME_DIR "${CMAKE_INSTALL_BINDIR}")
set(PROJECT_INSTALL_LIBRARY_DIR "${CMAKE_INSTALL_LIBDIR}")
set(PROJECT_INSTALL_ARCHIVE_DIR "${CMAKE_INSTALL_LIBDIR}")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(PROJECT_INSTALL_RUNTIME_DIR "debug/${CMAKE_INSTALL_BINDIR}")
    set(PROJECT_INSTALL_LIBRARY_DIR "debug/${CMAKE_INSTALL_LIBDIR}")
    set(PROJECT_INSTALL_ARCHIVE_DIR "debug/${CMAKE_INSTALL_LIBDIR}")
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    set(PROJECT_INSTALL_RUNTIME_DIR "relwithdebinfo/${CMAKE_INSTALL_BINDIR}")
    set(PROJECT_INSTALL_LIBRARY_DIR "relwithdebinfo/${CMAKE_INSTALL_LIBDIR}")
    set(PROJECT_INSTALL_ARCHIVE_DIR "relwithdebinfo/${CMAKE_INSTALL_LIBDIR}")
endif()

install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION "${PROJECT_INSTALL_RUNTIME_DIR}"
    LIBRARY DESTINATION "${PROJECT_INSTALL_LIBRARY_DIR}"
    ARCHIVE DESTINATION "${PROJECT_INSTALL_ARCHIVE_DIR}"
)

if(NOT "EXE" STREQUAL "EXE")
    install(
        DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}"
        FILES_MATCHING
            PATTERN "*.h"
            PATTERN "*.hpp"
            PATTERN "*.ixx"
            PATTERN "*.cppm"
    )
endif()

# 6. 给当前项目添加依赖/源文件，如自定义工具，代码生成器等，在项目执行之前构建好，本项目依赖于它，必须最后撰写
# 6.1 示例1-依赖 自己撰写代码生成器可执行文件执行生成代码文件到 本项目的UI文件夹下
# 资源生成工具：编译并运行，生成 ArtisticLetteringPixels.h / Contours.h
# set(ARTISTIC_LETTERING_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/UI/App")
# 
# add_executable(GenerateAssets
#     Tools/GenerateAssets.cpp
# )
# target_include_directories(GenerateAssets PRIVATE
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/UI>
# )
# target_compile_definitions(GenerateAssets PRIVATE
#     PROJECT_DIRECTORY="${CMAKE_CURRENT_SOURCE_DIR}"
#     PROJECT_OUTPUT_DIR="${ARTISTIC_LETTERING_OUTPUT_DIR}"
# )
# if(MSVC)
#     target_compile_options(GenerateAssets PRIVATE
#         "/wd4819"
#     )
# 
#     # 关闭 /showIncludes
#     string(REPLACE "/showIncludes" "" CMAKE_DEPFILE_FLAGS_C "${CMAKE_DEPFILE_FLAGS_C}")
#     string(REPLACE "/showIncludes" "" CMAKE_DEPFILE_FLAGS_CXX "${CMAKE_DEPFILE_FLAGS_CXX}")
# endif()
# target_link_libraries(GenerateAssets PRIVATE
#     Qt::Core
#     Qt::Gui
# )
# 
# # 主项目构建前自动运行 GenerateAssets
# add_custom_target(RunGenerateAssets ALL
#     COMMAND GenerateAssets
#     DEPENDS GenerateAssets
#     COMMENT "▶ Generating ArtisticLettering assets (Pixels.h + Contours.h)..."
# )
# add_dependencies(${PROJECT_NAME} RunGenerateAssets)

# 6.2 示例2-源文件，使用python 执行命令将proto输出h/cpp 文件 作为源文件包含到本项目
# set(PROTO_GEN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/IPC/Generated")
# set(PROTO_FILE "${CMAKE_SOURCE_DIR}/Protocols/IPC.proto")
# set(PROTO_SCRIPT "${CMAKE_SOURCE_DIR}/Script/generate_proto.py")
# 
# find_package(Python3 REQUIRED)
# 
# add_custom_command(
#     OUTPUT
#         ${PROTO_GEN_DIR}/IPC.pb.h
#         ${PROTO_GEN_DIR}/IPC.pb.cc
#         ${PROTO_GEN_DIR}/IPC.grpc.pb.h
#         ${PROTO_GEN_DIR}/IPC.grpc.pb.cc
#     COMMAND Python3::Interpreter ${PROTO_SCRIPT}
#     DEPENDS ${PROTO_FILE}
#     COMMENT "▶ Generating protobuf/gRPC C++ code from IPC.proto ..."
# )
# 
# target_sources(${PROJECT_NAME} PRIVATE
#     ${PROTO_GEN_DIR}/IPC.pb.cc
#     ${PROTO_GEN_DIR}/IPC.grpc.pb.cc
# )
