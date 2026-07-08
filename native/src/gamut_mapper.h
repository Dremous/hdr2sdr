#ifndef GAMUT_MAPPER_H
#define GAMUT_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
}

/// BT.709 → BT.2020 色域扩展矩阵（通过 XYZ D65 白点）
/// 在 GBRPF32 浮点帧上逐像素应用 3×3 primaries 转换
inline void gamutConvert709To2020(AVFrame* frame) {
    if (!frame || frame->format != AV_PIX_FMT_GBRPF32) return;

    for (int y = 0; y < frame->height; ++y) {
        for (int x = 0; x < frame->width; ++x) {
            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
            float* g = (float*)(frame->data[1] + y * frame->linesize[1]) + x;
            float* b = (float*)(frame->data[2] + y * frame->linesize[2]) + x;

            float ri = *r, gi = *g, bi = *b;

            // BT.709 primaries → BT.2020 primaries (D65 white)
            // Matrix from ITU-R BT.2087 / colormath.org
            *r = 0.6274f * ri + 0.3293f * gi + 0.0433f * bi;
            *g = 0.0691f * ri + 0.9195f * gi + 0.0114f * bi;
            *b = 0.0164f * ri + 0.0880f * gi + 0.8956f * bi;
        }
    }
}

/// BT.2020 → BT.709 色域压缩矩阵（D65 白点）
/// 在 GBRPF32 浮点帧上逐像素应用逆 3×3 primaries 转换
inline void gamutConvert2020To709(AVFrame* frame) {
    if (!frame || frame->format != AV_PIX_FMT_GBRPF32) return;

    for (int y = 0; y < frame->height; ++y) {
        for (int x = 0; x < frame->width; ++x) {
            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
            float* g = (float*)(frame->data[1] + y * frame->linesize[1]) + x;
            float* b = (float*)(frame->data[2] + y * frame->linesize[2]) + x;

            float ri = *r, gi = *g, bi = *b;

            // BT.2020 primaries → BT.709 primaries (D65 white)
            // Inverse of the 709→2020 matrix above
            *r =  1.6605f * ri - 0.5876f * gi - 0.0729f * bi;
            *g = -0.1245f * ri + 1.1329f * gi - 0.0084f * bi;
            *b = -0.0182f * ri - 0.1006f * gi + 1.1187f * bi;
        }
    }
}

#endif
