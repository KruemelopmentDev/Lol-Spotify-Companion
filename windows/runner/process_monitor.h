#ifndef PROCESS_MONITOR_H_
#define PROCESS_MONITOR_H_

#include <windows.h>
#include <Wbemidl.h>
#include <comdef.h>
#include <thread>
#include <atomic>
#include <string>
#include <memory>
#include <queue>
#include <mutex>
#include <flutter/encodable_value.h>

#pragma comment(lib, "wbemuuid.lib")

// Forward declarations
namespace flutter {
    template <typename T>
    class MethodChannel;
}

// Forward declare EventSink
class EventSink;

class ProcessMonitor {
public:
    ProcessMonitor(flutter::MethodChannel<flutter::EncodableValue>* channel, HWND window);
    ~ProcessMonitor();
    
    void StartMonitoring(const std::string& process_name);
    void StopMonitoring();
    void ProcessPendingNotifications();

private:
    friend class EventSink;  // Allow EventSink to access QueueNotification
    
    void MonitorLoop();
    bool InitializeWMI();
    void CleanupWMI();
    void QueueNotification(const std::string& process_name);
    
    flutter::MethodChannel<flutter::EncodableValue>* channel_;
    HWND window_;
    std::atomic<bool> monitoring_;
    std::thread monitor_thread_;
    std::string target_process_;
    
    // Thread-safe queue for notifications
    std::queue<std::string> notification_queue_;
    std::mutex queue_mutex_;
    
    IWbemLocator* locator_;
    IWbemServices* services_;
    
    static constexpr UINT WM_PROCESS_STARTED = WM_USER + 1;
};

// WMI Event Sink
class EventSink : public IWbemObjectSink {
public:
    EventSink(ProcessMonitor* monitor, const std::string& process_name);
    virtual ~EventSink();

    STDMETHODIMP QueryInterface(REFIID riid, void** ppv);
    STDMETHODIMP_(ULONG) AddRef();
    STDMETHODIMP_(ULONG) Release();

    STDMETHODIMP Indicate(LONG lObjectCount, IWbemClassObject** apObjArray);
    STDMETHODIMP SetStatus(LONG lFlags, HRESULT hResult, BSTR strParam, IWbemClassObject* pObjParam);

private:
    LONG ref_count_;
    ProcessMonitor* monitor_;
    std::string target_process_;
};

#endif  // PROCESS_MONITOR_H_