import 'dart:async';
import 'dart:typed_data';
import 'mjpeg_client.dart';
import 'imu_udp.dart';
import '../models/imu_packet.dart';

/// 連接狀態管理服務 - 負責管理所有設備的連接狀態
class ConnectionService {
  // 服務實例
  final MjpegClient _mjpeg = MjpegClient('http://192.168.4.1:81/stream');
  final ImuUdpService _imu = ImuUdpService(port: 9000);

  // 串流訂閱
  StreamSubscription<Uint8List>? _frameSub;
  StreamSubscription<ImuPacket>? _imuSub;

  // 連接狀態
  bool _cameraConnected = false;
  bool _imuConnected = false;

  // 連接狀態流
  final StreamController<Map<String, bool>> _connectionController =
      StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get connectionStream =>
      _connectionController.stream;

  /// 啟動所有服務
  Future<void> startServices() async {
    // 啟動 IMU
    await _imu.start();
    _imuSub = _imu.stream.listen(
      (pkt) {
        // 暫時註釋掉自動連接，用於測試
        // setState(() {
        //   _imuConnected = true;
        // });
      },
      onError: (e) {
        _updateConnectionStatus('imu', false);
      },
    );

    // 啟動 MJPEG
    _frameSub = _mjpeg.start().listen(
      (jpeg) {
        // 暫時註釋掉自動連接，用於測試
        // _cameraConnected = true;
      },
      onError: (e) {
        _updateConnectionStatus('camera', false);
      },
    );
  }

  /// 更新連接狀態
  void _updateConnectionStatus(String device, bool connected) {
    switch (device) {
      case 'camera':
        _cameraConnected = connected;
        break;
      case 'imu':
        _imuConnected = connected;
        break;
    }

    _connectionController.add({
      'camera': _cameraConnected,
      'imu': _imuConnected,
    });
  }

  /// 手動設置連接狀態（用於測試）
  void setConnectionStatus(String device, bool connected) {
    _updateConnectionStatus(device, connected);
  }

  /// 獲取攝影機連接狀態
  bool get isCameraConnected => _cameraConnected;

  /// 獲取IMU連接狀態
  bool get isImuConnected => _imuConnected;

  /// 獲取Aura連接狀態（攝影機和IMU都連接）
  bool get isAuraConnected => _cameraConnected && _imuConnected;

  /// 停止所有服務
  void stopServices() {
    _frameSub?.cancel();
    _imuSub?.cancel();
    _mjpeg.stop();
    _imu.stop();
  }

  /// 釋放資源
  void dispose() {
    stopServices();
    _connectionController.close();
  }
}
