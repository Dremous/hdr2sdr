#ifndef PIXEL_UTILS_H
#define PIXEL_UTILS_H

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/pixfmt.h>
#include <libswscale/swscale.h>
}

/// 将任意格式的 AVFrame 转换为 GBRPF32 平面格式用于浮点处理
/// 返回一个新分配的 frame，调用者需用 av_frame_free 释放
inline AVFrame* convertToFloatPlanar(AVFrame* src) {
    if (src->format == AV_PIX_FMT_GBRPF32) {
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

    // YUV→RGB 转换使用 BT.709 矩阵（SDR 默认），替代 swscale 默认的 BT.601
    sws_setColorspaceDetails(sws,
        sws_getCoefficients(AVCOL_SPC_BT709), 0,   // 源: BT.709 YUV (MPEG range)
        sws_getCoefficients(AVCOL_SPC_BT709), 1,   // 目标: 全范围 RGB（矩阵忽略）
        0, 1 << 16, 1 << 16);

    sws_scale(sws, src->data, src->linesize, 0, src->height,
              dst->data, dst->linesize);
    sws_freeContext(sws);

    return dst;
}

/// 将 GBRPF32 frame 转换回原始像素格式
/// 直接修改 src 的数据，不分配新 frame
inline int convertFromFloatPlanar(AVFrame* src, AVFrame* float_frame) {
    if (src->format == AV_PIX_FMT_GBRPF32) {
        return 0;
    }

    SwsContext* sws = sws_getContext(
        float_frame->width, float_frame->height, AV_PIX_FMT_GBRPF32,
        src->width, src->height, (AVPixelFormat)src->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);
    if (!sws) return -1;

    // RGB→YUV 转换使用 BT.709 矩阵（SDR 默认），与 convertToFloatPlanar 对称
    sws_setColorspaceDetails(sws,
        sws_getCoefficients(AVCOL_SPC_BT709), 1,   // 源: 全范围 RGB（矩阵忽略）
        sws_getCoefficients(AVCOL_SPC_BT709), 0,   // 目标: BT.709 YUV (MPEG range)
        0, 1 << 16, 1 << 16);

    sws_scale(sws, float_frame->data, float_frame->linesize, 0, float_frame->height,
              src->data, src->linesize);
    sws_freeContext(sws);
    return 0;
}

#endif