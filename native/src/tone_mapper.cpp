#include "tone_mapper.h"
#include "pixel_utils.h"
#include "gamut_mapper.h"
#include <cmath>
#include <cstring>

ToneMapper::ToneMapper() : algorithm_(0) {}

void ToneMapper::setAlgorithm(int algo) {
    algorithm_ = algo;
}

void ToneMapper::apply(AVFrame* frame, const ToneMapParams& params,
                       int src_colorspace, int dst_colorspace, int gamut_dir) {
    if (!frame) return;

    // YUV→GBRPF32（使用源视频矩阵系数）
    AVFrame* float_frame = convertToFloatPlanar(frame, src_colorspace);
    if (!float_frame) return;

    // BT.2390 色调映射
    applyBt2390(float_frame, params, true);  // HDR 输入为 BT.2020 原色

    // 色域转换（浮点域 primaries 矩阵映射）
    if (gamut_dir == 1)       gamutConvert2020To709(float_frame);
    else if (gamut_dir == 2)  gamutConvert709To2020(float_frame);

    // GBRPF32→YUV（使用目标视频矩阵系数，色域转换后为 BT.709）
    convertFromFloatPlanar(frame, float_frame, dst_colorspace);
    av_frame_free(&float_frame);
}

void ToneMapper::applyOnFloat(AVFrame* float_frame, const ToneMapParams& params,
                               bool is_bt2020) {
    applyBt2390(float_frame, params, is_bt2020);
}

void ToneMapper::applyBt2390(AVFrame* frame, const ToneMapParams& params,
                             bool is_bt2020) {
    int width = frame->width;
    int height = frame->height;
    float peak = params.peak_luminance > 0 ? params.peak_luminance : 1000.0f;
    float ev = powf(2.0f, params.exposure);
    float sat = params.saturation;
    // 根据输入原色选择亮度系数（BT.2020 或 BT.709）
    const float kr = is_bt2020 ? 0.2627f : 0.2126f;
    const float kg = is_bt2020 ? 0.6780f : 0.7152f;
    const float kb = is_bt2020 ? 0.0593f : 0.0722f;

    // GBRPF32 格式：data[0]=R, data[1]=G, data[2]=B, 每像素 float
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
            float* g = (float*)(frame->data[1] + y * frame->linesize[1]) + x;
            float* b = (float*)(frame->data[2] + y * frame->linesize[2]) + x;

            float rv = *r * ev;
            float gv = *g * ev;
            float bv = *b * ev;

            // BT.2390 tone mapping curve
            float max_rgb = fmaxf(rv, fmaxf(gv, bv));
            if (max_rgb > 0.0f) {
                float mapped = (max_rgb * (1.0f + max_rgb / peak)) /
                               (1.0f + max_rgb);
                float scale = mapped / max_rgb;
                *r = rv * scale;
                *g = gv * scale;
                *b = bv * scale;
            }

            // 饱和度调整（BT.2020 亮度系数）
            float lum = kr * (*r) + kg * (*g) + kb * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}