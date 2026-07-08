#include "tone_mapper.h"
#include "pixel_utils.h"
#include <cmath>
#include <cstring>

ToneMapper::ToneMapper() : algorithm_(0) {}

void ToneMapper::setAlgorithm(int algo) {
    algorithm_ = algo;
}

void ToneMapper::apply(AVFrame* frame, const ToneMapParams& params,
                       int src_colorspace) {
    if (!frame) return;

    // 转换为 GBRPF32 用于浮点 tone mapping（使用源视频的矩阵系数）
    AVFrame* float_frame = convertToFloatPlanar(frame, src_colorspace);
    if (!float_frame) return;

    // 在 float 帧上应用 BT.2390
    applyBt2390(float_frame, params);

    // 将结果写回原始帧（使用相同的矩阵系数保持对称）
    convertFromFloatPlanar(frame, float_frame, src_colorspace);
    av_frame_free(&float_frame);
}

void ToneMapper::applyOnFloat(AVFrame* float_frame, const ToneMapParams& params) {
    applyBt2390(float_frame, params);
}

void ToneMapper::applyBt2390(AVFrame* frame, const ToneMapParams& params) {
    int width = frame->width;
    int height = frame->height;
    float peak = params.peak_luminance > 0 ? params.peak_luminance : 1000.0f;
    float ev = powf(2.0f, params.exposure);
    float sat = params.saturation;

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

            // 饱和度调整
            float lum = 0.2126f * (*r) + 0.7152f * (*g) + 0.0722f * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}