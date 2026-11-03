cmake_minimum_required(VERSION 3.16)
project(dcdc_npu_demo CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Armnn_DIR 指向官方 SDK 的 armnn_lib 目录，例如
#   <sdk>/app/face_detection/libs/armnn_lib
# 该目录下应有 include/ 与 lib/（libarmnn.so.32 等）
if(NOT Armnn_DIR AND DEFINED ENV{ARMNN_DIR})
    set(Armnn_DIR $ENV{ARMNN_DIR})
endif()
if(NOT Armnn_DIR)
    message(FATAL_ERROR "请用 -DArmnn_DIR=<sdk>/libs/armnn_lib 指定 armnn 安装目录")
endif()

message(STATUS "Armnn_DIR = ${Armnn_DIR}")
include_directories(${Armnn_DIR}/include ${CMAKE_CURRENT_SOURCE_DIR})
link_directories(${Armnn_DIR}/lib)

add_executable(dcdc_npu_demo dcdc_npu_demo.cpp)
# 与官方 npu_flow/CMakeLists.txt 用的是同一组链接库
target_link_libraries(dcdc_npu_demo armnn armnnUtils armnnOnnxParser protobuf fmt
                      gcc c m pthread atomic dl)

option(DCDC_USE_WEIGHTS "编译 C 权重头直搭网络模式（--weights）" OFF)
if(DCDC_USE_WEIGHTS)
    target_compile_definitions(dcdc_npu_demo PRIVATE DCDC_USE_WEIGHTS_HEADER)
endif()

install(TARGETS dcdc_npu_demo RUNTIME DESTINATION bin)
