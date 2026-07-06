cmake_minimum_required(VERSION 3.16)
project(hdr_converter VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ── 编译验证模式：仅编译源文件不链接（CI 中用宿主 FFmpeg 头文件 + NDK 交叉编译器） ──
option(COMPILE_ONLY "Only compile source files, skip linking (for CI cross-platform verification)" OFF)

find_package(PkgConfig REQUIRED)
pkg_check_modules(AVCODEC REQUIRED libavcodec)
pkg_check_modules(AVFORMAT REQUIRED libavformat)
pkg_check_modules(AVUTIL REQUIRED libavutil)
pkg_check_modules(SWRESAMPLE REQUIRED libswresample)
pkg_check_modules(SWSCALE REQUIRED libswscale)

set(HDR_CONVERTER_SOURCES
    src/decoder.cpp
    src/hdr_analyzer.cpp
    src/tone_mapper.cpp
    src/inverse_tone_mapper.cpp
    src/color_converter.cpp
    src/hdr_metadata_injector.cpp
    src/encoder.cpp
    src/pipeline.cpp
)

# 编译模式：OBJECT 库（不链接）仅验证代码正确性
if(COMPILE_ONLY)
    add_library(hdr_converter OBJECT ${HDR_CONVERTER_SOURCES})
else()
    add_library(hdr_converter SHARED ${HDR_CONVERTER_SOURCES})
endif()

target_include_directories(hdr_converter
    PUBLIC include
    PRIVATE src
    ${AVCODEC_INCLUDE_DIRS}
    ${AVFORMAT_INCLUDE_DIRS}
    ${AVUTIL_INCLUDE_DIRS}
    ${SWRESAMPLE_INCLUDE_DIRS}
    ${SWSCALE_INCLUDE_DIRS}
)

if(NOT COMPILE_ONLY)
    target_link_directories(hdr_converter PRIVATE
        ${AVCODEC_LIBRARY_DIRS}
        ${AVFORMAT_LIBRARY_DIRS}
        ${AVUTIL_LIBRARY_DIRS}
        ${SWRESAMPLE_LIBRARY_DIRS}
        ${SWSCALE_LIBRARY_DIRS}
    )

    target_link_libraries(hdr_converter
        ${AVCODEC_LIBRARIES}
        ${AVFORMAT_LIBRARIES}
        ${AVUTIL_LIBRARIES}
        ${SWRESAMPLE_LIBRARIES}
        ${SWSCALE_LIBRARIES}
    )

    if(WIN32)
        set_target_properties(hdr_converter PROPERTIES PREFIX "")
    endif()
endif()
