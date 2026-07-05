#ifndef UTILS_H
#define UTILS_H

#include <string>
#include <libavutil/error.h>

// 将 FFmpeg 错误码转换为可读字符串
inline std::string avErrorToString(int errnum) {
    char buf[256];
    av_strerror(errnum, buf, sizeof(buf));
    return std::string(buf);
}

#endif