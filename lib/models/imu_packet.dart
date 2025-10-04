/*
📦 功能概要：
此類別負責定義並解析 ESP32 端傳送的 IMU 封包格式。
IMU 封包由 ESP32 透過 UDP 傳送至手機（或伺服器），
內容包含加速度與陀螺儀的原始感測數值。

🧠 資料結構 (Little-Endian, 共 16 bytes)：
struct {
  uint16 seq;   // 封包序號 (0~65535)，可用來檢查漏包或順序
  uint16 t_ms;  // 裝置端時間戳 (毫秒)，循環遞增
  int16 ax;     // 加速度 X 軸原始值
  int16 ay;     // 加速度 Y 軸原始值
  int16 az;     // 加速度 Z 軸原始值
  int16 gx;     // 角速度 X 軸原始值
  int16 gy;     // 角速度 Y 軸原始值
  int16 gz;     // 角速度 Z 軸原始值
};

📐 換算公式 (以 MPU6050 為例，可依實際 IMU 修改)：
- 加速度 (g)：raw / 16384.0
- 角速度 (°/s)：raw / 131.0

📱 使用場景：
- Flutter 端從 UDP 收到 Uint8List raw bytes → 呼叫 ImuPacket.fromBytes()
- 顯示在畫面上或存入緩衝區進行後續分析

⚙️ 延伸應用：
- 可加入磁力計 (Mx,My,Mz)
- 可擴充 timestamp 為 32-bit (避免 overflow)
- 可新增校正參數 (offset, scale)

*/

import 'dart:typed_data';

/// 定義 IMU 封包結構與解析邏輯
class ImuPacket {
  // ====== 原始欄位 ======
  final int seq; // 封包序號，範圍 0..65535，用來檢查是否有漏包
  final int tMs; // 裝置的遞增時間戳 (毫秒)，範圍 0..65535
  final int ax, ay, az; // 加速度 (原始 int16 整數值)
  final int gx, gy, gz; // 角速度 (原始 int16 整數值)

  const ImuPacket({
    required this.seq,
    required this.tMs,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  /// 工廠建構子：從二進位 bytes 解析成 ImuPacket 物件
  ///
  /// 對應 C 結構：
  /// struct { uint16 seq; uint16 t_ms; int16 ax,ay,az; int16 gx,gy,gz; }
  ///
  /// 使用 little-endian（ESP32 常見設定）
  factory ImuPacket.fromBytes(Uint8List bytes) {
    // 檢查封包長度是否足夠
    if (bytes.lengthInBytes < 16) {
      throw FormatException('IMU packet too short: ${bytes.lengthInBytes}');
    }

    final bd = ByteData.sublistView(bytes);
    int off = 0;

    // 依序解析欄位（每次移動 offset）
    final seq = bd.getUint16(off, Endian.little);
    off += 2;
    final tMs = bd.getUint16(off, Endian.little);
    off += 2;
    final ax = bd.getInt16(off, Endian.little);
    off += 2;
    final ay = bd.getInt16(off, Endian.little);
    off += 2;
    final az = bd.getInt16(off, Endian.little);
    off += 2;
    final gx = bd.getInt16(off, Endian.little);
    off += 2;
    final gy = bd.getInt16(off, Endian.little);
    off += 2;
    final gz = bd.getInt16(off, Endian.little);

    return ImuPacket(
      seq: seq,
      tMs: tMs,
      ax: ax,
      ay: ay,
      az: az,
      gx: gx,
      gy: gy,
      gz: gz,
    );
  }

  // ====== 換算為物理單位 ======

  /// 加速度 (單位 g)
  double get axG => ax / 16384.0;
  double get ayG => ay / 16384.0;
  double get azG => az / 16384.0;

  /// 角速度 (單位 °/s)
  double get gxDps => gx / 131.0;
  double get gyDps => gy / 131.0;
  double get gzDps => gz / 131.0;
}
