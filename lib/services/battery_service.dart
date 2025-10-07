import 'dart:async';
import 'dart:math' as math;

/// 電量管理服務 - 負責管理各設備的電量
class BatteryService {
  // 電量狀態
  int _systemBatteryLevel = 75;
  int _esp32BatteryLevel = 85;
  int _headsetBatteryLevel = 90;

  // 電量狀態流
  final StreamController<Map<String, int>> _batteryController =
      StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get batteryStream => _batteryController.stream;

  Timer? _batteryTimer;

  /// 啟動電量模擬
  void startBatterySimulation() {
    _batteryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateBatteryLevels();
    });
  }

  /// 停止電量模擬
  void stopBatterySimulation() {
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  /// 更新電量狀態
  void _updateBatteryLevels() {
    // 模擬電量消耗
    if (_systemBatteryLevel > 0) {
      _systemBatteryLevel = math.max(0, _systemBatteryLevel - 1);
    }
    if (_esp32BatteryLevel > 0) {
      _esp32BatteryLevel = math.max(0, _esp32BatteryLevel - 2);
    }
    if (_headsetBatteryLevel > 0) {
      _headsetBatteryLevel = math.max(0, _headsetBatteryLevel - 1);
    }

    // 發送電量更新
    _batteryController.add({
      'system': _systemBatteryLevel,
      'esp32': _esp32BatteryLevel,
      'headset': _headsetBatteryLevel,
    });
  }

  /// 獲取系統電量
  int get systemBatteryLevel => _systemBatteryLevel;

  /// 獲取ESP32電量
  int get esp32BatteryLevel => _esp32BatteryLevel;

  /// 獲取耳機電量
  int get headsetBatteryLevel => _headsetBatteryLevel;

  /// 設置電量（用於測試）
  void setBatteryLevel(String device, int level) {
    switch (device) {
      case 'system':
        _systemBatteryLevel = level;
        break;
      case 'esp32':
        _esp32BatteryLevel = level;
        break;
      case 'headset':
        _headsetBatteryLevel = level;
        break;
    }
    _batteryController.add({
      'system': _systemBatteryLevel,
      'esp32': _esp32BatteryLevel,
      'headset': _headsetBatteryLevel,
    });
  }

  /// 重置電量（用於測試）
  void resetBatteryLevels() {
    _systemBatteryLevel = 75;
    _esp32BatteryLevel = 85;
    _headsetBatteryLevel = 90;
    _batteryController.add({
      'system': _systemBatteryLevel,
      'esp32': _esp32BatteryLevel,
      'headset': _headsetBatteryLevel,
    });
  }

  /// 釋放資源
  void dispose() {
    stopBatterySimulation();
    _batteryController.close();
  }
}
