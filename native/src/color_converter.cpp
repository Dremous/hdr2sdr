#include "color_converter.h"
#include <cstring>

ColorConverter::ColorConverter() {}

int ColorConverter::convert(AVFrame* src, AVFrame* dst, int src_csp, int dst_csp) {
    if (!src || !dst) return -1;

    int src_colorspace = AVCOL_SPC_BT2020_NCL;
    int dst_colorspace = AVCOL_SPC_BT709;
    int src_color_prim = AVCOL_PRI_BT2020;
    int dst_color_prim = AVCOL_PRI_BT709;
    int src_color_trc = AVCOL_TRC_SMPTE2084;
    int dst_color_trc = AVCOL_TRC_BT709;
    int src_range = AVCOL_RANGE_MPEG;
    int dst_range = AVCOL_RANGE_MPEG;

    if (src_csp == 0) { // BT.709
        src_colorspace = AVCOL_SPC_BT709;
        src_color_prim = AVCOL_PRI_BT709;
        src_color_trc = AVCOL_TRC_BT709;
    } else if (src_csp == 2) { // DCI-P3
        src_colorspace = AVCOL_SPC_SMPTE170M;
        src_color_prim = AVCOL_PRI_SMPTE432;
    }

    if (dst_csp == 0) { // BT.709
        dst_colorspace = AVCOL_SPC_BT709;
        dst_color_prim = AVCOL_PRI_BT709;
        dst_color_trc = AVCOL_TRC_BT709;
    } else if (dst_csp == 2) { // DCI-P3
        dst_colorspace = AVCOL_SPC_SMPTE170M;
        dst_color_prim = AVCOL_PRI_SMPTE432;
    }

    SwsContext* sws = sws_getContext(
        src->width, src->height, (AVPixelFormat)src->format,
        dst->width, dst->height, (AVPixelFormat)dst->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws) return -1;

    sws_setColorspaceDetails(sws,
        sws_getCoefficients(src_colorspace), src_color_trc,
        sws_getCoefficients(dst_colorspace), dst_color_trc,
        0, 1 << 16, 1 << 16);

    sws_scale(sws, src->data, src->linesize, 0, src->height,
              dst->data, dst->linesize);

    sws_freeContext(sws);
    return 0;
}