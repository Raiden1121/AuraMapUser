/*

📡 功能概要：
此服務負責建立 UDP Socket，監聽 ESP32 端送出的 IMU 封包，
並解析成 ImuPacket 物件，透過 Stream 對外發送。

🧠 資料流程：
ESP32 ──(UDP/9000)──▶ Flutter App
   ↓
Raw bytes (16 bytes per packet)
   ↓
ImuPacket.fromBytes() 解析
   ↓
Stream<ImuPacket> 輸出給前端畫面或資料收集模組

🧱 預設設定：
- 綁定位址：0.0.0.0 (接收所有 IPv4)
- 監聽埠號：9000
- 每當收到 UDP 封包，就立即解析並推入 Stream

⚙️ 使用方式：
final imu = ImuUdpService(port: 9000);
await imu.start();
imu.stream.listen((pkt) => print(pkt.axG));

🧩 延伸功能建議：
- 加入錯誤計數與監控 (封包損失 / 頻率統計)
- 支援多來源裝置 (依 IP 分流)
- 自動重啟 socket 或 reconnect
- 支援 JSON / ProtoBuf 格式擴充

*/

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/imu_packet.dart';

/// IMU UDP 服務：建立 socket 接收 ESP32 傳來的二進位封包
class ImuUdpService {
  /// 綁定本機的網路位址（預設 0.0.0.0，表示接收所有介面）
  final InternetAddress bindAddress;

  /// 監聽埠號，ESP32 端應對應此 port
  final int port;

  /// 實際使用的 UDP socket
  RawDatagramSocket? _socket;

  /// 對外的封包流，使用 broadcast 方便多處同時監聽
  final _controller = StreamController<ImuPacket>.broadcast();

  /// 取得 IMU 資料流 (Stream)
  Stream<ImuPacket> get stream => _controller.stream;

  /// 建構子：可指定綁定位址與埠號
  ImuUdpService({InternetAddress? bindAddress, this.port = 9000})
    : bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  /// 啟動 UDP 監聽
  Future<void> start() async {
    if (_socket != null) return; // 若已啟動就略過

    // 綁定 socket 到指定埠號與位址
    _socket = await RawDatagramSocket.bind(bindAddress, port);

    // 監聽事件
    _socket!.listen((event) {
      // 當有資料可讀取
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();
        if (dg == null) return;

        try {
          // 嘗試將封包解析成 IMU 結構
          final pkt = ImuPacket.fromBytes(Uint8List.fromList(dg.data));

          // 若成功，推入資料流中
          _controller.add(pkt);
        } catch (e) {
          // 若封包長度錯誤或格式錯誤，直接丟棄
          // 可在此加入 debugPrint('Bad packet: $e');
        }
      }
    });
  }

  /// 停止服務：關閉 socket（但保留 stream）
  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    // 注意：不關閉 controller，讓重啟後可繼續使用同一個 stream
  }

  /// 完全釋放資源：關閉 socket + stream
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
