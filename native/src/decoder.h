#ifndef DECODER_H
#define DECODER_H

#include <string>
#include <mutex>
#include <atomic>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
}

class Decoder {
public:
    Decoder();
    ~Decoder();

    int open(const std::string& filename);
    void close();
    bool isOpen() const;

    int getFrameCount() const;
    double getFps() const;
    int getWidth() const;
    int getHeight() const;
    double getDurationSec() const;
    int getPixelFormat() const;

    AVFrame* decodeNextFrame();
    AVFrame* seekAndDecode(int64_t timestamp_us);
    void flush();

    AVFormatContext* getFormatContext() const { return fmt_ctx_; }
    AVCodecContext* getCodecContext() const { return codec_ctx_; }
    int getVideoStreamIndex() const { return video_stream_index_; }

private:
    AVFormatContext* fmt_ctx_;
    AVCodecContext* codec_ctx_;
    int video_stream_index_;
    std::mutex mutex_;
};

#endif