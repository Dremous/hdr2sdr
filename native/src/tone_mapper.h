#ifndef TONE_MAPPER_H
#define TONE_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/pixfmt.h>
}

struct ToneMapParams {
    double peak_luminance;
    double exposure;
    double saturation;
};

class ToneMapper {
public:
    ToneMapper();
    /// 色调映射 + 色域转换（完整 HDR→SDR / SDR→HDR 单帧处理）
    /// src_colorspace: YUV→RGB 矩阵 / dst_colorspace: RGB→YUV 矩阵
    /// gamut_dir: 0=不转换, 1=BT.2020→BT.709, 2=BT.709→BT.2020
    void apply(AVFrame* frame, const ToneMapParams& params,
               int src_colorspace = AVCOL_SPC_BT2020_NCL,
               int dst_colorspace = AVCOL_SPC_BT709,
               int gamut_dir = 0);
    /// 直接在 GBRPF32 float 帧上应用 BT.2390（不转换格式）
    /// is_bt2020: 亮度系数用 BT.2020(true) 还是 BT.709(false)
    void applyOnFloat(AVFrame* float_frame, const ToneMapParams& params,
                      bool is_bt2020 = true);
    void setAlgorithm(int algo); // 0=BT.2390, 1=Reinhard, 2=Mobius
private:
    void applyBt2390(AVFrame* frame, const ToneMapParams& params,
                     bool is_bt2020 = true);
    int algorithm_;
};

#endif