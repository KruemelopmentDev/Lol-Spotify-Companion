#include "process_monitor.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <iostream>

// EventSink Implementation
EventSink::EventSink(ProcessMonitor* monitor, const std::string& process_name)
    : ref_count_(1), monitor_(monitor), target_process_(process_name) {}

EventSink::~EventSink() {}

STDMETHODIMP EventSink::QueryInterface(REFIID riid, void** ppv) {
    if (riid == IID_IUnknown || riid == IID_IWbemObjectSink) {
        *ppv = static_cast<IWbemObjectSink*>(this);
        AddRef();
        return WBEM_S_NO_ERROR;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
}

STDMETHODIMP_(ULONG) EventSink::AddRef() {
    return InterlockedIncrement(&ref_count_);
}

STDMETHODIMP_(ULONG) EventSink::Release() {
    LONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) {
        delete this;
    }
    return count;
}

STDMETHODIMP EventSink::Indicate(LONG lObjectCount, IWbemClassObject** apObjArray) {
    for (LONG i = 0; i < lObjectCount; i++) {
        VARIANT vtProp;
        VariantInit(&vtProp);
        
        HRESULT hr = apObjArray[i]->Get(L"TargetInstance", 0, &vtProp, 0, 0);
        if (SUCCEEDED(hr) && vtProp.vt == VT_UNKNOWN) {
            IWbemClassObject* target_instance = nullptr;
            hr = vtProp.punkVal->QueryInterface(IID_IWbemClassObject, (void**)&target_instance);
            
            if (SUCCEEDED(hr)) {
                VARIANT vtName;
                VariantInit(&vtName);
                
                hr = target_instance->Get(L"Name", 0, &vtName, 0, 0);
                if (SUCCEEDED(hr) && vtName.vt == VT_BSTR) {
                    _bstr_t bstr(vtName.bstrVal);
                    std::string process_name = (char*)bstr;
                    
                    if (process_name == target_process_) {
                        // Queue the notification instead of calling directly
                        monitor_->QueueNotification(process_name);
                    }
                }
                VariantClear(&vtName);
                target_instance->Release();
            }
        }
        VariantClear(&vtProp);
    }
    return WBEM_S_NO_ERROR;
}

STDMETHODIMP EventSink::SetStatus(LONG lFlags, HRESULT hResult, BSTR strParam, IWbemClassObject* pObjParam) {
    return WBEM_S_NO_ERROR;
}

// ProcessMonitor Implementation
ProcessMonitor::ProcessMonitor(flutter::MethodChannel<flutter::EncodableValue>* channel, HWND window)
    : channel_(channel), window_(window), monitoring_(false), locator_(nullptr), services_(nullptr) {
    CoInitializeEx(0, COINIT_MULTITHREADED);
}

ProcessMonitor::~ProcessMonitor() {
    StopMonitoring();
    CoUninitialize();
}

void ProcessMonitor::QueueNotification(const std::string& process_name) {
    {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        notification_queue_.push(process_name);
    }
    
    // Post message to main window to process notifications on platform thread
    PostMessage(window_, WM_PROCESS_STARTED, 0, 0);
}

void ProcessMonitor::ProcessPendingNotifications() {
    std::queue<std::string> notifications;
    
    {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        notifications.swap(notification_queue_);
    }
    
    while (!notifications.empty()) {
        std::string process_name = notifications.front();
        notifications.pop();
        
        // Now we're on the platform thread, safe to call Flutter
        channel_->InvokeMethod(
            "onProcessStarted",
            std::make_unique<flutter::EncodableValue>(process_name)
        );
    }
}

void ProcessMonitor::StartMonitoring(const std::string& process_name) {
    if (monitoring_) {
        StopMonitoring();
    }
    
    target_process_ = process_name;
    monitoring_ = true;
    
    monitor_thread_ = std::thread(&ProcessMonitor::MonitorLoop, this);
}

void ProcessMonitor::StopMonitoring() {
    monitoring_ = false;
    
    if (monitor_thread_.joinable()) {
        monitor_thread_.join();
    }
    
    CleanupWMI();
}

bool ProcessMonitor::InitializeWMI() {
    HRESULT hr = CoInitializeSecurity(
        nullptr, -1, nullptr, nullptr,
        RPC_C_AUTHN_LEVEL_DEFAULT,
        RPC_C_IMP_LEVEL_IMPERSONATE,
        nullptr, EOAC_NONE, nullptr
    );
    
    if (FAILED(hr) && hr != RPC_E_TOO_LATE) {
        return false;
    }
    
    hr = CoCreateInstance(
        CLSID_WbemLocator, 0,
        CLSCTX_INPROC_SERVER,
        IID_IWbemLocator,
        (LPVOID*)&locator_
    );
    
    if (FAILED(hr)) {
        return false;
    }
    
    hr = locator_->ConnectServer(
        _bstr_t(L"ROOT\\CIMV2"),
        nullptr, nullptr, 0, 0, 0, 0, &services_
    );
    
    if (FAILED(hr)) {
        CleanupWMI();
        return false;
    }
    
    hr = CoSetProxyBlanket(
        services_,
        RPC_C_AUTHN_WINNT,
        RPC_C_AUTHZ_NONE,
        nullptr,
        RPC_C_AUTHN_LEVEL_CALL,
        RPC_C_IMP_LEVEL_IMPERSONATE,
        nullptr,
        EOAC_NONE
    );
    
    if (FAILED(hr)) {
        CleanupWMI();
        return false;
    }
    
    return true;
}

void ProcessMonitor::MonitorLoop() {
    if (!InitializeWMI()) {
        std::cerr << "Failed to initialize WMI" << std::endl;
        return;
    }
    
    EventSink* event_sink = new EventSink(this, target_process_);
    
    std::wstring query = L"SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'";
    
    HRESULT hr = services_->ExecNotificationQueryAsync(
        _bstr_t(L"WQL"),
        _bstr_t(query.c_str()),
        WBEM_FLAG_SEND_STATUS,
        nullptr,
        event_sink
    );
    
    if (FAILED(hr)) {
        std::cerr << "Failed to execute WMI query" << std::endl;
        event_sink->Release();
        return;
    }
    
    while (monitoring_) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    
    if (services_) {
        services_->CancelAsyncCall(event_sink);
    }
    
    event_sink->Release();
}

void ProcessMonitor::CleanupWMI() {
    if (services_) {
        services_->Release();
        services_ = nullptr;
    }
    
    if (locator_) {
        locator_->Release();
        locator_ = nullptr;
    }
}