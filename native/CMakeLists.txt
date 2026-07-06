cmake_minimum_required(VERSION 3.16)
project(hdr_converter VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ── 编译验证模式：仅编译源文件不链接 ──
# 由 build_android.sh / build_ios.sh --compile-only 触发
# 构建脚本负责隔离 FFmpeg 头文件并传入 FFMPEG_INCLUDE_DIR，避免宿主系统头文件与交叉编译器冲突
option(COMPILE_ONLY "Only compile source files, skip linking (for CI cross-platform verification)" OFF)

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

if(COMPILE_ONLY)
    # ── 交叉编译验证：仅编译 .o，不链接 ──
    # 使用构建脚本传入的隔离 FFmpeg 头文件目录，避免宿主系统头文件冲突
    if(NOT DEFINED FFMPEG_INCLUDE_DIR)
        message(FATAL_ERROR "COMPILE_ONLY 模式需要 FFMPEG_INCLUDE_DIR 参数（由 build_android.sh/build_ios.sh 传入）")
    endif()

    add_library(hdr_converter OBJECT ${HDR_CONVERTER_SOURCES})
    target_include_directories(hdr_converter
        PUBLIC include
        PRIVATE src ${FFMPEG_INCLUDE_DIR}
    )
else()
    # ── 本机构建：完整链接 ──
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(AVCODEC REQUIRED IMPORTED_TARGET libavcodec)
    pkg_check_modules(AVFORMAT REQUIRED IMPORTED_TARGET libavformat)
    pkg_check_modules(AVUTIL REQUIRED IMPORTED_TARGET libavutil)
    pkg_check_modules(SWRESAMPLE REQUIRED IMPORTED_TARGET libswresample)
    pkg_check_modules(SWSCALE REQUIRED IMPORTED_TARGET libswscale)

    add_library(hdr_converter SHARED ${HDR_CONVERTER_SOURCES})

    target_include_directories(hdr_converter
        PUBLIC include
        PRIVATE src
    )

    target_link_libraries(hdr_converter
        PkgConfig::AVCODEC
        PkgConfig::AVFORMAT
        PkgConfig::AVUTIL
        PkgConfig::SWRESAMPLE
        PkgConfig::SWSCALE
    )

    if(WIN32)
        set_target_properties(hdr_converter PROPERTIES PREFIX "")
    endif()
endif()
