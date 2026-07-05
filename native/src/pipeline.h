#ifndef PIPELINE_H
#define PIPELINE_H

#include <string>
#include <atomic>
#include <thread>
#include "hdr_converter.h"
#include "decoder.h"
#include "hdr_analyzer.h"
#include "tone_mapper.h"
#include "inverse_tone_mapper.h"
#include "color_converter.h"
#include "hdr_metadata_injector.h"
#include "encoder.h"

class Pipeline {
public:
    Pipeline();
    ~Pipeline();

    int open(const std::string& input_path);
    void close();
    int getFrameCount() const;
    VideoInfo getInfo() const;
    void setParams(ConvertParams params);
    int getFrame(uint8_t* out_buffer, int64_t timestamp_us,
                 int* out_width, int* out_height);
    int start(const std::string& output_path,
              ProgressCallback progress_cb,
              CompletionCallback complete_cb,
              void* user_data);
    void cancel();

private:
    void conversionThread(const std::string& output_path,
                          ProgressCallback progress_cb,
                          CompletionCallback complete_cb,
                          void* user_data);
    int processHdrToSdr(AVFrame* frame);
    int processSdrToHdr(AVFrame* frame);
    int swFrameToBgra(AVFrame* frame, uint8_t* out_buffer, int* w, int* h);

    Decoder decoder_;
    HDRAnalyzer analyzer_;
    ToneMapper tone_mapper_;
    InverseToneMapper inv_tone_mapper_;
    ColorConverter color_converter_;
    HDRMetadataInjector metadata_injector_;
    Encoder encoder_;

    ConvertParams params_;
    HDRMetadata hdr_meta_;
    std::atomic<bool> cancelled_;
    std::thread worker_thread_;
    bool initialized_;
};

#endif