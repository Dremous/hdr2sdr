cmake_minimum_required(VERSION 3.16)
project(hdr_converter VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ── 编译验证模式：仅编译源文件不链接（CI 中用宿主 FFmpeg 头文件 + NDK 交叉编译器） ──
option(COMPILE_ONLY "Only compile source files, skip linking (for CI cross-platform verification)" OFF)

find_package(PkgConfig REQUIRED)

# IMPORTED_TARGET: 自动处理 include 路径、库路径、链接标志，跨平台最可靠
pkg_check_modules(AVCODEC REQUIRED IMPORTED_TARGET libavcodec)
pkg_check_modules(AVFORMAT REQUIRED IMPORTED_TARGET libavformat)
pkg_check_modules(AVUTIL REQUIRED IMPORTED_TARGET libavutil)
pkg_check_modules(SWRESAMPLE REQUIRED IMPORTED_TARGET libswresample)
pkg_check_modules(SWSCALE REQUIRED IMPORTED_TARGET libswscale)

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

# OBJECT 库：仅编译 .o 文件不链接（COMPILE_ONLY 模式用，CI 交叉编译验证）
if(COMPILE_ONLY)
    add_library(hdr_converter OBJECT ${HDR_CONVERTER_SOURCES})
else()
    add_library(hdr_converter SHARED ${HDR_CONVERTER_SOURCES})
endif()

# 项目自身头文件
target_include_directories(hdr_converter
    PUBLIC include
    PRIVATE src
)

# IMPORTED_TARGET 自动提供 FFmpeg 的 include 路径 + 链接库
target_link_libraries(hdr_converter
    PkgConfig::AVCODEC
    PkgConfig::AVFORMAT
    PkgConfig::AVUTIL
    PkgConfig::SWRESAMPLE
    PkgConfig::SWSCALE
)

# 仅完整链接模式：平台特定设置
if(NOT COMPILE_ONLY)
    if(WIN32)
        set_target_properties(hdr_converter PROPERTIES PREFIX "")
    endif()
endif()
