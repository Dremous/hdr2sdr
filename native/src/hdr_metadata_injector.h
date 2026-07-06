#ifndef HDR_METADATA_INJECTOR_H
#define HDR_METADATA_INJECTOR_H

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/mastering_display_metadata.h>
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