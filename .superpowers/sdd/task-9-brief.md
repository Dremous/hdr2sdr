### Task 9: C++ Encoder 模块

**Files:**
- Create: `native/src/encoder.h`
- Create: `native/src/encoder.cpp`

- [x] **Step 1: 创建 native/src/encoder.h**

```cpp
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
```

- [x] **Step 2: 创建 native/src/encoder.cpp**

```cpp
#include "encoder.h"
#include <iostream>

Encoder::Encoder()
    : fmt_ctx_(nullptr), enc_ctx_(nullptr), stream_(nullptr),
      initialized_(false), cancelled_(false), frame_count_(0) {}

Encoder::~Encoder() {
    close();
}

int Encoder::open(const std::string& filename, AVCodecContext* dec_ctx,
                   int encoder_type, int crf,
                   int target_width, int target_height,
                   int crop_left, int crop_right, int crop_top, int crop_bottom) {
    int ret;

    ret = avformat_alloc_output_context2(&fmt_ctx_, nullptr, nullptr, filename.c_str());
    if (ret < 0) return ret;

    // 选择编码�?    const AVCodec* codec = nullptr;
    const char* codec_name = nullptr;
    switch (encoder_type) {
        case 0: codec_name = "libx264"; break;
        case 1: codec_name = "libx265"; break;
        case 2: codec_name = "libaom-av1"; break;
        default: codec_name = "libx265";
    }
    codec = avcodec_find_encoder_by_name(codec_name);
    if (!codec) return AVERROR_ENCODER_NOT_FOUND;

    enc_ctx_ = avcodec_alloc_context3(codec);
    if (!enc_ctx_) return AVERROR(ENOMEM);

    int out_w = target_width > 0 ? target_width : (dec_ctx->width - crop_left - crop_right);
    int out_h = target_height > 0 ? target_height : (dec_ctx->height - crop_top - crop_bottom);

    enc_ctx_->width = out_w;
    enc_ctx_->height = out_h;
    enc_ctx_->time_base = dec_ctx->time_base;
    enc_ctx_->pix_fmt = AV_PIX_FMT_YUV420P;
    enc_ctx_->color_primaries = dec_ctx->color_primaries;
    enc_ctx_->color_trc = dec_ctx->color_trc;
    enc_ctx_->colorspace = dec_ctx->colorspace;
    enc_ctx_->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

    if (codec->id == AV_CODEC_ID_H264 || codec->id == AV_CODEC_ID_H265) {
        av_opt_set(enc_ctx_->priv_data, "crf", std::to_string(crf).c_str(), 0);
        av_opt_set(enc_ctx_->priv_data, "preset", "medium", 0);
    }

    ret = avcodec_open2(enc_ctx_, codec, nullptr);
    if (ret < 0) return ret;

    stream_ = avformat_new_stream(fmt_ctx_, codec);
    if (!stream_) return AVERROR(ENOMEM);

    ret = avcodec_parameters_from_context(stream_->codecpar, enc_ctx_);
    if (ret < 0) return ret;
    stream_->time_base = enc_ctx_->time_base;

    if (!(fmt_ctx_->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&fmt_ctx_->pb, filename.c_str(), AVIO_FLAG_WRITE);
        if (ret < 0) return ret;
    }

    ret = avformat_write_header(fmt_ctx_, nullptr);
    if (ret < 0) return ret;

    initialized_ = true;
    return 0;
}

void Encoder::close() {
    if (enc_ctx_) {
        avcodec_free_context(&enc_ctx_);
    }
    if (fmt_ctx_ && !(fmt_ctx_->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&fmt_ctx_->pb);
    }
    if (fmt_ctx_) {
        avformat_free_context(fmt_ctx_);
    }
    initialized_ = false;
}

int Encoder::encodeFrame(AVFrame* frame) {
    if (!initialized_ || cancelled_) return -1;

    int ret = avcodec_send_frame(enc_ctx_, frame);
    if (ret < 0) return ret;

    AVPacket* pkt = av_packet_alloc();
    ret = avcodec_receive_packet(enc_ctx_, pkt);
    if (ret >= 0) {
        pkt->stream_index = 0;
        av_interleaved_write_frame(fmt_ctx_, pkt);
        frame_count_++;
    }
    av_packet_free(&pkt);
    return ret;
}

int Encoder::finalize() {
    if (!initialized_) return -1;

    // flush encoder
    int ret = avcodec_send_frame(enc_ctx_, nullptr);
    if (ret < 0) return ret;

    AVPacket* pkt = av_packet_alloc();
    while (true) {
        ret = avcodec_receive_packet(enc_ctx_, pkt);
        if (ret < 0) break;
        pkt->stream_index = 0;
        av_interleaved_write_frame(fmt_ctx_, pkt);
    }
    av_packet_free(&pkt);

    av_write_trailer(fmt_ctx_);
    return 0;
}

void Encoder::cancel() {
    cancelled_ = true;
}
```

- [x] **Step 3: 提交**

```bash
git add native/src/encoder.h native/src/encoder.cpp
git commit -m "feat: 添加视频编码器模�?
```

---

