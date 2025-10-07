import 'dart:async';
import 'package:flutter/services.dart';

/// 音訊服務 - 負責檢測耳機連接狀態
class AudioService {
  static const MethodChannel _platform = MethodChannel('com.auramap.audio');

  // 耳機連接狀態流
  final StreamController<bool> _headphoneController =
      StreamController<bool>.broadcast();
  Stream<bool> get headphoneStream => _headphoneController.stream;

  Timer? _detectionTimer;
  bool _isHeadphoneConnected = false;

  /// 啟動耳機檢測
  void startHeadphoneDetection() {
    // 立即檢查一次
    _checkHeadphoneStatus();

    // 定期檢查（每秒一次）
    _detectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkHeadphoneStatus();
    });
  }

  /// 停止耳機檢測
  void stopHeadphoneDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  /// 檢查耳機連接狀態
  Future<void> _checkHeadphoneStatus() async {
    try {
      // 使用平台通道檢測耳機連接
      final bool isConnected = await _platform.invokeMethod(
        'isHeadphoneConnected',
      );

      if (_isHeadphoneConnected != isConnected) {
        _isHeadphoneConnected = isConnected;
        _headphoneController.add(isConnected);
      }
    } catch (e) {
      // 如果檢測失敗，使用模擬檢測
      print('耳機檢測錯誤: $e，使用模擬檢測');
      _simulateHeadphoneDetection();
    }
  }

  /// 模擬耳機檢測（用於測試）
  void _simulateHeadphoneDetection() {
    // 預設為未連接
    if (_isHeadphoneConnected) {
      _isHeadphoneConnected = false;
      _headphoneController.add(false);
    }
  }

  /// 手動切換耳機連接狀態（用於測試）
  void toggleHeadphoneConnection() {
    _isHeadphoneConnected = !_isHeadphoneConnected;
    _headphoneController.add(_isHeadphoneConnected);
  }

  /// 獲取當前耳機連接狀態
  bool get isHeadphoneConnected => _isHeadphoneConnected;

  /// 釋放資源
  void dispose() {
    stopHeadphoneDetection();
    _headphoneController.close();
  }
}
