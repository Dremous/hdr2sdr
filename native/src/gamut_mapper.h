#ifndef GAMUT_MAPPER_H
#define GAMUT_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
}
#include <cmath>
#include <cstdio>

/// 输出 GBRPF32 浮点帧各通道 min/max/avg（仅首帧，避免日志洪水）
inline void debugFloatFrameStats(const char* label, AVFrame* frame, int frame_idx = 0) {
    if (!frame || frame->format != AV_PIX_FMT_GBRPF32 || frame_idx > 0) return;

    float rMin=1e9f, rMax=-1e9f, gMin=1e9f, gMax=-1e9f, bMin=1e9f, bMax=-1e9f;
    double rSum=0, gSum=0, bSum=0;
    int n = frame->width * frame->height;
    for (int y = 0; y < frame->height; ++y) {
        for (int x = 0; x < frame->width; ++x) {
            float r = *((float*)(frame->data[0] + y*1LL*frame->linesize[0]) + x);
            float g = *((float*)(frame->data[1] + y*1LL*frame->linesize[1]) + x);
            float b = *((float*)(frame->data[2] + y*1LL*frame->linesize[2]) + x);
            if (r < rMin) rMin = r; if (r > rMax) rMax = r;
            if (g < gMin) gMin = g; if (g > gMax) gMax = g;
            if (b < bMin) bMin = b; if (b > bMax) bMax = b;
            rSum += r; gSum += g; bSum += b;
        }
    }
    fprintf(stderr, "[hdr2sdr] %s %dx%d | R[%.4f~%.4f avg=%.4f] G[%.4f~%.4f avg=%.4f] B[%.4f~%.4f avg=%.4f]\n",
        label, frame->width, frame->height,
        rMin, rMax, rSum/n, gMin, gMax, gSum/n, bMin, bMax, bSum/n);
    fflush(stderr);
}

/// BT.709 → BT.2020 色域扩展矩阵（通过 XYZ D65 白点）
/// 在 GBRPF32 浮点帧上逐像素应用 3×3 primaries 转换
/// 仅裁剪负值（防止上游饱和度过高导致的非法值），HDR 可 >1 不设上限
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
            float rr = 0.6274f * ri + 0.3293f * gi + 0.0433f * bi;
            float gg = 0.0691f * ri + 0.9195f * gi + 0.0114f * bi;
            float bb = 0.0164f * ri + 0.0880f * gi + 0.8956f * bi;

            *r = rr < 0.0f ? 0.0f : rr; // BT.709⊂BT.2020，不应有负值，但防御上游非法值
            *g = gg < 0.0f ? 0.0f : gg;
            *b = bb < 0.0f ? 0.0f : bb;
        }
    }
}

/// BT.2020 → BT.709 色域压缩矩阵（D65 白点）
/// 在 GBRPF32 浮点帧上逐像素应用逆 3×3 primaries 转换
/// 窄色域值会超出 [0,1]（负值或 >1），需裁剪到有效范围
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
            float rr =  1.6605f * ri - 0.5876f * gi - 0.0729f * bi;
            float gg = -0.1245f * ri + 1.1329f * gi - 0.0084f * bi;
            float bb = -0.0182f * ri - 0.1006f * gi + 1.1187f * bi;

            // 窄色域裁剪：BT.2020 色域 > BT.709，转换后裁剪到 [0,1]
            *r = rr < 0.0f ? 0.0f : (rr > 1.0f ? 1.0f : rr);
            *g = gg < 0.0f ? 0.0f : (gg > 1.0f ? 1.0f : gg);
            *b = bb < 0.0f ? 0.0f : (bb > 1.0f ? 1.0f : bb);
        }
    }
}

#endif
