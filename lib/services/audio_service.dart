import 'dart:async';
import 'package:flutter/services.dart';

/// 音訊服務 - 負責檢測耳機連接狀態
class AudioService {
  static const platform = MethodChannel(
    'com.auramap.audio/headphone_detection',
  );

  // 耳機連接狀態流
  final StreamController<bool> _headphoneController =
      StreamController<bool>.broadcast();
  Stream<bool> get headphoneStream => _headphoneController.stream;

  bool _isHeadphoneConnected = false;
  Timer? _detectionTimer;

  /// 啟動耳機檢測
  Future<void> startHeadphoneDetection() async {
    try {
      // 初始檢查
      await _checkHeadphoneStatus();

      // 定期檢查（每秒）
      _detectionTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _checkHeadphoneStatus(),
      );
    } catch (e) {
      print('啟動耳機檢測失敗: $e');
    }
  }

  /// 停止耳機檢測
  void stopHeadphoneDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  /// 檢查耳機連接狀態
  Future<void> _checkHeadphoneStatus() async {
    try {
      // 檢查是否有耳機輸出
      final bool hasHeadphones = await platform.invokeMethod(
        'isHeadsetConnected',
      );

      if (_isHeadphoneConnected != hasHeadphones) {
        _isHeadphoneConnected = hasHeadphones;
        _headphoneController.add(hasHeadphones);
        print('耳機狀態更新: ${hasHeadphones ? "已連接" : "未連接"}');
      }
    } catch (e) {
      print('檢查耳機狀態失敗: $e');
      // 對於不支援的平台，假設沒有耳機連接
      if (_isHeadphoneConnected != false) {
        _isHeadphoneConnected = false;
        _headphoneController.add(false);
        print('平台不支援耳機檢測，設定為未連接狀態');
      }
    }
  }

  /// 取得當前耳機連接狀態
  bool get isHeadphoneConnected => _isHeadphoneConnected;

  /// 釋放資源
  void dispose() {
    stopHeadphoneDetection();
    _headphoneController.close();
  }
}
