#ifndef TONE_MAPPER_H
#define TONE_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
}

struct ToneMapParams {
    double peak_luminance;
    double exposure;
    double saturation;
};

class ToneMapper {
public:
    ToneMapper();
    void apply(AVFrame* frame, const ToneMapParams& params);
    void setAlgorithm(int algo); // 0=BT.2390, 1=Reinhard, 2=Mobius
private:
    void applyBt2390(AVFrame* frame, const ToneMapParams& params);
    int algorithm_;
};

#endif