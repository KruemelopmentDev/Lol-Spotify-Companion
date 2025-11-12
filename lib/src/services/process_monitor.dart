import 'package:flutter/services.dart';

class ProcessMonitor {
  static const platform = MethodChannel('process_monitor');

  Future<void> startMonitoring(String processName) async {
    try {
      await platform.invokeMethod('startMonitoring', {
        'processName': processName,
      });
    } catch (_) {}
  }

  Future<void> stopMonitoring() async {
    try {
      await platform.invokeMethod('stopMonitoring');
    } catch (_) {}
  }

  void setupListener(Function(String) onProcessStarted) {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onProcessStarted') {
        String processName = call.arguments;
        onProcessStarted(processName);
      }
    });
  }
}
