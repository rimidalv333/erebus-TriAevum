# Included after the top-level project() call (CMAKE_PROJECT_INCLUDE). Makes the
# executable's link the PS5 kit's: RADV, the platform layer, the CRT, the fake SELF.
if(NOT CMAKE_PARENT_LIST_FILE STREQUAL "${CMAKE_SOURCE_DIR}/CMakeLists.txt")
    return()
endif()
foreach(required PS5_KIT PS5_DEPS_PREFIX TRIAEVUM_LICENSE_FILE)
    if(NOT ${required})
        message(FATAL_ERROR "project-include.cmake: ${required} is not set")
    endif()
endforeach()
get_filename_component(_ps5_dir "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
# Every object and archive CMake would hand the linker goes to the kit's recipe;
# the platform layer is linked whole and first (its start-up constructor has no caller),
# and the Vulkan loader shim (RADV exports only vk_icdGetInstanceProcAddr) beside it.
set(CMAKE_CXX_LINK_EXECUTABLE
    "env TRIAEVUM_LICENSE=${TRIAEVUM_LICENSE_FILE} bash ${_ps5_dir}/tools/link-title.sh ${CMAKE_BINARY_DIR} ${PS5_KIT}/vulkan ${PS5_KIT}/sdk --whole-archive ${PS5_DEPS_PREFIX}/lib/libps5_platform.a --no-whole-archive <OBJECTS> <LINK_LIBRARIES>")
