#include "pipeline.h"
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
    int ret = decoder_.open(input_path);
    if (ret < 0) return ret;

    hdr_meta_ = HDRAnalyzer::analyze(
        decoder_.getFormatContext(),
        decoder_.getCodecContext(),
        decoder_.getVideoStreamIndex());

    initialized_ = true;
    return 0;
}

void Pipeline::close() {
    cancel();
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
    av_image_alloc(dst_data, dst_linesize, out_w, out_h,
                   AV_PIX_FMT_BGRA, 1);

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
    ToneMapParams tmp = {};
    tmp.peak_luminance = params_.peak_luminance > 0
        ? params_.peak_luminance : hdr_meta_.max_luminance;
    tmp.exposure = params_.exposure;
    tmp.saturation = params_.saturation;
    tone_mapper_.apply(frame, tmp);

    // 转换到 BT.709
    AVFrame* dst = av_frame_alloc();
    dst->format = AV_PIX_FMT_YUV420P;
    dst->width = frame->width;
    dst->height = frame->height;
    av_frame_get_buffer(dst, 32);

    color_converter_.convert(frame, dst, 1, 0);

    av_frame_unref(frame);
    av_frame_move_ref(frame, dst);
    av_frame_free(&dst);
    return 0;
}

int Pipeline::processSdrToHdr(AVFrame* frame) {
    InvToneMapParams itmp = {};
    itmp.target_peak = params_.peak_luminance > 0
        ? params_.peak_luminance : 1000.0;
    itmp.exposure = params_.exposure;
    itmp.saturation = params_.saturation;
    inv_tone_mapper_.apply(frame, itmp);

    AVFrame* dst = av_frame_alloc();
    dst->format = AV_PIX_FMT_YUV420P;
    dst->width = frame->width;
    dst->height = frame->height;
    av_frame_get_buffer(dst, 32);

    color_converter_.convert(frame, dst, 0, 1);

    av_frame_unref(frame);
    av_frame_move_ref(frame, dst);
    av_frame_free(&dst);
    return 0;
}

void Pipeline::conversionThread(const std::string& output_path,
                                 ProgressCallback progress_cb,
                                 CompletionCallback complete_cb,
                                 void* user_data) {
    int ret = encoder_.open(output_path,
        decoder_.getCodecContext(),
        params_.encoder, params_.crf,
        params_.target_width, params_.target_height,
        params_.crop_left, params_.crop_right,
        params_.crop_top, params_.crop_bottom);
    if (ret < 0) {
        if (complete_cb) complete_cb(0, "编码器初始化失败", user_data);
        return;
    }

    int total_frames = getFrameCount();
    int frame_idx = 0;

    //  seek 到开头
    decoder_.seekAndDecode(0);

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

        if (ret < 0 && ret != AVERROR(EAGAIN)) break;

        frame_idx++;
        if (progress_cb && total_frames > 0) {
            int pct = (int)(frame_idx * 100 / total_frames);
            progress_cb(pct, frame_idx, total_frames, user_data);
        }
    }

    encoder_.finalize();

    if (cancelled_) {
        if (complete_cb) complete_cb(0, "用户取消", user_data);
    } else {
        if (complete_cb) complete_cb(1, nullptr, user_data);
    }
}

int Pipeline::start(const std::string& output_path,
                     ProgressCallback progress_cb,
                     CompletionCallback complete_cb,
                     void* user_data) {
    if (!initialized_) return -1;

    cancelled_ = false;
    try {
        worker_thread_ = std::thread(&Pipeline::conversionThread, this,
                                      output_path, progress_cb, complete_cb, user_data);
    } catch (...) {
        return -1;
    }
    return 0;
}

void Pipeline::cancel() {
    cancelled_ = true;
    encoder_.cancel();
}