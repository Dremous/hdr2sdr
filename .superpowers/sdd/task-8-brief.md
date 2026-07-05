### Task 8: C++ ColorConverter �?HDRMetadataInjector

**Files:**
- Create: `native/src/color_converter.h`
- Create: `native/src/color_converter.cpp`
- Create: `native/src/hdr_metadata_injector.h`
- Create: `native/src/hdr_metadata_injector.cpp`

- [ ] **Step 1: 创建 native/src/color_converter.h**

```cpp
#ifndef COLOR_CONVERTER_H
#define COLOR_CONVERTER_H

extern "C" {
#include <libavutil/frame.h>
#include <libswscale/swscale.h>
}

class ColorConverter {
public:
    ColorConverter();
    ~ColorConverter();
    int convert(AVFrame* src, AVFrame* dst, int src_csp, int dst_csp);
private:
    SwsContext* sws_ctx_;
};

#endif
```

- [ ] **Step 2: 创建 native/src/color_converter.cpp**

```cpp
#include "color_converter.h"
#include <cstring>

ColorConverter::ColorConverter() : sws_ctx_(nullptr) {}

ColorConverter::~ColorConverter() {
    if (sws_ctx_) {
        sws_freeContext(sws_ctx_);
    }
}

int ColorConverter::convert(AVFrame* src, AVFrame* dst, int src_csp, int dst_csp) {
    if (!src || !dst) return -1;

    int src_colorspace = AVCOL_SPC_BT2020_NCL;
    int dst_colorspace = AVCOL_SPC_BT709;
    int src_color_trc = AVCOL_TRC_SMPTE2084;
    int dst_color_trc = AVCOL_TRC_BT709;

    if (src_csp == 0) { // BT.709
        src_colorspace = AVCOL_SPC_BT709;
        src_color_trc = AVCOL_TRC_BT709;
    } else if (src_csp == 2) { // DCI-P3
        src_colorspace = AVCOL_SPC_SMPTE170M;
    }

    if (dst_csp == 0) { // BT.709
        dst_colorspace = AVCOL_SPC_BT709;
        dst_color_trc = AVCOL_TRC_BT709;
    } else if (dst_csp == 2) { // DCI-P3
        dst_colorspace = AVCOL_SPC_SMPTE170M;
    }

    sws_ctx_ = sws_getContext(
        src->width, src->height, (AVPixelFormat)src->format,
        dst->width, dst->height, (AVPixelFormat)dst->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws_ctx_) return -1;

    sws_setColorspaceDetails(sws_ctx_,
        sws_getCoefficients(src_colorspace), src_color_trc,
        sws_getCoefficients(dst_colorspace), dst_color_trc,
        0, 1 << 16, 1 << 16);

    sws_scale(sws_ctx_, src->data, src->linesize, 0, src->height,
              dst->data, dst->linesize);

    return 0;
}
```

- [ ] **Step 3: 创建 native/src/hdr_metadata_injector.h**

```cpp
#ifndef HDR_METADATA_INJECTOR_H
#define HDR_METADATA_INJECTOR_H

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
}

struct HDRInjectParams {
    double max_luminance;
    double min_luminance;
    double max_cll;
    double max_fall;
    int hdr_type; // 1=HDR10, 2=HLG
};

class HDRMetadataInjector {
public:
    static void injectSideData(AVCodecContext* codec_ctx,
                                AVFormatContext* fmt_ctx,
                                const HDRInjectParams& params);
};

#endif
```

- [ ] **Step 4: 创建 native/src/hdr_metadata_injector.cpp**

```cpp
#include "hdr_metadata_injector.h"
#include <cstring>

void HDRMetadataInjector::injectSideData(AVCodecContext* codec_ctx,
                                          AVFormatContext* fmt_ctx,
                                          const HDRInjectParams& params) {
    if (!codec_ctx) return;

    // 设置色彩参数
    codec_ctx->color_primaries = AVCOL_PRI_BT2020;
    codec_ctx->color_trc = (params.hdr_type == 2)
        ? AVCOL_TRC_ARIB_STD_B67
        : AVCOL_TRC_SMPTE2084;
    codec_ctx->colorspace = AVCOL_SPC_BT2020_NCL;

    // HDR10 需要注�?Mastering Display Metadata
    if (params.hdr_type == 1) {
        auto* mastering = (AVMasteringDisplayMetadata*)
            av_mallocz(sizeof(AVMasteringDisplayMetadata));
        if (!mastering) return;

        // BT.2020 基色
        mastering->display_primaries[0][0] = av_d2q(0.708, 100000);
        mastering->display_primaries[0][1] = av_d2q(0.292, 100000);
        mastering->display_primaries[1][0] = av_d2q(0.170, 100000);
        mastering->display_primaries[1][1] = av_d2q(0.797, 100000);
        mastering->display_primaries[2][0] = av_d2q(0.131, 100000);
        mastering->display_primaries[2][1] = av_d2q(0.046, 100000);
        mastering->white_point[0] = av_d2q(0.3127, 100000);
        mastering->white_point[1] = av_d2q(0.3290, 100000);
        mastering->max_luminance = av_d2q(params.max_luminance, 10000);
        mastering->min_luminance = av_d2q(params.min_luminance > 0
            ? params.min_luminance : 0.005, 10000);
        mastering->has_luminance = 1;
        mastering->has_primaries = 1;

        av_stream_add_side_data(fmt_ctx->streams[0],
            AV_PKT_DATA_MASTERING_DISPLAY_METADATA,
            (uint8_t*)mastering,
            sizeof(AVMasteringDisplayMetadata));
    }
}
```

- [ ] **Step 5: 提交**

```bash
git add native/src/color_converter.h native/src/color_converter.cpp
git add native/src/hdr_metadata_injector.h native/src/hdr_metadata_injector.cpp
git commit -m "feat: 添加 ColorConverter �?HDRMetadataInjector 模块"
```

---

