#include "hdr_analyzer.h"

int HDRAnalyzer::detectHdrType(AVFormatContext* fmt_ctx, int video_stream_index) {
    if (video_stream_index < 0) return 0;

    AVStream* stream = fmt_ctx->streams[video_stream_index];

    // 检查 Dolby Vision
    for (int i = 0; i < stream->codecpar->nb_coded_side_data; ++i) {
        auto side_data = stream->codecpar->coded_side_data[i];
        if (side_data.type == AV_PKT_DATA_DOVI_CONF) return 3;
    }

    // 检查 HDR10 / HLG
    for (int i = 0; i < stream->codecpar->nb_coded_side_data; ++i) {
        auto side_data = stream->codecpar->coded_side_data[i];
        if (side_data.type == AV_PKT_DATA_MASTERING_DISPLAY_METADATA) return 1;
    }

    // 检查 AVFrame side data
    // 先通过 codec context 的 side data 或 HLG transfer
    if (stream->codecpar->color_trc == AVCOL_TRC_ARIB_STD_B67) return 2;
    if (stream->codecpar->color_trc == AVCOL_TRC_SMPTE2084) return 1;

    return 0;
}

HDRMetadata HDRAnalyzer::analyze(AVFormatContext* fmt_ctx,
                                  AVCodecContext* codec_ctx,
                                  int video_stream_index) {
    HDRMetadata meta = {};
    meta.hdr_type = detectHdrType(fmt_ctx, video_stream_index);

    AVStream* stream = fmt_ctx->streams[video_stream_index];

    // 读取 Mastering Display Metadata
    AVMasteringDisplayMetadata* mastering = nullptr;
    AVContentLightMetadata* light = nullptr;

    for (int i = 0; i < stream->codecpar->nb_coded_side_data; ++i) {
        auto* sd = &stream->codecpar->coded_side_data[i];
        if (sd->type == AV_PKT_DATA_MASTERING_DISPLAY_METADATA
            && sd->size >= sizeof(AVMasteringDisplayMetadata)) {
            mastering = (AVMasteringDisplayMetadata*)sd->data;
        }
        if (sd->type == AV_PKT_DATA_CONTENT_LIGHT_LEVEL
            && sd->size >= sizeof(AVContentLightMetadata)) {
            light = (AVContentLightMetadata*)sd->data;
        }
    }

    if (mastering) {
        if (mastering->has_luminance) {
            meta.max_luminance = av_q2d(mastering->max_luminance);
            meta.min_luminance = av_q2d(mastering->min_luminance);
        }
        if (mastering->has_primaries) {
            meta.primaries[0] = av_q2d(mastering->display_primaries[0][0]);
            meta.primaries[1] = av_q2d(mastering->display_primaries[0][1]);
            meta.primaries[2] = av_q2d(mastering->display_primaries[1][0]);
            meta.primaries[3] = av_q2d(mastering->display_primaries[1][1]);
            meta.primaries[4] = av_q2d(mastering->display_primaries[2][0]);
            meta.primaries[5] = av_q2d(mastering->display_primaries[2][1]);
            meta.primaries[6] = av_q2d(mastering->white_point[0]);
            meta.primaries[7] = av_q2d(mastering->white_point[1]);
        }
    }

    if (light) {
        meta.max_cll = light->MaxCLL;
        meta.max_fall = light->MaxFALL;
    }

    if (meta.max_luminance <= 0) {
        meta.max_luminance = meta.hdr_type == 2 ? 1000.0 : 203.0;
    }

    meta.avg_luminance = meta.max_luminance * 0.2;

    return meta;
}