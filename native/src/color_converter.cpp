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
    int src_color_trc = AVCOL_TRC_BT709;
    int dst_color_trc = is_hdr_output ? AVCOL_TRC_SMPTE2084 : AVCOL_TRC_BT709;

    if (src_csp == 0) { // BT.709 SDR 输入
        src_colorspace = AVCOL_SPC_BT709;
        src_color_prim = AVCOL_PRI_BT709;
        src_color_trc = AVCOL_TRC_BT709;
    } else if (src_csp == 2) { // DCI-P3
        src_colorspace = AVCOL_SPC_SMPTE170M;
        src_color_prim = AVCOL_PRI_SMPTE432;
    }
    // src_csp==1 (BT.2020): 默认值

    // GBRPF32 浮点输入已由 convertToFloatPlanar 线性化，TRC=LINEAR
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
    // 注：色域映射已在 gamut_mapper.h 中实现

    // 在帧上设置色度元数据——sws_scale_frame 据此做 TRC 转换
    src->color_trc = (AVColorTransferCharacteristic)src_color_trc;
    src->color_primaries = (AVColorPrimaries)src_color_prim;
    src->colorspace = (AVColorSpace)src_colorspace;
    src->color_range = (src->format == AV_PIX_FMT_GBRPF32)
        ? AVCOL_RANGE_JPEG : AVCOL_RANGE_MPEG;

    dst->color_trc = (AVColorTransferCharacteristic)dst_color_trc;
    dst->color_primaries = (AVColorPrimaries)dst_color_prim;
    dst->colorspace = (AVColorSpace)dst_colorspace;
    dst->color_range = AVCOL_RANGE_MPEG;

    SwsContext* sws = sws_getContext(
        src->width, src->height, (AVPixelFormat)src->format,
        dst->width, dst->height, (AVPixelFormat)dst->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws) return -1;

    // sws_setColorspaceDetails 的 range 值：0=limited, 1=full
    // AVCOL_RANGE_MPEG=1, AVCOL_RANGE_JPEG=2，需转换
    int sws_src_range = (src->color_range == AVCOL_RANGE_JPEG) ? 1 : 0;
    int sws_dst_range = (dst->color_range == AVCOL_RANGE_JPEG) ? 1 : 0;
    sws_setColorspaceDetails(sws,
        sws_getCoefficients(src_colorspace), sws_src_range,
        sws_getCoefficients(dst_colorspace), sws_dst_range,
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

    sws_scale_frame(sws, dst, src);
    sws_freeContext(sws);
    return 0;
}