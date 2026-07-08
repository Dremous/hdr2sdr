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
    float peak_nits = params.peak_luminance > 0 ? (float)params.peak_luminance : 1000.0f;
    float ev = powf(2.0f, (float)params.exposure);
    float sat = (float)params.saturation;

    // swscale PQ→LINEAR 后 1.0=10000nits，但 BT.2390 公式期望 SDR 空间 (1.0=100nits)
    const float kSdrWhite = 100.0f;
    const float kPQPeak = 10000.0f;
    float pq_to_sdr = kSdrWhite / kPQPeak;   // 0.01: PQ-rel → SDR-rel
    float peak_sdr = peak_nits / kSdrWhite;  // 相对峰值，BT.2390 公式单位

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

            // 1) PQ-relative → SDR-relative（÷100）
            float rv_sdr = rv * pq_to_sdr;
            float gv_sdr = gv * pq_to_sdr;
            float bv_sdr = bv * pq_to_sdr;

            // 2) BT.2390 色调映射（在 SDR-relative 空间）
            float max_rgb = fmaxf(rv_sdr, fmaxf(gv_sdr, bv_sdr));
            if (max_rgb > 0.0f) {
                float mapped = (max_rgb * (1.0f + max_rgb / peak_sdr)) /
                               (1.0f + max_rgb);
                float scale = mapped / max_rgb;
                *r = rv_sdr * scale;
                *g = gv_sdr * scale;
                *b = bv_sdr * scale;
            }

            // 3) 饱和度调整（SDR-relative 空间）
            float lum = kr * (*r) + kg * (*g) + kb * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}