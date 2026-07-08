#include "color_converter.h"
#include "debug_log.h"
#include <cstring>

ColorConverter::ColorConverter() {}

int ColorConverter::convert(AVFrame* src, AVFrame* dst, int src_csp, int dst_csp,
                            bool is_hdr_output) {
    if (!src || !dst) return -1;

    int src_colorspace = AVCOL_SPC_BT2020_NCL;
    int dst_colorspace = AVCOL_SPC_BT709;
    int src_color_prim = AVCOL_PRI_BT2020;
    int dst_color_prim = AVCOL_PRI_BT709;
    // 默认 SDR TRC（BT.709 gamma），HDR 输出时覆盖为 PQ
    int src_color_trc = AVCOL_TRC_BT709;
    int dst_color_trc = is_hdr_output ? AVCOL_TRC_SMPTE2084 : AVCOL_TRC_BT709;
    int src_range = AVCOL_RANGE_MPEG;
    int dst_range = AVCOL_RANGE_MPEG;

    if (src_csp == 0) { // BT.709 SDR 输入
        src_colorspace = AVCOL_SPC_BT709;
        src_color_prim = AVCOL_PRI_BT709;
        src_color_trc = AVCOL_TRC_BT709;
    } else if (src_csp == 2) { // DCI-P3
        src_colorspace = AVCOL_SPC_SMPTE170M;
        src_color_prim = AVCOL_PRI_SMPTE432;
    }
    // src_csp==1 (BT.2020): 默认值

    // GBRPF32 浮点输入已经是线性值（convertToFloatPlanar 已做去 gamma 处理）
    // 必须用 LINEAR 避免 swscale 二次逆 gamma —— 放在 src_csp 之后，防止被覆盖
    if (src->format == AV_PIX_FMT_GBRPF32) {
        src_color_trc = AVCOL_TRC_LINEAR;
    }

    if (dst_csp == 0) { // BT.709 SDR 输出
        dst_colorspace = AVCOL_SPC_BT709;
        dst_color_prim = AVCOL_PRI_BT709;
        dst_color_trc = AVCOL_TRC_BT709;
    } else if (dst_csp == 2) { // DCI-P3
        dst_colorspace = AVCOL_SPC_SMPTE170M;
        dst_color_prim = AVCOL_PRI_SMPTE432;
    }
    // dst_csp==1 (BT.2020): 默认值通过 is_hdr_output 控制 TRC
    //   HDR 输出 → PQ，SDR 输出 → BT.709 gamma
    //
    // 注：色域映射（BT.709↔BT.2020 primaries 3×3 矩阵）已在 gamut_mapper.h 中实现，
    // 在 pipeline.cpp 的 processSdrToHdr / processHdrToSdr 中调用。
    // sws_setColorspaceDetails 仅控制 YUV 编解码矩阵和传递函数。

    SwsContext* sws = sws_getContext(
        src->width, src->height, (AVPixelFormat)src->format,
        dst->width, dst->height, (AVPixelFormat)dst->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws) return -1;

    sws_setColorspaceDetails(sws,
        sws_getCoefficients(src_colorspace), src_color_trc,
        sws_getCoefficients(dst_colorspace), dst_color_trc,
        0, 1 << 16, 1 << 16);

    // 首帧时输出转换参数
    static int call_count = 0;
    if (call_count == 0) {
        HDR_LOG("color_converter[0]: fmt %d→%d | srcCSP=%d(spc=%d,pri=%d,trc=%d) dstCSP=%d(spc=%d,pri=%d,trc=%d) hdr=%d",
            src->format, dst->format,
            src_csp, src_colorspace, src_color_prim, src_color_trc,
            dst_csp, dst_colorspace, dst_color_prim, dst_color_trc,
            (int)is_hdr_output);
        call_count++;
    }

    sws_scale(sws, src->data, src->linesize, 0, src->height,
              dst->data, dst->linesize);

    sws_freeContext(sws);
    return 0;
}