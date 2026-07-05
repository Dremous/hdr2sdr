#ifndef HDR_ANALYZER_H
#define HDR_ANALYZER_H

#include <string>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/mastering_display_metadata.h>
#include <libavutil/content_light_metadata.h>
}

struct HDRMetadata {
    int hdr_type;           // 0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
    double max_luminance;   // nit
    double min_luminance;
    double avg_luminance;
    double max_cll;         // MaxCLL
    double max_fall;        // MaxFALL
    double primaries[8];    // display primaries (x,y for R,G,B,W)
};

class HDRAnalyzer {
public:
    static HDRMetadata analyze(AVFormatContext* fmt_ctx,
                                AVCodecContext* codec_ctx,
                                int video_stream_index);
    static int detectHdrType(AVFormatContext* fmt_ctx, int video_stream_index);
};

#endif