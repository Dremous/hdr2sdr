# native/toolchain-android.cmake — Android NDK 工具链配置
cmake_minimum_required(VERSION 3.16)

set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 24)

# NDK 路径（从环境变量获取）
set(CMAKE_ANDROID_NDK $ENV{ANDROID_NDK_HOME})

# ABI 架构（由 build_android.sh 传入）
set(CMAKE_ANDROID_ARCH_ABI ${ANDROID_ABI})

# 使用 NDK 的默认工具链
set(CMAKE_ANDROID_STL_TYPE c++_shared)
