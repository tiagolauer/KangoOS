#include "whisper.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {

constexpr int kExitOk = 0;
constexpr int kExitUsage = 1;
constexpr int kExitBadModel = 2;
constexpr int kExitBadAudio = 3;
constexpr int kExitNoSpeech = 4;
constexpr int kExitFailed = 5;

constexpr int kExpectedSampleRate = 16000;
constexpr int kWavHeaderBytes = 44;
constexpr size_t kMaxTranscriptLength = 4000;

bool ReadPcm16Wav(const char* path, std::vector<float>& out) {
  FILE* file = nullptr;
  if (fopen_s(&file, path, "rb") != 0 || !file) return false;

  uint8_t header[kWavHeaderBytes];
  if (fread(header, 1, sizeof(header), file) != sizeof(header)) {
    fclose(file);
    return false;
  }
  if (memcmp(header, "RIFF", 4) != 0 || memcmp(header + 8, "WAVE", 4) != 0) {
    fclose(file);
    return false;
  }

  uint32_t sampleRate = 0;
  uint16_t channels = 0;
  uint16_t bits = 0;
  memcpy(&channels, header + 22, sizeof(channels));
  memcpy(&sampleRate, header + 24, sizeof(sampleRate));
  memcpy(&bits, header + 34, sizeof(bits));
  if (sampleRate != kExpectedSampleRate || channels != 1 || bits != 16) {
    fclose(file);
    return false;
  }

  std::vector<int16_t> samples;
  int16_t chunk[4096];
  size_t read = 0;
  while ((read = fread(chunk, sizeof(int16_t), 4096, file)) > 0) {
    samples.insert(samples.end(), chunk, chunk + read);
  }
  fclose(file);
  if (samples.empty()) return false;

  out.resize(samples.size());
  for (size_t i = 0; i < samples.size(); i++) {
    out[i] = static_cast<float>(samples[i]) / 32768.0f;
  }
  return true;
}

std::string Trim(const std::string& value) {
  const size_t begin = value.find_first_not_of(" \t\r\n");
  if (begin == std::string::npos) return "";
  const size_t end = value.find_last_not_of(" \t\r\n");
  return value.substr(begin, end - begin + 1);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 3) {
    fprintf(stderr, "usage: whisper_transcribe <model.bin> <audio.wav>\n");
    return kExitUsage;
  }

  std::vector<float> audio;
  if (!ReadPcm16Wav(argv[2], audio)) return kExitBadAudio;

  whisper_context_params contextParams = whisper_context_default_params();
  contextParams.use_gpu = false;
  whisper_context* context =
      whisper_init_from_file_with_params(argv[1], contextParams);
  if (!context) return kExitBadModel;

  whisper_full_params params =
      whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  params.print_special = false;
  params.translate = false;
  params.language = nullptr;
  params.no_timestamps = true;
  params.single_segment = false;

  int result = kExitFailed;
  if (whisper_full(context, params, audio.data(),
                   static_cast<int>(audio.size())) == 0) {
    std::string transcript;
    const int segments = whisper_full_n_segments(context);
    for (int i = 0; i < segments; i++) {
      transcript += whisper_full_get_segment_text(context, i);
    }
    transcript = Trim(transcript);
    if (transcript.empty()) {
      result = kExitNoSpeech;
    } else {
      if (transcript.size() > kMaxTranscriptLength) {
        transcript.resize(kMaxTranscriptLength);
      }
      fwrite(transcript.data(), 1, transcript.size(), stdout);
      result = kExitOk;
    }
  }

  whisper_free(context);
  return result;
}
