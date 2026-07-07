/* debug_log.h — 跨平台调试日志宏
 * Windows: OutputDebugStringA (用 DebugView 查看)
 * Linux/macOS: fprintf(stderr, ...)
 * Android: __android_log_print (logcat 可见)
 */

#pragma once

#include <cstdio>
#include <cstdarg>
#include <cstring>

#ifdef _WIN32
#include <windows.h>
#define HDR_LOG(fmt, ...) do { \
    char _buf[1024]; \
    snprintf(_buf, sizeof(_buf), "[hdr2sdr] " fmt "\n", ##__VA_ARGS__); \
    OutputDebugStringA(_buf); \
} while(0)
#elif defined(__ANDROID__)
#include <android/log.h>
#define HDR_LOG(fmt, ...) __android_log_print(ANDROID_LOG_INFO, "hdr2sdr-native", "[hdr2sdr] " fmt, ##__VA_ARGS__)
#else
#define HDR_LOG(fmt, ...) do { \
    fprintf(stderr, "[hdr2sdr] " fmt "\n", ##__VA_ARGS__); \
    fflush(stderr); \
} while(0)
#endif
