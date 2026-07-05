### Task 7: C++ ToneMapper �?InverseToneMapper

**Files:**
- Create: `native/src/tone_mapper.h`
- Create: `native/src/tone_mapper.cpp`
- Create: `native/src/inverse_tone_mapper.h`
- Create: `native/src/inverse_tone_mapper.cpp`

**Interfaces:**
- Consumes: `AVFrame`, `HDRMetadata`
- Produces: tone-mapped AVFrame

- [ ] **Step 1: 创建 native/src/tone_mapper.h**

```cpp
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
```

- [ ] **Step 2: 创建 native/src/tone_mapper.cpp**

```cpp
#include "tone_mapper.h"
#include <cmath>
#include <cstring>

ToneMapper::ToneMapper() : algorithm_(0) {}

void ToneMapper::setAlgorithm(int algo) {
    algorithm_ = algo;
}

void ToneMapper::apply(AVFrame* frame, const ToneMapParams& params) {
    if (!frame) return;
    applyBt2390(frame, params);
}

void ToneMapper::applyBt2390(AVFrame* frame, const ToneMapParams& params) {
    int width = frame->width;
    int height = frame->height;
    float peak = params.peak_luminance > 0 ? params.peak_luminance : 1000.0f;
    float ev = powf(2.0f, params.exposure);
    float sat = params.saturation;

    // 对每个像素应�?BT.2390 tone mapping
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            // 获取 RGB 值（假设 frame 数据�?float32 平面格式�?            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
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

            // 饱和度调�?            float lum = 0.2126f * (*r) + 0.7152f * (*g) + 0.0722f * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}
```

- [ ] **Step 3: 创建 native/src/inverse_tone_mapper.h**

```cpp
#ifndef INVERSE_TONE_MAPPER_H
#define INVERSE_TONE_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
}

struct InvToneMapParams {
    double target_peak;     // 目标峰值亮�?nit
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
```

- [ ] **Step 4: 创建 native/src/inverse_tone_mapper.cpp**

```cpp
#include "inverse_tone_mapper.h"
#include <cmath>

InverseToneMapper::InverseToneMapper() {}

void InverseToneMapper::apply(AVFrame* frame, const InvToneMapParams& params) {
    applyExpansion(frame, params);
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

            // 简单的线性扩�?+ roll-off
            float max_rgb = fmaxf(rv, fmaxf(gv, bv));
            if (max_rgb > 0.0f) {
                float expanded = max_rgb * (target_peak / 203.0f);
                float scale = expanded / max_rgb;
                *r = rv * scale;
                *g = gv * scale;
                *b = bv * scale;
            }

            // 饱和度调�?            float lum = 0.2126f * (*r) + 0.7152f * (*g) + 0.0722f * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}
```

- [ ] **Step 5: 提交**

```bash
git add native/src/tone_mapper.h native/src/tone_mapper.cpp
git add native/src/inverse_tone_mapper.h native/src/inverse_tone_mapper.cpp
git commit -m "feat: 添加 ToneMapper �?InverseToneMapper 模块"
```

---

