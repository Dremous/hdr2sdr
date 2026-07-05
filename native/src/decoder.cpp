#include "decoder.h"
#include <iostream>

Decoder::Decoder()
    : fmt_ctx_(nullptr), codec_ctx_(nullptr), video_stream_index_(-1) {}

Decoder::~Decoder() {
    close();
}

int Decoder::open(const std::string& filename) {
    std::lock_guard<std::mutex> lock(mutex_);

    int ret = avformat_open_input(&fmt_ctx_, filename.c_str(), nullptr, nullptr);
    if (ret < 0) return ret;

    ret = avformat_find_stream_info(fmt_ctx_, nullptr);
    if (ret < 0) return ret;

    for (unsigned int i = 0; i < fmt_ctx_->nb_streams; ++i) {
        if (fmt_ctx_->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_stream_index_ = i;
            break;
        }
    }
    if (video_stream_index_ < 0) return AVERROR_DECODER_NOT_FOUND;

    AVCodecParameters* codecpar = fmt_ctx_->streams[video_stream_index_]->codecpar;
    const AVCodec* codec = avcodec_find_decoder(codecpar->codec_id);
    if (!codec) return AVERROR_DECODER_NOT_FOUND;

    codec_ctx_ = avcodec_alloc_context3(codec);
    if (!codec_ctx_) return AVERROR(ENOMEM);

    ret = avcodec_parameters_to_context(codec_ctx_, codecpar);
    if (ret < 0) return ret;

    ret = avcodec_open2(codec_ctx_, codec, nullptr);
    return ret;
}

void Decoder::close() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (codec_ctx_) {
        avcodec_free_context(&codec_ctx_);
    }
    if (fmt_ctx_) {
        avformat_close_input(&fmt_ctx_);
    }
    video_stream_index_ = -1;
}

bool Decoder::isOpen() const {
    return fmt_ctx_ != nullptr && codec_ctx_ != nullptr;
}

int Decoder::getFrameCount() const {
    if (!isOpen()) return 0;
    return fmt_ctx_->streams[video_stream_index_]->nb_frames;
}

double Decoder::getFps() const {
    if (!isOpen()) return 0.0;
    AVRational r = fmt_ctx_->streams[video_stream_index_]->avg_frame_rate;
    return av_q2d(r);
}

int Decoder::getWidth() const {
    return codec_ctx_ ? codec_ctx_->width : 0;
}

int Decoder::getHeight() const {
    return codec_ctx_ ? codec_ctx_->height : 0;
}

double Decoder::getDurationSec() const {
    if (!fmt_ctx_) return 0.0;
    return fmt_ctx_->duration / (double)AV_TIME_BASE;
}

int Decoder::getPixelFormat() const {
    return codec_ctx_ ? codec_ctx_->pix_fmt : AV_PIX_FMT_NONE;
}

AVFrame* Decoder::decodeNextFrame() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!isOpen()) return nullptr;

    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    while (av_read_frame(fmt_ctx_, pkt) >= 0) {
        if (pkt->stream_index == video_stream_index_) {
            int ret = avcodec_send_packet(codec_ctx_, pkt);
            if (ret < 0) break;

            ret = avcodec_receive_frame(codec_ctx_, frame);
            if (ret == 0) {
                av_packet_free(&pkt);
                return frame;
            }
        }
        av_packet_unref(pkt);
    }

    av_packet_free(&pkt);
    av_frame_free(&frame);
    return nullptr;
}

AVFrame* Decoder::seekAndDecode(int64_t timestamp_us) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!isOpen()) return nullptr;

    int64_t ts = av_rescale_q(timestamp_us, AV_TIME_BASE_Q,
        fmt_ctx_->streams[video_stream_index_]->time_base);
    av_seek_frame(fmt_ctx_, video_stream_index_, ts, AVSEEK_FLAG_BACKWARD);
    avcodec_flush_buffers(codec_ctx_);

    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    while (av_read_frame(fmt_ctx_, pkt) >= 0) {
        if (pkt->stream_index == video_stream_index_) {
            int ret = avcodec_send_packet(codec_ctx_, pkt);
            if (ret < 0) break;

            ret = avcodec_receive_frame(codec_ctx_, frame);
            if (ret == 0) {
                av_packet_free(&pkt);
                return frame;
            }
        }
        av_packet_unref(pkt);
    }

    av_packet_free(&pkt);
    av_frame_free(&frame);
    return nullptr;
}

void Decoder::flush() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (codec_ctx_) {
        avcodec_flush_buffers(codec_ctx_);
    }
}