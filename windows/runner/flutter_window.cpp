#include "flutter_window.h"

#include <optional>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include "flutter/generated_plugin_registrant.h"
#include "process_monitor.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Create method channel
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "process_monitor",
      &flutter::StandardMethodCodec::GetInstance()
  );

  // Create process monitor with window handle for message posting
  process_monitor_ = std::make_unique<ProcessMonitor>(channel_.get(), GetHandle());

  // Set up method call handler
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    
    if (call.method_name() == "startMonitoring") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
      
      if (arguments) {
        auto process_name_it = arguments->find(flutter::EncodableValue("processName"));
        
        if (process_name_it != arguments->end()) {
          const auto* process_name = std::get_if<std::string>(&process_name_it->second);
          
          if (process_name) {
            process_monitor_->StartMonitoring(*process_name);
            result->Success();
            return;
          }
        }
      }
      result->Error("INVALID_ARGUMENTS", "Process name required");
      
    } else if (call.method_name() == "stopMonitoring") {
      process_monitor_->StopMonitoring();
      result->Success();
      
    } else {
      result->NotImplemented();
    }
  });

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Handle our custom message for process notifications
  if (message == WM_PROCESS_STARTED && process_monitor_) {
    process_monitor_->ProcessPendingNotifications();
    return 0;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}