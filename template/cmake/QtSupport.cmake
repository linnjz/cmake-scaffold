# Qt framework support. The root CMakeLists.txt includes this file; find_package()
# must run before any target is created, which is why it is included right after
# the platform/compiler setup.

include_guard(GLOBAL)

option(QT_SUPPORT "Enable Qt framework support" #{QT_SUPPORT_DEFAULT})
if(NOT QT_SUPPORT)
    return()
endif()

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Qt SDK path (set via qt.sdk_dir in project.toml); empty by default so
# system-visible Qt installs are found without project-specific paths.
if(NOT QT_SDK_DIR)
    set(QT_SDK_DIR "#{QT_SDK_DIR}" CACHE PATH "Path to Qt SDK (e.g. D:/Qt/6.6.2/msvc2019_64); empty = search the default Qt paths")
endif()
message(STATUS "QT_SDK_DIR: ${QT_SDK_DIR}")
list(APPEND CMAKE_PREFIX_PATH ${QT_SDK_DIR})

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS #{QT_COMPONENTS})
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS #{QT_COMPONENTS})
