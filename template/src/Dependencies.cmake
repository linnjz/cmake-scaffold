# 子项目依赖入口，由 src/CMakeLists.txt 以 include() 引入。
# 默认不引入任何依赖；按需取消注释。此文件只提供配方，不包含活动逻辑。

# ---------------------------------------------------------------------------
# 1. vcpkg 包
# ---------------------------------------------------------------------------
# 前提：根 CMakeLists.txt 已 include(Vcpkg)。
# FindVcpkgPackage(grpc     LINKAGE DYNAMIC REQUIRED CONFIG)
# FindVcpkgPackage(protobuf LINKAGE STATIC  REQUIRED CONFIG)
# FindVcpkgPackage(cryptopp LINKAGE DYNAMIC REQUIRED CONFIG)
#
# 静态 triplet 跟随 MSVC_RUNTIME_MODE：
#   MD → <arch>-windows-static-md，MT → <arch>-windows-static。

# ---------------------------------------------------------------------------
# 2. 系统包 / Config 包
# ---------------------------------------------------------------------------
# find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Network)
# find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Network)
# find_library(LZO_LIB NAMES lzo2 lzo REQUIRED)

# ---------------------------------------------------------------------------
# 3. 手工预编译库
# ---------------------------------------------------------------------------
# 见 cmake/PrebuiltLibraries.cmake：scaffold_add_prebuilt_library() 创建
# IMPORTED GLOBAL 目标，子目录同样可见。
# include(PrebuiltLibraries)

# ---------------------------------------------------------------------------
# 4. 链接
# ---------------------------------------------------------------------------
# target_link_libraries(${PROJECT_NAME} PRIVATE
#     Qt${QT_VERSION_MAJOR}::Network
#     gRPC::grpc++
#     protobuf::libprotobuf
#     cryptopp::cryptopp
# )
#
# if(LZO_LIB)
#     target_link_libraries(${PROJECT_NAME} PRIVATE ${LZO_LIB})
# endif()
#
# if(WIN32)
#     target_link_libraries(${PROJECT_NAME} PRIVATE
#         rpcrt4
#         usp10
#         dwrite
#     )
# endif()

# ---------------------------------------------------------------------------
# 5. 运行时 DLL 拷贝
# ---------------------------------------------------------------------------
# 5.1 vcpkg 动态库：第 4 个参数是 Debug 目录（省略时与 Release 相同）。
# set(DYNAMIC_LINK_LIBRARY_LIST
#     "grpc*"
#     "cryptopp*"
# )
# CopyTargetDependentLibs(${PROJECT_NAME} "${DYNAMIC_LINK_LIBRARY_LIST}"
#     "${VCPKG_DYNAMIC_BIN_PATH}" "${VCPKG_DYNAMIC_DEBUG_BIN_PATH}")
#
# 5.2 手工预编译库
# add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
#     COMMAND ${CMAKE_COMMAND} -E copy_if_different
#         "$<TARGET_FILE:ExampleLib>"
#         $<TARGET_FILE_DIR:${PROJECT_NAME}>
#     COMMENT "Copying ExampleLib DLL to executable directory..."
# )

# ---------------------------------------------------------------------------
# 6. 编译定义 / 三方库宏
# ---------------------------------------------------------------------------
# target_compile_definitions(${PROJECT_NAME} PRIVATE
#     CRYPTOPP_ENABLE_NAMESPACE_WEAK=1
#     PROJECT_DIRECTORY="${CMAKE_CURRENT_SOURCE_DIR}"
# )

# ---------------------------------------------------------------------------
# 7. 已知问题：protobuf 动态/静态 triplet 头文件冲突
# ---------------------------------------------------------------------------
# 前提：根 CMakeLists.txt 已 include(Vcpkg)，且动态与静态 triplet 都已安装。
# vcpkg 先加入动态 triplet 的 SYSTEM include；其中的 port_def.inc 定义
# PROTOBUF_USE_DLLS，使类型带 __declspec(dllimport)，而链接使用静态库 →
# LNK2019。把静态 include 目录以普通 -I 提前（全局或仅当前目标）：
#
# include_directories(${VCPKG_STATIC_INCLUDE_PATH})
# include_directories(SYSTEM ${VCPKG_DYNAMIC_INCLUDE_PATH})
#
# 或只影响当前目标：
# get_target_property(_protobuf_include protobuf::libprotobuf INTERFACE_INCLUDE_DIRECTORIES)
# target_include_directories(${PROJECT_NAME} BEFORE PRIVATE ${_protobuf_include})

# ---------------------------------------------------------------------------
# 8. protobuf / gRPC 代码生成（cmake/ProtoGen.cmake，根 CMakeLists.txt 已 include）
# ---------------------------------------------------------------------------
# 工具查找顺序：函数参数 > SCAFFOLD_* 缓存变量 > protobuf::protoc 导入目标 >
# <VCPKG_ROOT>/installed/*/tools/{protobuf,grpc} > PATH。
# 生成目录默认 ${CMAKE_BINARY_DIR}/generated/proto/{cpp,csharp,java,python}。
#
# 8.1 C++：生成 .pb.cc/.pb.h（GRPC 时另有 .grpc.pb.cc/.pb.h），并把源文件与
#     include 目录挂到当前目标（<name>_SOURCES / <name>_INCLUDE_DIRS 也可手动取用）。
# scaffold_protobuf_generate(echo_proto
#     PROTO_FILES "${CMAKE_CURRENT_SOURCE_DIR}/proto/echo.proto"
#     LANGUAGES CPP
#     GRPC
#     TARGET ${PROJECT_NAME}
# )
# target_link_libraries(${PROJECT_NAME} PRIVATE protobuf::libprotobuf gRPC::grpc++)
#
# 8.2 C# / Java / Python：只生成文件供外部工程引用；<name>_OUTPUT_DIR 给出根目录。
#     构建触发：cmake --build --build ... --target <name>（或被依赖的 C++ 目标带动）。
#     Java 的 gRPC 插件（protoc-gen-grpc-java）需单独下载，Java 无 GRPC 时仅需 protoc。
# scaffold_protobuf_generate(frontend_api
#     PROTO_FILES "${CMAKE_CURRENT_SOURCE_DIR}/proto/echo.proto"
#     LANGUAGES CSHARP JAVA
#     GRPC
# )
