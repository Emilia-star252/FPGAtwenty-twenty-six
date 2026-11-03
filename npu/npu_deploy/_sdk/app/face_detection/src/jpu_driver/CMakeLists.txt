cmake_minimum_required(VERSION 3.15)
if("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
    file(GLOB RESOURCE
        helper/src/*.c
        jdi/src/*.c
        jdi/linux/*.c
        jpuapi/src/*.c
        wrapper/*.c
        src/*.c
    )
else()
    file(GLOB RESOURCE
        helper/src/*.c
        jdi/src/*.c
        jdi/nonos/*.c
        jpuapi/src/*.c
        src/*.c
    )
endif()

add_library(jpu_driver STATIC ${RESOURCE})

target_include_directories(jpu_driver PRIVATE

)

target_include_directories(jpu_driver PUBLIC
    helper/inc
    jdi/inc
    jpuapi/inc
    inc
    wrapper
)

if (NOT("${CMAKE_BUILD_TYPE}" STREQUAL "Debug"))
    target_compile_options(jpu_driver PRIVATE -O1)
endif()
