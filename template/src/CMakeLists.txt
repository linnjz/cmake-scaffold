project(#{SUB_PROJECT_NAME}
    VERSION #{SUB_PROJECT_VERSION}
    DESCRIPTION "#{SUB_PROJECT_DESCRIPTION}"
    HOMEPAGE_URL "#{PROJECT_HOMEPAGE_URL}"
    LANGUAGES #{PROJECT_LANGUAGES}
)

include(ProjectTarget)

set(PROJECT_TARGET_TYPE "#{TARGET_TYPE}")

# 1. 源文件
# generate.py 按目标类型放入入口文件：EXE 为 main.cpp，库为 library.cpp/h。
# 显式源列表便于 review；新增文件后重新运行 CMake 即可（不要依赖 FILE(GLOB)）。
if(PROJECT_TARGET_TYPE STREQUAL "EXE")
    set(PROJECT_SOURCES main.cpp)
else()
    set(PROJECT_SOURCES library.cpp)
endif()

# 目标创建后仍可用 target_sources() 追加（例如按平台拆分实现）：
# target_sources(${PROJECT_NAME} PRIVATE
#     $<$<PLATFORM_ID:Windows>:windows_impl.cpp>
#     $<$<PLATFORM_ID:Linux>:linux_impl.cpp>
# )
# 仅影响 IDE 展示的分组：
# source_group("Sources" FILES ${PROJECT_SOURCES})

# 2. 创建目标（Qt5/6 与可执行文件/库的差异由 ProjectTarget.cmake 统一处理）
scaffold_add_project_target(${PROJECT_NAME}
    TYPE ${PROJECT_TARGET_TYPE}
    SOURCES ${PROJECT_SOURCES}
)

# 2.1 示例模块库（modules/math）：默认不接入构建；需要时在根 CMakeLists.txt
# 添加 add_subdirectory(modules)，再取消下一行注释。
# target_link_libraries(${PROJECT_NAME} PRIVATE math)

# 2.2 标准库模块与编译器选项
if(CMAKE_CXX_STANDARD GREATER_EQUAL 20)
    scaffold_enable_import_std(${PROJECT_NAME})
endif()

include(CompilerOptions)
scaffold_configure_target(${PROJECT_NAME})

# 3. 包含路径
# target_include_directories(${PROJECT_NAME} PRIVATE
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/UI>
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Module>
#     $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Src>
# )

# 4. 三方库依赖（子项目级；根级依赖见根 CMakeLists.txt）
include("${CMAKE_CURRENT_SOURCE_DIR}/Dependencies.cmake")

# 5. 目标属性
# Bundle/控制台属性只对可执行文件有意义；LINK_WHAT_YOU_USE 只对会链接的目标设置。
if(PROJECT_TARGET_TYPE STREQUAL "EXE")
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        MACOSX_BUNDLE #{MACOS_BUNDLE}
        # ON = Windows 上使用窗口子系统（GUI）：不弹出随程序存在的控制台窗口
        WIN32_EXECUTABLE #{WIN32_EXECUTABLE}
    )
endif()
if(NOT PROJECT_TARGET_TYPE STREQUAL "STATIC")
    set_target_properties(${PROJECT_NAME} PROPERTIES LINK_WHAT_YOU_USE ON)
endif()

# Qt6 的可执行目标必须显式 finalize；库目标不会被误传给 qt_finalize_executable。
scaffold_finalize_project_target(${PROJECT_NAME})

# 6. 安装
# Debug/RelWithDebInfo 使用独立目录前缀；库目标同时安装匹配的头文件。
scaffold_install_project_target(${PROJECT_NAME})

# 7. 代码生成示例（按需启用）
# 7.1 依赖自己撰写的代码生成器：编译并运行，产物作为源码/头文件
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
# if(COMPILER_MSVC_LIKE)
#     target_compile_options(GenerateAssets PRIVATE "/wd4819")
#
#     # 不要从 CMAKE_DEPFILE_FLAGS_* 中删除 /showIncludes：它是 Ninja 头文件依赖的来源。
#     # 本地化前缀由 cmake/ShowIncludesPrefix.cmake（CMake < 4.4）或 CMake 4.4 自带机制处理。
# endif()
# target_link_libraries(GenerateAssets PRIVATE
#     Qt::Core
#     Qt::Gui
# )
#
# add_custom_target(RunGenerateAssets ALL
#     COMMAND GenerateAssets
#     DEPENDS GenerateAssets
#     COMMENT "Generating assets..."
# )
# add_dependencies(${PROJECT_NAME} RunGenerateAssets)

# 7.2 使用脚本（如 protoc）生成源码：add_custom_command(OUTPUT ...) 声明产物，
#     再用 target_sources() 加入目标；CONFIGURE_DEPENDS 不可用于这种生成流程。
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
#     COMMENT "Generating protobuf/gRPC code from IPC.proto ..."
# )
#
# target_sources(${PROJECT_NAME} PRIVATE
#     ${PROTO_GEN_DIR}/IPC.pb.cc
#     ${PROTO_GEN_DIR}/IPC.grpc.pb.cc
# )
