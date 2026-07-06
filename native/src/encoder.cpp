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

    // 选择编码器
    const AVCodec* codec = nullptr;
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

    // 像素格式转换提醒（FFmpeg 7+ 用 av_pix_fmt_desc_get 替代废弃的 av_get_pix_fmt_name）
    if (dec_ctx->pix_fmt != AV_PIX_FMT_YUV420P) {
        const char* fmt_name = "未知";
        const AVPixFmtDescriptor* desc = av_pix_fmt_desc_get(dec_ctx->pix_fmt);
        if (desc && desc->name) fmt_name = desc->name;
        std::cerr << "警告: 输入像素格式 " << fmt_name
                  << " 将转换为 YUV420P 编码" << std::endl;
    }

    // 编码器参数（使用 AVDictionary 替代 av_opt_set，避免 FFmpeg 8.x API 废弃问题）
    if (codec->id == AV_CODEC_ID_H264 || codec->id == AV_CODEC_ID_H265) {
        AVDictionary* opts = nullptr;
        av_dict_set(&opts, "crf", std::to_string(crf).c_str(), 0);
        av_dict_set(&opts, "preset", "medium", 0);
        ret = avcodec_open2(enc_ctx_, codec, &opts);
        av_dict_free(&opts);
    } else {
        ret = avcodec_open2(enc_ctx_, codec, nullptr);
    }
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
    if (ret < 0 && ret != AVERROR_EOF) return ret;

    AVPacket* pkt = av_packet_alloc();
    // 循环接收：编码器可能为一个输入帧产生多个输出包（B 帧 / lookahead）
    while (true) {
        ret = avcodec_receive_packet(enc_ctx_, pkt);
        if (ret == AVERROR(EAGAIN)) break;
        if (ret < 0) { av_packet_free(&pkt); return ret; }
        pkt->stream_index = 0;
        ret = av_interleaved_write_frame(fmt_ctx_, pkt);
        av_packet_unref(pkt);
        if (ret < 0) { av_packet_free(&pkt); return ret; }
        frame_count_++;
    }
    av_packet_free(&pkt);
    return 0;
}

int Encoder::finalize() {
    if (!initialized_) return -1;

    // 冲刷编码器：发送 EOF 信号
    int ret = avcodec_send_frame(enc_ctx_, nullptr);
    // EAGAIN 表示编码器还有缓冲包未输出，继续 receive 循环排空即可
    if (ret < 0 && ret != AVERROR_EOF && ret != AVERROR(EAGAIN)) return ret;

    AVPacket* pkt = av_packet_alloc();
    while (true) {
        ret = avcodec_receive_packet(enc_ctx_, pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) break;
        pkt->stream_index = 0;
        ret = av_interleaved_write_frame(fmt_ctx_, pkt);
        av_packet_unref(pkt);
        if (ret < 0) break;
    }
    av_packet_free(&pkt);

    av_write_trailer(fmt_ctx_);
    return 0;
}

void Encoder::cancel() {
    cancelled_ = true;
}
