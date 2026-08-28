#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>

#include <audioclient.h>
#include <mmdeviceapi.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

namespace {

constexpr int kExitOk = 0;
constexpr int kExitUsage = 1;
constexpr int kExitNoDevice = 2;
constexpr int kExitFailed = 3;
constexpr int kExitSilent = 4;

constexpr int kSampleRate = 16000;
constexpr int kChannels = 1;
constexpr int kBitsPerSample = 16;
constexpr int kMaxSeconds = 300;
constexpr REFERENCE_TIME kBufferDuration = 10000000;
constexpr int kVadFrameMilliseconds = 20;
constexpr int kVadMinimumConsecutiveFrames = 3;
constexpr double kVadRmsThreshold = 0.012;

struct ComScope {
  bool ok = false;
  ComScope() { ok = SUCCEEDED(CoInitializeEx(nullptr, COINIT_MULTITHREADED)); }
  ~ComScope() {
    if (ok) CoUninitialize();
  }
};

template <typename T>
void SafeRelease(T*& value) {
  if (value) {
    value->Release();
    value = nullptr;
  }
}

WAVEFORMATEX DesiredFormat() {
  WAVEFORMATEX format = {};
  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = kChannels;
  format.nSamplesPerSec = kSampleRate;
  format.wBitsPerSample = kBitsPerSample;
  format.nBlockAlign = format.nChannels * format.wBitsPerSample / 8;
  format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;
  format.cbSize = 0;
  return format;
}

bool WriteWav(const std::wstring& path, const std::vector<int16_t>& samples) {
  FILE* file = nullptr;
  if (_wfopen_s(&file, path.c_str(), L"wb") != 0 || !file) return false;

  const uint32_t dataBytes =
      static_cast<uint32_t>(samples.size() * sizeof(int16_t));
  const uint32_t byteRate = kSampleRate * kChannels * kBitsPerSample / 8;
  const uint16_t blockAlign = kChannels * kBitsPerSample / 8;
  const uint32_t riffSize = 36 + dataBytes;
  const uint32_t fmtSize = 16;
  const uint16_t pcm = 1;
  const uint16_t channels = kChannels;
  const uint32_t sampleRate = kSampleRate;
  const uint16_t bits = kBitsPerSample;

  fwrite("RIFF", 1, 4, file);
  fwrite(&riffSize, 4, 1, file);
  fwrite("WAVEfmt ", 1, 8, file);
  fwrite(&fmtSize, 4, 1, file);
  fwrite(&pcm, 2, 1, file);
  fwrite(&channels, 2, 1, file);
  fwrite(&sampleRate, 4, 1, file);
  fwrite(&byteRate, 4, 1, file);
  fwrite(&blockAlign, 2, 1, file);
  fwrite(&bits, 2, 1, file);
  fwrite("data", 1, 4, file);
  fwrite(&dataBytes, 4, 1, file);
  fwrite(samples.data(), 1, dataBytes, file);
  fclose(file);
  return true;
}

bool IsWorkstationUnlocked() {
  HDESK desktop = OpenInputDesktop(0, FALSE, DESKTOP_SWITCHDESKTOP);
  if (!desktop) return false;
  const bool unlocked = SwitchDesktop(desktop) != FALSE;
  CloseDesktop(desktop);
  return unlocked;
}

bool HasVoiceActivity(const std::vector<int16_t>& samples) {
  const size_t frameSamples =
      static_cast<size_t>(kSampleRate * kVadFrameMilliseconds / 1000);
  int consecutiveFrames = 0;
  for (size_t start = 0; start < samples.size(); start += frameSamples) {
    const size_t end = std::min(start + frameSamples, samples.size());
    double squaredSum = 0;
    for (size_t index = start; index < end; ++index) {
      const double normalized =
          static_cast<double>(samples[index]) / INT16_MAX;
      squaredSum += normalized * normalized;
    }
    const double rms = std::sqrt(squaredSum / (end - start));
    consecutiveFrames = rms >= kVadRmsThreshold ? consecutiveFrames + 1 : 0;
    if (consecutiveFrames >= kVadMinimumConsecutiveFrames) return true;
  }
  return false;
}

int Record(const std::wstring& path, int seconds) {
  if (!IsWorkstationUnlocked()) return kExitFailed;
  IMMDeviceEnumerator* enumerator = nullptr;
  IMMDevice* device = nullptr;
  IAudioClient* client = nullptr;
  IAudioCaptureClient* capture = nullptr;
  WAVEFORMATEX* mixFormat = nullptr;
  int result = kExitFailed;

  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                              CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                              reinterpret_cast<void**>(&enumerator)))) {
    return kExitFailed;
  }

  if (FAILED(enumerator->GetDefaultAudioEndpoint(eCapture, eConsole,
                                                 &device))) {
    SafeRelease(enumerator);
    return kExitNoDevice;
  }

  do {
    if (FAILED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                reinterpret_cast<void**>(&client)))) {
      break;
    }

    WAVEFORMATEX format = DesiredFormat();
    const DWORD flags = AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                        AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
    if (FAILED(client->Initialize(AUDCLNT_SHAREMODE_SHARED, flags,
                                  kBufferDuration, 0, &format, nullptr))) {
      break;
    }
    if (FAILED(client->GetService(__uuidof(IAudioCaptureClient),
                                  reinterpret_cast<void**>(&capture)))) {
      break;
    }
    if (FAILED(client->Start())) break;

    std::vector<int16_t> samples;
    samples.reserve(static_cast<size_t>(kSampleRate) * seconds);
    const size_t wanted = static_cast<size_t>(kSampleRate) * seconds;
    bool interrupted = false;

    while (samples.size() < wanted) {
      if (!IsWorkstationUnlocked()) {
        interrupted = true;
        break;
      }
      UINT32 packetFrames = 0;
      if (FAILED(capture->GetNextPacketSize(&packetFrames))) break;
      if (packetFrames == 0) {
        Sleep(10);
        continue;
      }

      BYTE* data = nullptr;
      UINT32 frames = 0;
      DWORD bufferFlags = 0;
      if (FAILED(capture->GetBuffer(&data, &frames, &bufferFlags, nullptr,
                                    nullptr))) {
        break;
      }

      if (bufferFlags & AUDCLNT_BUFFERFLAGS_SILENT) {
        samples.insert(samples.end(), frames, 0);
      } else {
        const int16_t* pcmData = reinterpret_cast<const int16_t*>(data);
        samples.insert(samples.end(), pcmData, pcmData + frames);
      }
      capture->ReleaseBuffer(frames);
    }

    client->Stop();
    if (interrupted) break;
    if (samples.empty()) break;
    if (samples.size() > wanted) samples.resize(wanted);

    if (!WriteWav(path, samples)) break;
    result = HasVoiceActivity(samples) ? kExitOk : kExitSilent;
  } while (false);

  if (mixFormat) CoTaskMemFree(mixFormat);
  SafeRelease(capture);
  SafeRelease(client);
  SafeRelease(device);
  SafeRelease(enumerator);
  return result;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc < 3) {
    fwprintf(stderr, L"usage: audio_capture <output.wav> <seconds>\n");
    return kExitUsage;
  }

  const int seconds = _wtoi(argv[2]);
  if (seconds <= 0 || seconds > kMaxSeconds) return kExitUsage;

  ComScope com;
  if (!com.ok) return kExitFailed;
  return Record(argv[1], seconds);
}
