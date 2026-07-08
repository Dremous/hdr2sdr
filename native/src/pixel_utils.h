#ifndef PIXEL_UTILS_H
#define PIXEL_UTILS_H

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/pixfmt.h>
#include <libswscale/swscale.h>
}

/// 辅助：根据 YCbCr 矩阵系数推断输入 TRC（仅当解码器未设时使用）
inline AVColorTransferCharacteristic inferColorTrc(int colorspace) {
    return (colorspace == AVCOL_SPC_BT2020_NCL || colorspace == AVCOL_SPC_BT2020_CL)
        ? AVCOL_TRC_SMPTE2084    // BT.2020 → 假定 PQ（HDR）
        : AVCOL_TRC_BT709;       // 其他 → 假定 BT.709 gamma（SDR）
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

    // 设置目标帧 TRC：sws_scale_frame 据此做逆 TRC 转换输出线性值
    dst->color_trc = AVCOL_TRC_LINEAR;
    // 如果解码器未设源 TRC，根据矩阵系数推断
    if (src->color_trc <= AVCOL_TRC_UNSPECIFIED) {
        src->color_trc = inferColorTrc(src_colorspace);
    }

    // YUV→RGB 转换使用源视频的矩阵系数（BT.709 或 BT.2020）
    sws_setColorspaceDetails(sws,
        sws_getCoefficients(src_colorspace), 0,   // 源: YUV (MPEG range)
        sws_getCoefficients(src_colorspace), 1,   // 目标: 全范围 RGB
        0, 1 << 16, 1 << 16);

    // sws_scale_frame 读取帧级 color_trc，自动处理 TRC 转换
    sws_scale_frame(sws, dst, src);
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

    // 源（GBRPF32）是线性全范围值
    float_frame->color_trc = AVCOL_TRC_LINEAR;
    float_frame->color_range = AVCOL_RANGE_JPEG;
    // 目标使用原始帧已有的 TRC 和 range（解码器已设或 convertToFloatPlanar 已推断）
    if (src->color_trc <= AVCOL_TRC_UNSPECIFIED) {
        src->color_trc = inferColorTrc(dst_colorspace);
    }

    // RGB→YUV 转换使用目标视频的矩阵系数
    sws_setColorspaceDetails(sws,
        sws_getCoefficients(dst_colorspace), 1,   // 源: 全范围 RGB
        sws_getCoefficients(dst_colorspace), 0,   // 目标: YUV (MPEG range)
        0, 1 << 16, 1 << 16);

    sws_scale_frame(sws, src, float_frame);
    sws_freeContext(sws);
    return 0;
}

#endif