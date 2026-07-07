#include "hdr_converter.h"
#include "pipeline.h"
#include "debug_log.h"
#include <cstring>

// FFmpeg 日志回调：将 FFmpeg 内部日志重定向到 HDR_LOG
static void ffmpegLogCallback(void* /*avcl*/, int level, const char* fmt, va_list vl) {
    // 只输出 warning 及以上级别
    if (level > AV_LOG_WARNING) return;
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, vl);
    // 去掉末尾换行
    size_t len = strlen(buf);
    if (len > 0 && buf[len - 1] == '\n') buf[len - 1] = '\0';
    HDR_LOG("[ffmpeg] %s", buf);
}

extern "C" {

EXPORT void* converter_create() {
    // 设置 FFmpeg 日志回调（全局只设一次）
    static bool logCallbackSet = false;
    if (!logCallbackSet) {
        av_log_set_level(AV_LOG_WARNING);
        av_log_set_callback(ffmpegLogCallback);
        logCallbackSet = true;
    }
    return new Pipeline();
}

EXPORT void converter_destroy(void* handle) {
    delete static_cast<Pipeline*>(handle);
}

EXPORT int converter_open(void* handle, const char* input_path) {
    return static_cast<Pipeline*>(handle)->open(input_path);
}

EXPORT void converter_close(void* handle) {
    static_cast<Pipeline*>(handle)->close();
}

EXPORT int converter_get_frame_count(void* handle) {
    return static_cast<Pipeline*>(handle)->getFrameCount();
}

EXPORT void converter_get_info(void* handle, VideoInfo* out_info) {
    *out_info = static_cast<Pipeline*>(handle)->getInfo();
}

EXPORT void converter_set_params(void* handle, ConvertParams params) {
    static_cast<Pipeline*>(handle)->setParams(params);
}

EXPORT int converter_get_frame(void* handle, uint8_t* out_buffer,
                                int64_t timestamp_us, int* out_width,
                                int* out_height) {
    return static_cast<Pipeline*>(handle)->getFrame(
        out_buffer, timestamp_us, out_width, out_height);
}

EXPORT int converter_start(void* handle, const char* output_path,
                            ProgressCallback progress_cb,
                            CompletionCallback complete_cb,
                            void* user_data) {
    return static_cast<Pipeline*>(handle)->start(
        output_path, progress_cb, complete_cb, user_data);
}

EXPORT void converter_cancel(void* handle) {
    static_cast<Pipeline*>(handle)->cancel();
}

}