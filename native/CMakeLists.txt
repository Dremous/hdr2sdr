cmake_minimum_required(VERSION 3.16)
project(hdr_converter VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ── 编译模式 ──
# COMPILE_ONLY: 仅编译不链接（iOS CI 交叉编译验证用）
# FFMPEG_ROOT:  Android 交叉编译链接模式，指向预编译的 FFmpeg 目录（含 include/ 和 lib/）
option(COMPILE_ONLY "Only compile, skip linking" OFF)

set(HDR_CONVERTER_SOURCES
    src/decoder.cpp
    src/converter.cpp
    src/hdr_analyzer.cpp
    src/tone_mapper.cpp
    src/inverse_tone_mapper.cpp
    src/color_converter.cpp
    src/hdr_metadata_injector.cpp
    src/encoder.cpp
    src/pipeline.cpp
)

# ── FFMPEG_ROOT 模式（Android 交叉编译完整链接） ──
if(DEFINED FFMPEG_ROOT)
    add_library(hdr_converter SHARED ${HDR_CONVERTER_SOURCES})

    target_include_directories(hdr_converter
        PUBLIC include
        PRIVATE src "${FFMPEG_ROOT}/include"
    )

    target_link_directories(hdr_converter PRIVATE "${FFMPEG_ROOT}/lib")

    target_link_libraries(hdr_converter
        avcodec avformat avutil swresample swscale
        log  # Android NDK 日志库（__android_log_print）
    )

# ── COMPILE_ONLY 模式（iOS 交叉编译验证） ──
elseif(COMPILE_ONLY)
    if(NOT DEFINED FFMPEG_INCLUDE_DIR)
        message(FATAL_ERROR "COMPILE_ONLY 模式需要 FFMPEG_INCLUDE_DIR 参数")
    endif()

    add_library(hdr_converter OBJECT ${HDR_CONVERTER_SOURCES})
    target_include_directories(hdr_converter
        PUBLIC include
        PRIVATE src ${FFMPEG_INCLUDE_DIR}
    )

# ── 本机构建（桌面：Linux/macOS/Windows） ──
else()
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
