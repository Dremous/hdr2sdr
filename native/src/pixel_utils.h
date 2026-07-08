#ifndef PIXEL_UTILS_H
#define PIXEL_UTILS_H

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/pixfmt.h>
#include <libswscale/swscale.h>
}

/// 将任意格式的 AVFrame 转换为 GBRPF32 平面格式用于浮点处理
/// src_colorspace: 源视频的色彩空间矩阵（默认 BT.709，HDR 内容应传 AVCOL_SPC_BT2020_NCL）
/// 返回一个新分配的 frame，调用者需用 av_frame_free 释放
inline AVFrame* convertToFloatPlanar(AVFrame* src,
    int src_colorspace = AVCOL_SPC_BT709) {
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

    // YUV→RGB 转换使用源视频的矩阵系数（BT.709 或 BT.2020），替代 swscale 默认的 BT.601
    sws_setColorspaceDetails(sws,
        sws_getCoefficients(src_colorspace), 0,   // 源: YUV (MPEG range)
        sws_getCoefficients(src_colorspace), 1,   // 目标: 全范围 RGB（矩阵忽略仅作标识）
        0, 1 << 16, 1 << 16);

    sws_scale(sws, src->data, src->linesize, 0, src->height,
              dst->data, dst->linesize);
    sws_freeContext(sws);

    return dst;
}

/// 将 GBRPF32 frame 转换回原始像素格式
/// dst_colorspace: 目标视频的色彩空间矩阵（默认 BT.709，HDR 内容应传 AVCOL_SPC_BT2020_NCL）
/// 直接修改 src 的数据，不分配新 frame
inline int convertFromFloatPlanar(AVFrame* src, AVFrame* float_frame,
    int dst_colorspace = AVCOL_SPC_BT709) {
    if (src->format == AV_PIX_FMT_GBRPF32) {
        return 0;
    }

    SwsContext* sws = sws_getContext(
        float_frame->width, float_frame->height, AV_PIX_FMT_GBRPF32,
        src->width, src->height, (AVPixelFormat)src->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);
    if (!sws) return -1;

    // RGB→YUV 转换使用目标视频的矩阵系数，与 convertToFloatPlanar 对称
    sws_setColorspaceDetails(sws,
        sws_getCoefficients(dst_colorspace), 1,   // 源: 全范围 RGB（矩阵忽略）
        sws_getCoefficients(dst_colorspace), 0,   // 目标: YUV (MPEG range)
        0, 1 << 16, 1 << 16);

    sws_scale(sws, float_frame->data, float_frame->linesize, 0, float_frame->height,
              src->data, src->linesize);
    sws_freeContext(sws);
    return 0;
}

#endif