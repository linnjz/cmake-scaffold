# Manual import of third-party libraries
# use: include(GlobalThirdParty.cmake)

include(ExternalProject)

set(NEXUS_INCLUDE_DIR "E:/NexUs/NexUs/Source/include" CACHE PATH "NexUs include directory")
set(NEXUS_CMAKE_BUILD_DIR_DEBUG "E:/NexUs/out/build/debug" CACHE PATH "NexUs CMake build directory (Debug)")
set(NEXUS_CMAKE_BUILD_DIR_RELWITHDEBINFO "E:/NexUs/out/build/relwithdebinfo" CACHE PATH "NexUs CMake build directory (RelWithDebInfo)")
set(NEXUS_BIN_DIR_DEBUG "E:/NexUs/Bin/NexUs_Debug_x64" CACHE PATH "NexUs binary directory (Debug)")
set(NEXUS_BIN_DIR_RELWITHDEBINFO "E:/NexUs/Bin/NexUs_RelWithDebInfo_x64" CACHE PATH "NexUs binary directory (RelWithDebInfo)")
set(NEXUS_BIN_DIR_RELEASE "E:/NexUs/Bin/NexUs_Release_x64" CACHE PATH "NexUs binary directory (Release)")

set(NEXUS_BIN_DIR "$<IF:$<CONFIG:Debug>,${NEXUS_BIN_DIR_DEBUG},${NEXUS_BIN_DIR_RELWITHDEBINFO}>")

if(NOT TARGET NexUs)
    add_library(NexUs SHARED IMPORTED GLOBAL)

    set_target_properties(NexUs PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${NEXUS_INCLUDE_DIR}"

        IMPORTED_LOCATION_DEBUG "${NEXUS_BIN_DIR_DEBUG}/NexUsd.dll"
        IMPORTED_IMPLIB_DEBUG "${NEXUS_BIN_DIR_DEBUG}/NexUsd.lib"

        IMPORTED_LOCATION_RELEASE "${NEXUS_BIN_DIR_RELEASE}/NexUs.dll"
        IMPORTED_IMPLIB_RELEASE "${NEXUS_BIN_DIR_RELEASE}/NexUs.lib"

        IMPORTED_LOCATION_RELWITHDEBINFO "${NEXUS_BIN_DIR_RELWITHDEBINFO}/NexUs.dll"
        IMPORTED_IMPLIB_RELWITHDEBINFO "${NEXUS_BIN_DIR_RELWITHDEBINFO}/NexUs.lib"

        IMPORTED_LOCATION_MINSIZEREL "${NEXUS_BIN_DIR_RELWITHDEBINFO}/NexUs.dll"
        IMPORTED_IMPLIB_MINSIZEREL "${NEXUS_BIN_DIR_RELWITHDEBINFO}/NexUs.lib"
    )
endif()

if(NOT TARGET NexUs::NexUs)
    add_library(NexUs::NexUs ALIAS NexUs)
endif()
