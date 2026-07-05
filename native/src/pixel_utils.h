#ifndef PIXEL_UTILS_H
#define PIXEL_UTILS_H

extern "C" {
#include <libavutil/frame.h>
#include <libswscale/swscale.h>
}

/// 将任意格式的 AVFrame 转换为 GBRPF32 平面格式用于浮点处理
/// 返回一个新分配的 frame，调用者需用 av_frame_free 释放
inline AVFrame* convertToFloatPlanar(AVFrame* src) {
    if (src->format == AV_PIX_FMT_GBRPF32) {
        // 已经是 float 平面格式，直接引用
        return av_frame_clone(src);
    }

    AVFrame* dst = av_frame_alloc();
    if (!dst) return nullptr;

    dst->format = AV_PIX_FMT_GBRPF32;
    dst->width = src->width;
    dst->height = src->height;
    if (av_frame_get_buffer(dst, 32) < 0) {
        av_frame_free(&dst);
        return nullptr;
    }

    SwsContext* sws = sws_getContext(
        src->width, src->height, (AVPixelFormat)src->format,
        dst->width, dst->height, AV_PIX_FMT_GBRPF32,
        SWS_BILINEAR, nullptr, nullptr, nullptr);
    if (!sws) {
        av_frame_free(&dst);
        return nullptr;
    }

    sws_scale(sws, src->data, src->linesize, 0, src->height,
              dst->data, dst->linesize);
    sws_freeContext(sws);

    return dst;
}

/// 将 GBRPF32 frame 转换回原始像素格式
/// 直接修改 src 的数据，不分配新 frame
inline int convertFromFloatPlanar(AVFrame* src, AVFrame* float_frame) {
    if (src->format == AV_PIX_FMT_GBRPF32) {
        return 0; // 无需转换
    }

    SwsContext* sws = sws_getContext(
        float_frame->width, float_frame->height, AV_PIX_FMT_GBRPF32,
        src->width, src->height, (AVPixelFormat)src->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);
    if (!sws) return -1;

    sws_scale(sws, float_frame->data, float_frame->linesize, 0, float_frame->height,
              src->data, src->linesize);
    sws_freeContext(sws);
    return 0;
}

#endif