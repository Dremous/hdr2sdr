### Task 4: C++ 公共 API 头文�?
**Files:**
- Create: `native/include/hdr_converter.h`
- Create: `native/CMakeLists.txt`

**Interfaces:**
- Produces: C 风格 API 声明，与 dart:ffi 绑定对应

- [ ] **Step 1: 创建 native/include/hdr_converter.h**

```c
#ifndef HDR_CONVERTER_H
#define HDR_CONVERTER_H

#include <stdint.h>

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

typedef struct {
    int width;
    int height;
    double fps;
    int64_t frame_count;
    double duration_sec;
    int is_hdr;              // 0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
    double max_luminance;
    int pixel_format;
} VideoInfo;

typedef struct {
    int direction;           // 0=HDR→SDR, 1=SDR→HDR
    int auto_mode;
    int preset_style;        // 0=standard, 1=vivid, 2=cinematic, 3=custom
    double peak_luminance;
    double exposure;
    double saturation;
    int target_color_space;  // 0=BT.709, 1=BT.2020, 2=DCI-P3
    int encoder;             // 0=H.264, 1=H.265, 2=AV1
    int crf;
    int target_width;
    int target_height;
    int crop_left;
    int crop_right;
    int crop_top;
    int crop_bottom;
} ConvertParams;

typedef void (*ProgressCallback)(int percent, int64_t current_frame,
                                  int64_t total_frames, void* user_data);
typedef void (*CompletionCallback)(int success, const char* error_msg,
                                    void* user_data);

EXPORT void* converter_create();
EXPORT void  converter_destroy(void* handle);
EXPORT int   converter_open(void* handle, const char* input_path);
EXPORT void  converter_close(void* handle);
EXPORT int   converter_get_frame_count(void* handle);
EXPORT void  converter_get_info(void* handle, VideoInfo* out_info);
EXPORT void  converter_set_params(void* handle, ConvertParams params);
EXPORT int   converter_get_frame(void* handle, uint8_t* out_buffer,
                                  int64_t timestamp_us, int* out_width,
                                  int* out_height);
EXPORT int   converter_start(void* handle, const char* output_path,
                              ProgressCallback progress_cb,
                              CompletionCallback complete_cb,
                              void* user_data);
EXPORT void  converter_cancel(void* handle);

#endif
```

- [ ] **Step 2: 创建 native/CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.16)
project(hdr_converter VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(AVCODEC REQUIRED libavcodec)
pkg_check_modules(AVFORMAT REQUIRED libavformat)
pkg_check_modules(AVUTIL REQUIRED libavutil)
pkg_check_modules(SWRESAMPLE REQUIRED libswresample)
pkg_check_modules(SWSCALE REQUIRED libswscale)

add_library(hdr_converter SHARED
    src/decoder.cpp
    src/hdr_analyzer.cpp
    src/tone_mapper.cpp
    src/inverse_tone_mapper.cpp
    src/color_converter.cpp
    src/hdr_metadata_injector.cpp
    src/encoder.cpp
    src/pipeline.cpp
)

target_include_directories(hdr_converter
    PUBLIC include
    PRIVATE src
    ${AVCODEC_INCLUDE_DIRS}
    ${AVFORMAT_INCLUDE_DIRS}
    ${AVUTIL_INCLUDE_DIRS}
    ${SWRESAMPLE_INCLUDE_DIRS}
    ${SWSCALE_INCLUDE_DIRS}
)

target_link_libraries(hdr_converter
    ${AVCODEC_LIBRARIES}
    ${AVFORMAT_LIBRARIES}
    ${AVUTIL_LIBRARIES}
    ${SWRESAMPLE_LIBRARIES}
    ${SWSCALE_LIBRARIES}
)

if(WIN32)
    set_target_properties(hdr_converter PROPERTIES PREFIX "")
endif()
```

- [ ] **Step 3: 创建 native/src/utils.h**

```cpp
#ifndef UTILS_H
#define UTILS_H

#include <string>

inline std::string avErrorToString(int errnum) {
    char buf[256];
    av_strerror(errnum, buf, sizeof(buf));
    return std::string(buf);
}

#endif
```

- [ ] **Step 4: 提交**

```bash
git add native/include/ native/CMakeLists.txt native/src/utils.h
git commit -m "feat: 添加 C++ 公共 API 头文件和 CMake 构建配置"
```

---

