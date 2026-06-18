# 标准框架介绍
# 1. 使用 cmake/Functions.cmake 的 "函数FindVcpkgPackage" 找vcpkg的包, 默认只提供 DYNAMIC动态库 和 STATIC静态库md
# FindVcpkgPackage(grpc LINKAGE DYNAMIC REQUIRED CONFIG)
# FindVcpkgPackage(protobuf LINKAGE STATIC REQUIRED CONFIG)
# FindVcpkgPackage(cryptopp LINKAGE DYNAMIC REQUIRED CONFIG)

# 2. 手动导包/库
# find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Network)
# find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Network)
# find_library(LZO_LIB NAMES lzo2 lzo REQUIRED)
# include(ThirdParty.cmake) # 见cmake/ThirdParty.cmake的编写方式，这里时特定项目的依赖包，区别于根目录CMakeLists.txt的全局依赖包

# 3. 链接库
# target_link_libraries(${PROJECT_NAME} PRIVATE
#     Qt${QT_VERSION_MAJOR}::Network
#     gRPC::grpc++
#     protobuf::libprotobuf
#     cryptopp::cryptopp
# )

# if(LZO_LIB)
#     target_link_libraries(${PROJECT_NAME} PRIVATE ${LZO_LIB})
# endif()

# if (WIN32)
#   target_link_libraries(${PROJECT_NAME} PRIVATE
#       rpcrt4
#       usp10
#       dwrite
#   )
# endif()

# 4. 补丁修复
# 4.1 补丁修复说明
# protobuf 特殊处理：vcpkg 自身的默认 include 路径为 x64-windows（动态库），
# 且该路径在 x64-windows-static-md 的 include 之前被添加到编译命令行（SYSTEM include），
# 导致静态链接模式下（x64-windows-static-md）仍找到了动态 triplet 的 protobuf 头文件。
# 动态 triplet 的 port_def.inc 在第 29-31 行硬编码了 #define PROTOBUF_USE_DLLS，
# 使得 protobuf 所有类型被标记为 __declspec(dllimport)，编译器生成 __imp_ 前缀的符号引用。
# 但链接使用的是静态库 libprotobufd.lib，这些符号不存在于静态库中，导致 LNK2019。
# 修复：将 protobuf target 自身的 include 路径以普通 -I（非 SYSTEM）提前插入，
# 确保 MSVC 在搜索 SYSTEM 路径之前找到静态 triplet 的 protobuf 头文件。
# 或者使用全局的 include_directories() 强制将 protobuf 的 include 路径提前，但这会影响所有 target，可能引入其他问题。
# include_directories(
#     ${VCPKG_STATIC_INCLUDE_PATH}
# )
# include_directories(SYSTEM
#     ${VCPKG_DYNAMIC_INCLUDE_PATH}
# )
# 见cmake/Dependencies.cmake

# 4.2 补丁修复 cmake 配置
# get_target_property(_protobuf_include protobuf::libprotobuf INTERFACE_INCLUDE_DIRECTORIES)
# target_include_directories(${PROJECT_NAME} BEFORE PRIVATE ${_protobuf_include})

# 5. 自定义宏/使用三方库宏配置
# target_compile_definitions(${PROJECT_NAME} PRIVATE
#   -DCRYPTOPP_ENABLE_NAMESPACE_WEAK=1 # 三方库宏配置
#   -DPROJECT_DIRECTORY="${CMAKE_CURRENT_SOURCE_DIR}" # 自定义宏配置
#   -DLINN_PROPERTY_ENABLE_SHORT_MACROS
#   -DLINN_SINGLETON_ENABLE_SHORT_MACROS
# )

# 6. dll拷贝
# 6.1 使用 cmake/Functions.cmake 的 "函数CopyTargetDependentLibs" 将dll拷贝到项目生成目录下, *是通配符，自动处理debug、release等构建模式不同后缀
# set(DYNAMIC_LINK_LIBRARY_LIST 
# 	"grpc*"
# 	"cryptopp*"
# )
# 
# VCPKG动态库的设置配置见 cmake/VcpkgSetup.cmake
# CopyTargetDependentLibs(${PROJECT_NAME} "${DYNAMIC_LINK_LIBRARY_LIST}" ${VCPKG_DYNAMIC_BIN_PATH} ${VCPKG_DYNAMIC_DEBUG_BIN_PATH})

# 6.2 使用 custom_command 命令拷贝（见cmake/ThirdParty.cmake 全局/特定三方库，由根/子目录CMakeLists.txt导入时，子项目需要处理dll拷贝）
# add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
#     COMMAND ${CMAKE_COMMAND} -E copy_if_different
#         "$<TARGET_FILE:NexUs>"
#         $<TARGET_FILE_DIR:${PROJECT_NAME}>
#     COMMENT "Copying NexUs DLL to executable directory..."
# )
