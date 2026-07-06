#ifndef HDR_CONVERTER_H
#define HDR_CONVERTER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

// 视频基本信息结构体
typedef struct {
    int width;               // 视频宽度（像素）
    int height;              // 视频高度（像素）
    double fps;              // 帧率
    int64_t frame_count;     // 总帧数
    double duration_sec;     // 总时长（秒）
    int is_hdr;              // HDR 类型：0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
    double max_luminance;    // 最大亮度（cd/m^2）
    int pixel_format;        // 像素格式标识
} VideoInfo;

// 转换参数结构体
typedef struct {
    int direction;           // 转换方向：0=HDR→SDR, 1=SDR→HDR
    int auto_mode;           // 自动模式开关
    int preset_style;        // 预设风格：0=standard, 1=vivid, 2=cinematic, 3=custom
    double peak_luminance;   // 峰值亮度（cd/m^2）
    double exposure;         // 曝光补偿
    double saturation;       // 饱和度
    int target_color_space;  // 目标色彩空间：0=BT.709, 1=BT.2020, 2=DCI-P3
    int encoder;             // 编码器：0=H.264, 1=H.265, 2=AV1, 3=H.264_HW, 4=H.265_HW
    int crf;                 // CRF 质量值
    int target_width;        // 目标宽度
    int target_height;       // 目标高度
    int crop_left;           // 左侧裁剪像素
    int crop_right;          // 右侧裁剪像素
    int crop_top;            // 顶部裁剪像素
    int crop_bottom;         // 底部裁剪像素
} ConvertParams;

// 进度回调函数指针类型
typedef void (*ProgressCallback)(int percent, int64_t current_frame,
                                  int64_t total_frames, void* user_data);

// 完成回调函数指针类型
typedef void (*CompletionCallback)(int success, const char* error_msg,
                                    void* user_data);

// 创建转换器实例
EXPORT void* converter_create();
// 销毁转换器实例
EXPORT void  converter_destroy(void* handle);
// 打开输入视频文件
EXPORT int   converter_open(void* handle, const char* input_path);
// 关闭输入视频文件
EXPORT void  converter_close(void* handle);
// 获取视频总帧数
EXPORT int   converter_get_frame_count(void* handle);
// 获取视频基本信息
EXPORT void  converter_get_info(void* handle, VideoInfo* out_info);
// 设置转换参数
EXPORT void  converter_set_params(void* handle, ConvertParams params);
// 获取指定时间戳的视频帧数据
EXPORT int   converter_get_frame(void* handle, uint8_t* out_buffer,
                                  int64_t timestamp_us, int* out_width,
                                  int* out_height);
// 启动转换任务
EXPORT int   converter_start(void* handle, const char* output_path,
                              ProgressCallback progress_cb,
                              CompletionCallback complete_cb,
                              void* user_data);
// 取消转换任务
EXPORT void  converter_cancel(void* handle);

#ifdef __cplusplus
}
#endif

#endif