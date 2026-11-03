cmake_minimum_required(VERSION 3.15)


if(NOT KERNELDIR)
    message(FATAL_ERROR ${KERNELDIR} "KERNELDIR Empty")
endif()

if(NOT ARCH)
    message(FATAL_ERROR ${ARCH} "ARCH Empty")
endif()


if ("${ARCH}" STREQUAL "arm64")
elseif("${ARCH}" STREQUAL "riscv")
else()
    message(FATAL_ERROR ${ARCH} "Empty or Not Supported" )
endif()


string(REGEX MATCH "(.+)-" CROSS_PREFIX ${CMAKE_C_COMPILER})
message(STATUS "build linux kernel modules status:")
message(STATUS "    CROSS_PREFIX=" ${CROSS_PREFIX})
message(STATUS "    ARCH        =" ${ARCH})

find_program(BEAR_FOUND bear)

function(compile_module obj dir)
    message(STATUS "compile_module(" ${obj} " " ${dir} ")")
    set(TARGET_NAME ${obj})
    install(CODE "execute_process(COMMAND make clean CROSS_PREFIX=${CROSS_PREFIX} KERNELDIR=${KERNELDIR} ARCH=${ARCH} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir})")
    if(BEAR_FOUND)
        install(CODE "execute_process(COMMAND bear make CROSS_PREFIX=${CROSS_PREFIX} KERNELDIR=${KERNELDIR} ARCH=${ARCH} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir})")
    else()
        install(CODE "execute_process(COMMAND make CROSS_PREFIX=${CROSS_PREFIX} KERNELDIR=${KERNELDIR} ARCH=${ARCH} WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir})")
    endif()
    install(FILES ${dir}/${obj}.ko DESTINATION bin) 
endfunction()


# add subdirectory 
file(GLOB THE_LIST ./*/Makefile)

foreach(ITEM ${THE_LIST})
    message(STATUS "Find Makefile at " ${ITEM})
    string(REPLACE ${CMAKE_CURRENT_SOURCE_DIR}/./ "" ITEM ${ITEM})
    string(REPLACE "/Makefile" "" ITEM ${ITEM})
    string(REPLACE "_driver" "" NAME ${ITEM})
    compile_module(${NAME} ${ITEM})
endforeach()


