#ifndef ENCODER_H
#define ENCODER_H

#include <string>
#include <atomic>
#include <functional>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/frame.h>
}

using ProgressCb = std::function<void(int percent, int64_t current, int64_t total)>;

class Encoder {
public:
    Encoder();
    ~Encoder();

    int open(const std::string& filename, AVCodecContext* dec_ctx,
             int encoder_type, int crf,
             int target_width, int target_height,
             int crop_left, int crop_right, int crop_top, int crop_bottom);
    void close();
    int encodeFrame(AVFrame* frame);
    int finalize();
    void cancel();

private:
    AVFormatContext* fmt_ctx_;
    AVCodecContext* enc_ctx_;
    AVStream* stream_;
    bool initialized_;
    std::atomic<bool> cancelled_;
    int frame_count_;
};

#endif