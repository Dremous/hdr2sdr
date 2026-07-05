#ifndef INVERSE_TONE_MAPPER_H
#define INVERSE_TONE_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
}

struct InvToneMapParams {
    double target_peak;     // 目标峰值亮度，nit
    double exposure;
    double saturation;
};

class InverseToneMapper {
public:
    InverseToneMapper();
    void apply(AVFrame* frame, const InvToneMapParams& params);
private:
    void applyExpansion(AVFrame* frame, const InvToneMapParams& params);
};

#endif