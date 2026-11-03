cmake_minimum_required(VERSION 3.15)
# project settings
project(LinuxRuntime C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_compile_options(-Wall)

link_libraries(gcc c m pthread atomic dl) 

add_subdirectory(jpu_driver)


# add executable
option(BUILD_APPS "build apps" ON) 
if(BUILD_APPS)
    add_subdirectory(npu_flow)
endif()

option(BUILD_MODULES "build linux kernel modules" OFF) 
if(BUILD_MODULES)
    add_subdirectory(linux_driver)
endif()


find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
    message(STATUS "ccache found")
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
    # set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif(CCACHE_FOUND)