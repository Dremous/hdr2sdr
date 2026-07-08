#include "inverse_tone_mapper.h"
#include "pixel_utils.h"
#include <cmath>

InverseToneMapper::InverseToneMapper() {}

void InverseToneMapper::apply(AVFrame* frame, const InvToneMapParams& params,
                              int src_colorspace) {
    if (!frame) return;

    AVFrame* float_frame = convertToFloatPlanar(frame, src_colorspace);
    if (!float_frame) return;

    applyExpansion(float_frame, params);

    convertFromFloatPlanar(frame, float_frame, src_colorspace);
    av_frame_free(&float_frame);
}

void InverseToneMapper::applyOnFloat(AVFrame* float_frame, const InvToneMapParams& params) {
    if (!float_frame) return;
    applyExpansion(float_frame, params);
}

void InverseToneMapper::applyExpansion(AVFrame* frame, const InvToneMapParams& params) {
    int width = frame->width;
    int height = frame->height;
    float target_peak = params.target_peak > 0 ? (float)params.target_peak : 1000.0f;
    float ev = powf(2.0f, (float)params.exposure);
    float sat = (float)params.saturation;

    // SDR 参考白点 (nits)，用于计算相对峰值
    const float kSdrWhite = 100.0f;
    // 相对峰值 = 目标峰值 / SDR 白点，控制展开曲线形状
    float p = target_peak / kSdrWhite;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
            float* g = (float*)(frame->data[1] + y * frame->linesize[1]) + x;
            float* b = (float*)(frame->data[2] + y * frame->linesize[2]) + x;

            float rv = *r * ev;
            float gv = *g * ev;
            float bv = *b * ev;

            // 逆 BT.2390 色调映射曲线:
            //   前向:  mapped = x*(1+x/p)/(1+x)   用于 HDR→SDR 压缩
            //   逆向:  x = (p*(m-1) + sqrt(p²*(m-1)² + 4*p*m)) / 2
            //   x 是 SDR-相对线性值 (1.0 = 100 nits)，由 color_converter 做 LINEAR→PQ 映射
            float max_rgb = fmaxf(rv, fmaxf(gv, bv));
            if (max_rgb > 0.0f) {
                float m = max_rgb;
                float tmp = p * (m - 1.0f);
                float x = (tmp + sqrtf(tmp * tmp + 4.0f * p * m)) * 0.5f;
                float scale = x / m;
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