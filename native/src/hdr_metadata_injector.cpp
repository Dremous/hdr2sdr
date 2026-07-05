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

    // HDR10 需要注入 Mastering Display Metadata
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