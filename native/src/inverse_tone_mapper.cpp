#include "inverse_tone_mapper.h"
#include "pixel_utils.h"
#include <cmath>

InverseToneMapper::InverseToneMapper() {}

void InverseToneMapper::apply(AVFrame* frame, const InvToneMapParams& params) {
    if (!frame) return;

    AVFrame* float_frame = convertToFloatPlanar(frame);
    if (!float_frame) return;

    applyExpansion(float_frame, params);

    convertFromFloatPlanar(frame, float_frame);
    av_frame_free(&float_frame);
}

void InverseToneMapper::applyOnFloat(AVFrame* float_frame, const InvToneMapParams& params) {
    if (!float_frame) return;
    applyExpansion(float_frame, params);
}

void InverseToneMapper::applyExpansion(AVFrame* frame, const InvToneMapParams& params) {
    int width = frame->width;
    int height = frame->height;
    float target_peak = params.target_peak > 0 ? params.target_peak : 1000.0f;
    float ev = powf(2.0f, params.exposure);
    float sat = params.saturation;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
            float* g = (float*)(frame->data[1] + y * frame->linesize[1]) + x;
            float* b = (float*)(frame->data[2] + y * frame->linesize[2]) + x;

            // SDR (0-1) -> HDR (0-target_peak) 扩展
            float rv = *r * ev;
            float gv = *g * ev;
            float bv = *b * ev;

            // 简单的线性扩展 + roll-off
            float max_rgb = fmaxf(rv, fmaxf(gv, bv));
            // 暗部噪点门限：低于阈值的像素不扩展，避免帧间闪烁
            const float noiseFloor = 0.03f;
            if (max_rgb < noiseFloor) {
                *r = rv;
                *g = gv;
                *b = bv;
            } else if (max_rgb > 0.0f) {
                float expanded = max_rgb * (target_peak / 203.0f);
                // 平滑过渡：在门限附近做线性混合
                float t = (max_rgb - noiseFloor) / (0.02f);
                t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
                float scale = (1.0f - t) + t * (expanded / max_rgb);
                *r = rv * scale;
                *g = gv * scale;
                *b = bv * scale;
            }

            // 饱和度调整
            float lum = 0.2126f * (*r) + 0.7152f * (*g) + 0.0722f * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}