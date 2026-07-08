#include "pipeline.h"
#include "debug_log.h"
#include "pixel_utils.h"
#include "gamut_mapper.h"
#include <cstring>
#include <iostream>
extern "C" {
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
}

Pipeline::Pipeline()
    : cancelled_(false), initialized_(false) {
    memset(&params_, 0, sizeof(params_));
    memset(&hdr_meta_, 0, sizeof(hdr_meta_));
    params_.peak_luminance = 1000.0;
    params_.saturation = 1.0;
    params_.crf = 23;
}

Pipeline::~Pipeline() {
    cancel();
    if (worker_thread_.joinable()) worker_thread_.join();
}

int Pipeline::open(const std::string& input_path) {
    HDR_LOG("Pipeline::open: %s", input_path.c_str());
    int ret = decoder_.open(input_path);
    if (ret < 0) {
        HDR_LOG("Pipeline::open: 解码器打开失败 ret=%d", ret);
        return ret;
    }

    hdr_meta_ = HDRAnalyzer::analyze(
        decoder_.getFormatContext(),
        decoder_.getCodecContext(),
        decoder_.getVideoStreamIndex());

    auto* codecpar = decoder_.getFormatContext()
        ->streams[decoder_.getVideoStreamIndex()]->codecpar;
    HDR_LOG("Pipeline::open: 成功, %dx%d pix=%d fps=%.2f frames=%d dur=%.1fs hdr=%d maxLum=%.0f",
            decoder_.getWidth(), decoder_.getHeight(),
            codecpar->format, decoder_.getFps(), decoder_.getFrameCount(),
            decoder_.getDurationSec(), hdr_meta_.hdr_type,
            hdr_meta_.max_luminance);
    HDR_LOG("Pipeline::open: 输入色彩 pri=%d trc=%d spc=%d range=%d",
            codecpar->color_primaries, codecpar->color_trc,
            codecpar->color_space, codecpar->color_range);

    initialized_ = true;
    return 0;
}

void Pipeline::close() {
    // 不再调用 cancel()——取消由 converter_cancel 显式触发
    if (worker_thread_.joinable()) worker_thread_.join();
    decoder_.close();
    initialized_ = false;
}

int Pipeline::getFrameCount() const {
    return decoder_.getFrameCount();
}

VideoInfo Pipeline::getInfo() const {
    VideoInfo info = {};
    info.width = decoder_.getWidth();
    info.height = decoder_.getHeight();
    info.fps = decoder_.getFps();
    info.frame_count = getFrameCount();
    info.duration_sec = decoder_.getDurationSec();
    info.is_hdr = hdr_meta_.hdr_type;
    info.max_luminance = hdr_meta_.max_luminance;
    info.pixel_format = decoder_.getPixelFormat();
    return info;
}

void Pipeline::setParams(ConvertParams params) {
    params_ = params;
}

int Pipeline::swFrameToBgra(AVFrame* frame, uint8_t* out_buffer, int* w, int* h) {
    int out_w = frame->width;
    int out_h = frame->height;
    *w = out_w;
    *h = out_h;

    uint8_t* dst_data[4] = {nullptr};
    int dst_linesize[4] = {0};
    if (av_image_alloc(dst_data, dst_linesize, out_w, out_h,
                       AV_PIX_FMT_BGRA, 1) < 0) {
        return -1;
    }

    SwsContext* sws = sws_getContext(
        frame->width, frame->height, (AVPixelFormat)frame->format,
        out_w, out_h, AV_PIX_FMT_BGRA,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws) return -1;

    sws_scale(sws, frame->data, frame->linesize, 0, frame->height,
              dst_data, dst_linesize);

    int size = dst_linesize[0] * out_h;
    memcpy(out_buffer, dst_data[0], size);

    sws_freeContext(sws);
    av_freep(&dst_data[0]);
    return 0;
}

int Pipeline::getFrame(uint8_t* out_buffer, int64_t timestamp_us,
                        int* out_width, int* out_height) {
    if (!initialized_) return -1;

    AVFrame* frame = decoder_.seekAndDecode(timestamp_us);
    if (!frame) return -1;

    int ret = 0;
    if (hdr_meta_.hdr_type > 0) {
        ret = processHdrToSdr(frame);
    }

    if (ret == 0) {
        ret = swFrameToBgra(frame, out_buffer, out_width, out_height);
    }

    av_frame_free(&frame);
    return ret;
}

int Pipeline::processHdrToSdr(AVFrame* frame) {
    // HDR→SDR 始终做色调压缩，色域压缩取决于目标色彩空间
    ToneMapParams tmp = {};
    tmp.peak_luminance = params_.peak_luminance > 0
        ? params_.peak_luminance : hdr_meta_.max_luminance;
    tmp.exposure = params_.exposure;
    tmp.saturation = params_.saturation;

    bool target_is_bt709 = (params_.target_color_space == 0);
    // 目标 BT.709: BT.2020→BT.709 色域压缩 + BT.709 YUV 矩阵
    // 目标 BT.2020: 保持 BT.2020 色域，仅压缩亮度（SDR BT.2020）
    int gamut_dir     = target_is_bt709 ? 1 : 0;
    int dst_colorspace = target_is_bt709 ? AVCOL_SPC_BT709 : AVCOL_SPC_BT2020_NCL;
    int src_csp        = target_is_bt709 ? 0 : 1;
    tone_mapper_.apply(frame, tmp, AVCOL_SPC_BT2020_NCL, dst_colorspace, gamut_dir);

    AVFrame* dst = av_frame_alloc();
    int pix_fmt = target_is_bt709 ? AV_PIX_FMT_YUV420P : AV_PIX_FMT_YUV420P10LE;
    dst->format = pix_fmt;
    dst->width = frame->width;
    dst->height = frame->height;
    if (av_frame_get_buffer(dst, 32) < 0) {
        av_frame_free(&dst);
        return -1;
    }

    color_converter_.convert(frame, dst, src_csp, params_.target_color_space, false);

    av_frame_unref(frame);
    av_frame_move_ref(frame, dst);
    av_frame_free(&dst);
    return 0;
}

int Pipeline::processSdrToHdr(AVFrame* frame) {
    bool is_hdr_target = (params_.target_color_space == 1);

    // 一次转换到 float，全程在 float 域处理，避免中间 YUV 截断
    AVFrame* flt = convertToFloatPlanar(frame);
    if (!flt) return -1;
    debugFloatFrameStats("SDR→HDR step1 float", flt, 0);

    if (is_hdr_target) {
        // ── 真正的 SDR→HDR ──
        InvToneMapParams itmp = {};
        itmp.target_peak = params_.peak_luminance > 0
            ? params_.peak_luminance : 1000.0;
        itmp.exposure = params_.exposure;
        itmp.saturation = params_.saturation;

        // 逆色调映射扩展（SDR→HDR，值可超过 1.0）
        inv_tone_mapper_.applyOnFloat(flt, itmp);
        debugFloatFrameStats("SDR→HDR step2 expand", flt, 0);

        // 色域扩展：BT.709 → BT.2020
        gamutConvert709To2020(flt);
        debugFloatFrameStats("SDR→HDR step3 gamut709→2020", flt, 0);
    }
    // SDR→SDR: 跳过色调映射，BT.709→BT.709 无需 expand/compress/gamut

    // 分配输出帧
    AVFrame* dst = av_frame_alloc();
    int pix_fmt = is_hdr_target ? AV_PIX_FMT_YUV420P10LE : AV_PIX_FMT_YUV420P;
    dst->format = pix_fmt;
    dst->width = frame->width;
    dst->height = frame->height;
    if (av_frame_get_buffer(dst, 32) < 0) {
        av_frame_free(&dst);
        av_frame_free(&flt);
        return -1;
    }

    int src_csp = is_hdr_target ? 1 : 0;
    color_converter_.convert(flt, dst, src_csp, params_.target_color_space, is_hdr_target);

    av_frame_unref(frame);
    av_frame_move_ref(frame, dst);
    av_frame_free(&dst);
    av_frame_free(&flt);
    return 0;
}

void Pipeline::conversionThread(const std::string& output_path,
                                 ProgressCallback progress_cb,
                                 CompletionCallback complete_cb,
                                 void* user_data) {
    // 自动模式：根据输入视频的 HDR 类型决定转换方向
    //   SDR 输入（hdr_type=0）→ SDR→HDR
    //   HDR 输入（hdr_type>0）→ HDR→SDR
    if (params_.auto_mode) {
        params_.direction = (hdr_meta_.hdr_type > 0) ? 0 : 1;
        HDR_LOG("转换线程: 自动模式 hdr_type=%d → 方向=%d (%s)",
            hdr_meta_.hdr_type, params_.direction,
            params_.direction == 0 ? "HDR→SDR" : "SDR→HDR");
    }

    // HDR 输出标志：仅 SDR→HDR 且目标 BT.2020 时才是真 HDR(PQ)
    bool is_hdr_output = (params_.direction == 1 && params_.target_color_space == 1);
    HDR_LOG("转换线程: 目标色彩=%d isHdr=%d pix=%s",
        params_.target_color_space, (int)is_hdr_output,
        is_hdr_output ? "10bit" : "8bit");

    HDR_LOG("转换线程: 开始, 打开编码器...");
    int ret = encoder_.open(output_path,
        decoder_.getCodecContext(),
        params_.encoder, params_.crf,
        params_.target_width, params_.target_height,
        params_.crop_left, params_.crop_right,
        params_.crop_top, params_.crop_bottom,
        params_.target_color_space,
        is_hdr_output);
    if (ret < 0) {
        HDR_LOG("转换线程: 编码器初始化失败 ret=%d", ret);
        if (complete_cb) complete_cb(0, "编码器初始化失败", user_data);
        return;
    }
    HDR_LOG("转换线程: 编码器已打开, 开始解码...");

    int total_frames = getFrameCount();
    int frame_idx = 0;

    HDR_LOG("转换线程: 总帧数=%d, 方向=%d", total_frames, params_.direction);

    // seek 到开头（丢弃解码出的第一帧，它已在 open() 时被解码过）
    AVFrame* firstFrame = decoder_.seekAndDecode(0);
    if (firstFrame) av_frame_free(&firstFrame);

    while (!cancelled_) {
        AVFrame* frame = decoder_.decodeNextFrame();
        if (!frame) break;

        if (params_.direction == 0) {
            ret = processHdrToSdr(frame);
        } else {
            ret = processSdrToHdr(frame);
        }

        if (ret == 0) {
            ret = encoder_.encodeFrame(frame);
        }

        av_frame_free(&frame);

        if (ret < 0 && ret != AVERROR(EAGAIN)) {
            HDR_LOG("转换线程: 帧%d处理失败 ret=%d", frame_idx, ret);
            break;
        }

        frame_idx++;
        if (progress_cb && total_frames > 0) {
            int pct = (int)(frame_idx * 100 / total_frames);
            progress_cb(pct, frame_idx, total_frames, user_data);
        }
    }

    HDR_LOG("转换线程: 帧循环结束, 已处理%d帧, 拷贝音频流...", frame_idx);

    // 从输入拷贝音频流到输出（不重新编码）
    AVFormatContext* input_ctx = decoder_.getFormatContext();
    AVFormatContext* output_ctx = encoder_.getFormatContext();
    int src_audio_idx = -1;
    for (unsigned i = 0; i < input_ctx->nb_streams; i++) {
        if (input_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            src_audio_idx = i;
            break;
        }
    }
    if (src_audio_idx >= 0) {
        AVStream* audio_out = avformat_new_stream(output_ctx, nullptr);
        avcodec_parameters_copy(audio_out->codecpar,
            input_ctx->streams[src_audio_idx]->codecpar);
        audio_out->time_base = input_ctx->streams[src_audio_idx]->time_base;
        int dst_audio_idx = audio_out->index;

        // seek 回文件开头只读音频包
        avformat_flush(input_ctx);
        avformat_seek_file(input_ctx, src_audio_idx, 0, 0,
            input_ctx->streams[src_audio_idx]->duration, 0);

        AVPacket* apkt = av_packet_alloc();
        while (av_read_frame(input_ctx, apkt) >= 0) {
            if (apkt->stream_index == src_audio_idx) {
                apkt->stream_index = dst_audio_idx;
                av_interleaved_write_frame(output_ctx, apkt);
            }
            av_packet_unref(apkt);
        }
        av_packet_free(&apkt);
        HDR_LOG("转换线程: 音频拷贝完成, stream=%d→%d", src_audio_idx, dst_audio_idx);
    } else {
        HDR_LOG("转换线程: 无音频流, 跳过");
    }

    HDR_LOG("转换线程: 冲刷编码器...");
    encoder_.finalize();

    if (cancelled_) {
        HDR_LOG("转换线程: 已被取消");
        if (complete_cb) complete_cb(0, "用户取消", user_data);
    } else {
        HDR_LOG("转换线程: 转换完成! 共%d帧", frame_idx);
        if (complete_cb) complete_cb(1, nullptr, user_data);
    }
}

int Pipeline::start(const std::string& output_path,
                     ProgressCallback progress_cb,
                     CompletionCallback complete_cb,
                     void* user_data) {
    if (!initialized_) return -1;

    HDR_LOG("Pipeline::start: 输出=%s, encoder=%d, crf=%d, %dx%d",
            output_path.c_str(), params_.encoder, params_.crf,
            decoder_.getWidth(), decoder_.getHeight());

    cancelled_ = false;
    try {
        worker_thread_ = std::thread(&Pipeline::conversionThread, this,
                                      output_path, progress_cb, complete_cb, user_data);
    } catch (...) {
        HDR_LOG("Pipeline::start: 创建线程失败");
        return -1;
    }
    HDR_LOG("Pipeline::start: 工作线程已创建");
    return 0;
}

void Pipeline::cancel() {
    cancelled_ = true;
    encoder_.cancel();
}