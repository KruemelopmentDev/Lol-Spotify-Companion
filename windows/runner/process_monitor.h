#ifndef PROCESS_MONITOR_H_
#define PROCESS_MONITOR_H_

#include <windows.h>
#include <Wbemidl.h>
#include <comdef.h>
#include <thread>
#include <atomic>
#include <string>
#include <memory>
#include <flutter/encodable_value.h>

#pragma comment(lib, "wbemuuid.lib")

// Forward declarations
namespace flutter {
    template <typename T>
    class MethodChannel;
}

class ProcessMonitor {
public:
    ProcessMonitor(flutter::MethodChannel<flutter::EncodableValue>* channel);
    ~ProcessMonitor();
    
    void StartMonitoring(const std::string& process_name);
    void StopMonitoring();

private:
    void MonitorLoop();
    bool InitializeWMI();
    void CleanupWMI();
    
    flutter::MethodChannel<flutter::EncodableValue>* channel_;
    std::atomic<bool> monitoring_;
    std::thread monitor_thread_;
    std::string target_process_;
    
    IWbemLocator* locator_;
    IWbemServices* services_;
};

// WMI Event Sink
class EventSink : public IWbemObjectSink {
public:
    EventSink(flutter::MethodChannel<flutter::EncodableValue>* channel, const std::string& process_name);
    virtual ~EventSink();

    STDMETHODIMP QueryInterface(REFIID riid, void** ppv);
    STDMETHODIMP_(ULONG) AddRef();
    STDMETHODIMP_(ULONG) Release();

    STDMETHODIMP Indicate(LONG lObjectCount, IWbemClassObject** apObjArray);
    STDMETHODIMP SetStatus(LONG lFlags, HRESULT hResult, BSTR strParam, IWbemClassObject* pObjParam);

private:
    LONG ref_count_;
    flutter::MethodChannel<flutter::EncodableValue>* channel_;
    std::string target_process_;
};

#endif  // PROCESS_MONITOR_H_