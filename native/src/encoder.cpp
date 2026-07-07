#include "encoder.h"
#include "debug_log.h"
#include <iostream>

Encoder::Encoder()
    : fmt_ctx_(nullptr), enc_ctx_(nullptr), stream_(nullptr),
      initialized_(false), cancelled_(false), frame_count_(0),
      frame_duration_(3000) {}

Encoder::~Encoder() {
    close();
}

int Encoder::open(const std::string& filename, AVCodecContext* dec_ctx,
                   int encoder_type, int crf,
                   int target_width, int target_height,
                   int crop_left, int crop_right, int crop_top, int crop_bottom) {
    int ret;
    HDR_LOG("Encoder::open: 开始, 输出=%s", filename.c_str());

    if (!dec_ctx) {
        HDR_LOG("Encoder::open: dec_ctx 为空!");
        return AVERROR(EINVAL);
    }

    HDR_LOG("Encoder::open: step1 avformat_alloc_output_context2...");
    ret = avformat_alloc_output_context2(&fmt_ctx_, nullptr, nullptr, filename.c_str());
    if (ret < 0) {
        HDR_LOG("Encoder::open: avformat_alloc_output_context2 失败 ret=%d", ret);
        return ret;
    }
    HDR_LOG("Encoder::open: step1 OK, fmt=%s", fmt_ctx_->oformat->name);

    // 选择编码器（若目标编码器不可用则回退到 mpeg4）
    const AVCodec* codec = nullptr;
    const char* codec_name = nullptr;
    switch (encoder_type) {
        case 0: codec_name = "libx264"; break;
        case 1: codec_name = "libx265"; break;
        case 2: codec_name = "libaom-av1"; break;
        default: codec_name = "libx265";
    }
    HDR_LOG("Encoder::open: step2 查找编码器 %s...", codec_name);
    codec = avcodec_find_encoder_by_name(codec_name);
    if (!codec) {
        // 回退：使用 mpeg4 编码器（始终可用，无需外部库）
        codec = avcodec_find_encoder_by_name("mpeg4");
        if (!codec) {
            HDR_LOG("Encoder::open: 未找到任何编码器");
            return AVERROR_ENCODER_NOT_FOUND;
        }
        HDR_LOG("Encoder::open: 回退到 mpeg4");
    }
    HDR_LOG("Encoder::open: step2 OK, codec=%s", codec->name);

    HDR_LOG("Encoder::open: step3 avcodec_alloc_context3...");
    enc_ctx_ = avcodec_alloc_context3(codec);
    if (!enc_ctx_) {
        HDR_LOG("Encoder::open: avcodec_alloc_context3 失败");
        return AVERROR(ENOMEM);
    }
    HDR_LOG("Encoder::open: step3 OK");

    int out_w = target_width > 0 ? target_width : (dec_ctx->width - crop_left - crop_right);
    int out_h = target_height > 0 ? target_height : (dec_ctx->height - crop_top - crop_bottom);

    enc_ctx_->width = out_w;
    enc_ctx_->height = out_h;
    enc_ctx_->pix_fmt = AV_PIX_FMT_YUV420P;
    // 帧率：优先用解码器帧率，无效则回退 30fps
    HDR_LOG("Encoder::open: step4 设置参数...");
    AVRational fr = dec_ctx->framerate;
    HDR_LOG("Encoder::open: 解码器帧率=%d/%d", fr.num, fr.den);
    if (fr.num <= 0 || fr.den <= 0) {
        // 尝试从码流时间基推断
        if (dec_ctx->time_base.num > 0 && dec_ctx->time_base.den > 0) {
            fr = av_inv_q(dec_ctx->time_base);
            HDR_LOG("Encoder::open: 从 time_base 推断帧率=%d/%d", fr.num, fr.den);
        } else {
            fr = {30, 1};
            HDR_LOG("Encoder::open: 使用默认 30fps");
        }
    }
    enc_ctx_->framerate = fr;
    // mpeg4 标准限制 timebase 分母 ≤ 65535，用 {1, 30000}
    enc_ctx_->time_base = AVRational{1, 30000};
    // 每帧时长 = 30000 / fps（时间基单位）
    frame_duration_ = av_rescale_q(1, av_inv_q(fr), enc_ctx_->time_base);
    if (frame_duration_ <= 0) frame_duration_ = 1000; // 默认 30fps → 1000
    enc_ctx_->color_primaries = dec_ctx->color_primaries;
    enc_ctx_->color_trc = dec_ctx->color_trc;
    enc_ctx_->colorspace = dec_ctx->colorspace;
    enc_ctx_->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    HDR_LOG("Encoder::open: step4 OK, timebase=%d/%d", enc_ctx_->time_base.num, enc_ctx_->time_base.den);

    // 像素格式转换提醒
    if (dec_ctx->pix_fmt != AV_PIX_FMT_YUV420P) {
        const char* fmt_name = "未知";
        const AVPixFmtDescriptor* desc = av_pix_fmt_desc_get(dec_ctx->pix_fmt);
        if (desc && desc->name) fmt_name = desc->name;
        HDR_LOG("Encoder::open: 输入像素格式 %s 将转换为 YUV420P", fmt_name);
    }

    // 编码器参数
    HDR_LOG("Encoder::open: step5 avcodec_open2...");
    if (codec->id == AV_CODEC_ID_H264 || codec->id == AV_CODEC_ID_H265) {
        AVDictionary* opts = nullptr;
        av_dict_set(&opts, "crf", std::to_string(crf).c_str(), 0);
        av_dict_set(&opts, "preset", "medium", 0);
        ret = avcodec_open2(enc_ctx_, codec, &opts);
        av_dict_free(&opts);
    } else {
        ret = avcodec_open2(enc_ctx_, codec, nullptr);
    }
    if (ret < 0) {
        HDR_LOG("Encoder::open: avcodec_open2 失败 ret=%d", ret);
        return ret;
    }
    HDR_LOG("Encoder::open: step5 OK");

    HDR_LOG("Encoder::open: step6 avformat_new_stream...");
    stream_ = avformat_new_stream(fmt_ctx_, codec);
    if (!stream_) {
        HDR_LOG("Encoder::open: avformat_new_stream 失败");
        return AVERROR(ENOMEM);
    }

    ret = avcodec_parameters_from_context(stream_->codecpar, enc_ctx_);
    if (ret < 0) {
        HDR_LOG("Encoder::open: avcodec_parameters_from_context 失败 ret=%d", ret);
        return ret;
    }
    stream_->time_base = enc_ctx_->time_base;
    HDR_LOG("Encoder::open: step6 OK");

    HDR_LOG("Encoder::open: step7 avio_open...");
    if (!(fmt_ctx_->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&fmt_ctx_->pb, filename.c_str(), AVIO_FLAG_WRITE);
        if (ret < 0) {
            HDR_LOG("Encoder::open: avio_open 失败 ret=%d", ret);
            return ret;
        }
    }
    HDR_LOG("Encoder::open: step7 OK");

    HDR_LOG("Encoder::open: step8 准备写入 header...");
    // mpeg4 在 mp4 容器中可能需要显式设置 codec_tag
    if (stream_->codecpar->codec_tag == 0) {
        stream_->codecpar->codec_tag = MKTAG('m', 'p', '4', 'v');
    }
    ret = avformat_write_header(fmt_ctx_, nullptr);
    if (ret < 0) {
        HDR_LOG("Encoder::open: avformat_write_header 失败 ret=%d", ret);
        return ret;
    }
    HDR_LOG("Encoder::open: header 写入成功");

    HDR_LOG("Encoder::open: 全部完成, codec=mpeg4, %dx%d", out_w, out_h);
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

    if (frame) frame->pts = frame_count_ * frame_duration_;

    int ret = avcodec_send_frame(enc_ctx_, frame);
    if (ret < 0 && ret != AVERROR_EOF) return ret;

    AVPacket* pkt = av_packet_alloc();
    // 循环接收：编码器可能为一个输入帧产生多个输出包（B 帧 / lookahead）
    while (true) {
        ret = avcodec_receive_packet(enc_ctx_, pkt);
        if (ret == AVERROR(EAGAIN)) break;
        if (ret < 0) { av_packet_free(&pkt); return ret; }
        pkt->stream_index = 0;
        // mpeg4 编码器不自动设 duration
        if (pkt->duration <= 0) {
            pkt->duration = frame_duration_;
        }
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
    HDR_LOG("Encoder: finalize 完成, 共写入%d帧", frame_count_);
    return 0;
}

void Encoder::cancel() {
    cancelled_ = true;
}
