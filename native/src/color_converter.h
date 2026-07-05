#ifndef COLOR_CONVERTER_H
#define COLOR_CONVERTER_H

extern "C" {
#include <libavutil/frame.h>
#include <libswscale/swscale.h>
}

class ColorConverter {
public:
    ColorConverter();
    ~ColorConverter() = default;
    int convert(AVFrame* src, AVFrame* dst, int src_csp, int dst_csp);
};

#endif