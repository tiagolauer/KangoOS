#include <windows.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#include <cstdio>
#include <string>
#include <vector>

struct __declspec(uuid("5b0d3235-4dba-4d44-865e-8f1d0e4fd04d")) __declspec(
    novtable) IMemoryBufferByteAccess : ::IUnknown {
  virtual HRESULT __stdcall GetBuffer(uint8_t** value, uint32_t* capacity) = 0;
};

namespace {

constexpr int kExitOk = 0;
constexpr int kExitNoText = 1;
constexpr int kExitFailed = 2;
constexpr size_t kMaxCapturedTextLength = 4000;
constexpr int kBitsPerPixel = 32;
constexpr int kBytesPerPixel = 4;

struct Screenshot {
  std::vector<uint8_t> pixels;
  int width = 0;
  int height = 0;
};

bool CaptureWindow(HWND window, Screenshot& out) {
  RECT bounds = {};
  if (!IsWindow(window) || !GetWindowRect(window, &bounds)) return false;
  const int width = bounds.right - bounds.left;
  const int height = bounds.bottom - bounds.top;
  if (width <= 0 || height <= 0) return false;

  HDC screen = GetDC(nullptr);
  if (!screen) return false;

  HDC memory = CreateCompatibleDC(screen);
  HBITMAP bitmap = CreateCompatibleBitmap(screen, width, height);
  bool ok = false;

  if (memory && bitmap) {
    HGDIOBJ previous = SelectObject(memory, bitmap);
    if (PrintWindow(window, memory, PW_RENDERFULLCONTENT)) {
      BITMAPINFO info = {};
      info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
      info.bmiHeader.biWidth = width;
      info.bmiHeader.biHeight = -height;
      info.bmiHeader.biPlanes = 1;
      info.bmiHeader.biBitCount = kBitsPerPixel;
      info.bmiHeader.biCompression = BI_RGB;

      out.pixels.resize(static_cast<size_t>(width) * height * kBytesPerPixel);
      out.width = width;
      out.height = height;
      ok = GetDIBits(memory, bitmap, 0, height, out.pixels.data(), &info,
                     DIB_RGB_COLORS) != 0;
    }
    SelectObject(memory, previous);
  }

  if (bitmap) DeleteObject(bitmap);
  if (memory) DeleteDC(memory);
  ReleaseDC(nullptr, screen);
  return ok;
}

winrt::Windows::Graphics::Imaging::SoftwareBitmap ToSoftwareBitmap(
    const Screenshot& shot) {
  using namespace winrt::Windows::Graphics::Imaging;
  using namespace winrt::Windows::Storage::Streams;

  SoftwareBitmap bitmap(BitmapPixelFormat::Bgra8, shot.width, shot.height,
                        BitmapAlphaMode::Premultiplied);
  BitmapBuffer buffer = bitmap.LockBuffer(BitmapBufferAccessMode::Write);
  auto reference = buffer.CreateReference();

  auto access = reference.as<::IMemoryBufferByteAccess>();
  uint8_t* destination = nullptr;
  uint32_t capacity = 0;
  winrt::check_hresult(access->GetBuffer(&destination, &capacity));
  if (capacity < shot.pixels.size()) throw winrt::hresult_error(E_FAIL);
  memcpy(destination, shot.pixels.data(), shot.pixels.size());

  reference.Close();
  buffer.Close();
  return bitmap;
}

void WriteUtf8(const std::wstring& text) {
  const int needed = WideCharToMultiByte(CP_UTF8, 0, text.c_str(),
                                         static_cast<int>(text.size()), nullptr,
                                         0, nullptr, nullptr);
  if (needed <= 0) return;
  std::string utf8(static_cast<size_t>(needed), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                      utf8.data(), needed, nullptr, nullptr);
  fwrite(utf8.data(), 1, utf8.size(), stdout);
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  try {
    if (argc != 2) return kExitFailed;
    const auto value = _wcstoui64(argv[1], nullptr, 10);
    HWND window = reinterpret_cast<HWND>(value);
    if (!window || GetForegroundWindow() != window) return kExitNoText;
    winrt::init_apartment();

    Screenshot shot;
    if (!CaptureWindow(window, shot)) return kExitFailed;

    auto engine = winrt::Windows::Media::Ocr::OcrEngine::
        TryCreateFromUserProfileLanguages();
    if (!engine) return kExitFailed;

    auto result = engine.RecognizeAsync(ToSoftwareBitmap(shot)).get();
    if (GetForegroundWindow() != window) return kExitNoText;
    std::wstring text(result.Text());
    if (text.empty()) return kExitNoText;
    if (text.size() > kMaxCapturedTextLength) {
      text.resize(kMaxCapturedTextLength);
    }

    WriteUtf8(text);
    return kExitOk;
  } catch (...) {
    return kExitFailed;
  }
}
