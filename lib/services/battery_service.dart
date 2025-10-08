import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 電量管理服務 - 負責管理各設備的電量
class BatteryService {
  // 電量狀態流
  final StreamController<Map<String, dynamic>> _batteryController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get batteryStream => _batteryController.stream;

  Timer? _batteryTimer;
  Timer? _simulationTimer;
  BluetoothDevice? _connectedHeadset;
  bool _headsetSupportsBattery = false;
  StreamSubscription? _scanSubscription;
  int? _headsetBatteryLevel;
  int _esp32BatteryLevel = 0;
  bool _isSimulationMode = false;

  /// 開始監控電量
  Future<void> startBatteryMonitoring() async {
    try {
      // 檢查藍牙權限和狀態
      if (!await FlutterBluePlus.isAvailable) {
        print('藍牙不可用');
        _emitBatteryUpdate();
        return;
      }

      // 開始掃描藍牙設備
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (_isHeadset(result.device)) {
            _connectToHeadset(result.device);
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

      // 定期檢查電量
      _batteryTimer = Timer.periodic(Duration(seconds: 5), (_) {
        _updateBatteryLevels();
      });
    } catch (e) {
      print('啟動電量監控失敗: $e');
      _emitBatteryUpdate();
    }
  }

  /// 停止監控電量
  void stopBatteryMonitoring() {
    _batteryTimer?.cancel();
    _batteryTimer = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _connectedHeadset?.disconnect();
    _connectedHeadset = null;
    _headsetBatteryLevel = null;
    _headsetSupportsBattery = false;
    _emitBatteryUpdate();
  }

  /// 判斷設備是否為耳機
  bool _isHeadset(BluetoothDevice device) {
    final name = device.name.toLowerCase();
    return name.contains('headphone') ||
        name.contains('earphone') ||
        name.contains('headset') ||
        name.contains('airpods') ||
        name.contains('buds');
  }

  /// 連接耳機
  Future<void> _connectToHeadset(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedHeadset = device;

      // 檢查是否支援電量顯示
      final services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == '0000180F-0000-1000-8000-00805F9B34FB') {
          _headsetSupportsBattery = true;
          break;
        }
      }

      print('已連接耳機: ${device.name}');
      print('是否支援電量顯示: $_headsetSupportsBattery');

      await _updateBatteryLevels();
    } catch (e) {
      print('連接耳機失敗: $e');
    }
  }

  /// 檢查耳機電量
  Future<void> _updateBatteryLevels() async {
    if (_connectedHeadset == null || !_headsetSupportsBattery) {
      _emitBatteryUpdate();
      return;
    }

    try {
      final services = await _connectedHeadset!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == '0000180F-0000-1000-8000-00805F9B34FB') {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid.toString() == '00002A19-0000-1000-8000-00805F9B34FB') {
              final value = await c.read();
              if (value.isNotEmpty) {
                _headsetBatteryLevel = value[0];
                _emitBatteryUpdate();
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      print('讀取耳機電量失敗: $e');
      _emitBatteryUpdate();
    }
  }

  /// 發送電量更新
  void _emitBatteryUpdate() {
    _batteryController.add({
      'headsetConnected': _connectedHeadset != null,
      'headsetSupportsBattery': _headsetSupportsBattery,
      'esp32': _esp32BatteryLevel,
      if (_headsetBatteryLevel != null) 'headsetBattery': _headsetBatteryLevel,
    });
  }

  /// 設置ESP32電量
  void setEsp32BatteryLevel(int level) {
    _esp32BatteryLevel = level;
    _emitBatteryUpdate();
  }

  /// 獲取ESP32電量
  int get esp32BatteryLevel => _esp32BatteryLevel;

  /// 獲取當前耳機電量
  int get headsetBatteryLevel => _headsetBatteryLevel ?? 0;

  /// 耳機是否支援電量顯示
  bool get supportsBatteryLevel => _headsetSupportsBattery;

  /// 耳機是否已連接
  bool get isHeadsetConnected => _connectedHeadset != null;

  /// 開始 ESP32 電量模擬（用於測試）
  void startBatterySimulation() {
    _isSimulationMode = true;
    _esp32BatteryLevel = 100;
    _simulationTimer = Timer.periodic(Duration(seconds: 10), (_) {
      if (_esp32BatteryLevel > 0) {
        _esp32BatteryLevel = _esp32BatteryLevel - 1;
      }
      _emitBatteryUpdate();
    });
  }

  /// 停止 ESP32 電量模擬
  void stopBatterySimulation() {
    _isSimulationMode = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _esp32BatteryLevel = 0;
    _emitBatteryUpdate();
  }

  /// 釋放資源
  void dispose() {
    stopBatteryMonitoring();
    stopBatterySimulation();
    _batteryController.close();
  }
}
