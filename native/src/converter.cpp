#include "hdr_converter.h"
#include "pipeline.h"
#include <cstring>

extern "C" {

EXPORT void* converter_create() {
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