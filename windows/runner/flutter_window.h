#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// Forward declarations
class ProcessMonitor;

namespace flutter {
    class EncodableValue;
    template <typename T>
    class MethodChannel;
}

class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                        LPARAM const lparam) noexcept override;

 private:
  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<ProcessMonitor> process_monitor_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  
  static constexpr UINT WM_PROCESS_STARTED = WM_USER + 1;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_