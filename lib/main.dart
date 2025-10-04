/*

📱 功能概要：
此程式為 AuraMap 導航系統的最小可行版本 (MVP)，
主要目的是驗證 ESP32 影像串流與 IMU 感測資料
能否在手機端即時顯示與同步接收。

🧠 功能重點：
1️⃣ MJPEG 影像串流顯示
   - 透過 HTTP 連接 ESP32-CAM 的 MJPEG 串流端點
   - 即時顯示最新畫面 (每幀 JPEG)
   - URL: http://192.168.4.1:81/stream (可修改)

2️⃣ UDP IMU 資料接收
   - 透過 UDP socket 監聽 ESP32 傳送的 IMU 封包
   - 解析加速度與陀螺儀原始數值與換算值
   - 預設 port: 9000 (可修改)

3️⃣ IMU 緩衝區 (Ring Buffer)
   - 保留最近約 2 秒 IMU 資料（後續可用於上傳或對齊影像）

4️⃣ UI 顯示
   - 上半部顯示影像串流畫面
   - 下半部顯示最新 IMU 數據與 Start/Stop 按鈕

🧩 架構說明：
- services/mjpeg_client.dart → 負責 MJPEG 串流接收
- services/imu_udp.dart      → 負責接收並解析 UDP IMU 封包
- models/imu_packet.dart     → 定義 IMU 封包資料結構

⚙️ 使用方式：
1. 手機或筆電連上 ESP32 的 Wi-Fi (AP 模式)
2. 點擊「Start」開始接收影像與 IMU
3. 點擊「Stop」停止串流

🧱 可擴充方向：
- 上傳影像+IMU 到雲端 (FastAPI / Node server)
- 自動重連 / 錯誤提示
- IMU + 影像時間同步分析
- AI 物件辨識或導航語音提示

=========================================
*/

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'services/mjpeg_client.dart'; // 自訂服務：負責連 ESP32 MJPEG 串流
import 'services/imu_udp.dart'; // 自訂服務：負責接收 UDP IMU 封包
import 'models/imu_packet.dart'; // 自訂資料結構：IMU 封包解析

void main() {
  runApp(const MyApp()); // Flutter 入口：掛上根 Widget
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp：設定主題與首頁
    return MaterialApp(
      title: 'AuraMap',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MvpScreen(), // App 進入點 → MVP 畫面
    );
  }
}

/// MVP 畫面：示範「同時收影像 + 收 IMU」並即時顯示
class MvpScreen extends StatefulWidget {
  const MvpScreen({super.key});

  @override
  State<MvpScreen> createState() => _MvpScreenState();
}

class _MvpScreenState extends State<MvpScreen> {
  // === 連線/服務層 ===

  // 1) MJPEG client：固定串流 URL（AP 模式下，ESP32 常見為 192.168.4.1）
  //    若改 STA(連家中Wi-Fi) 或換埠，直接改這裡的 URL 即可。
  final _mjpeg = MjpegClient('http://192.168.4.1:81/stream');

  // 2) UDP IMU 服務：ESP32 將 IMU 封包以 UDP 發到此埠（9000）
  //    若要改埠或多路設備，可把 port 抽到設定或透過 UI 輸入。
  final _imu = ImuUdpService(port: 9000);

  // === 資源管理 ===

  // 這兩個 StreamSubscription 用於「開始接收」後訂閱資料流；停止時要取消訂閱以免記憶體外洩。
  StreamSubscription<Uint8List>? _frameSub; // 訂閱 MJPEG 畫面
  StreamSubscription<ImuPacket>? _imuSub; // 訂閱 IMU 封包

  // 最新資料暫存（UI 直接讀取這兩個展示）
  Uint8List? _lastFrame; // 最新一幀 JPEG bytes
  ImuPacket? _lastImu; // 最新一筆 IMU

  // IMU 環形緩衝區：保留最近 1~2 秒（依頻率彈性調整）。
  // 後續你若要「按下上傳 → 連同前後 N 秒 IMU + 對應影像」就能快速取用。
  final _imuRing = <ImuPacket>[];

  // UI 狀態旗標：是否正在運行（有訂閱串流）
  bool _running = false;

  /// 開始收資料：啟動 UDP + MJPEG，並訂閱兩個資料流
  Future<void> _start() async {
    if (_running) return; // 避免重複啟動
    setState(() => _running = true);

    // 1) 啟動 IMU（UDP）服務
    //    - _imu.start() 可能會做 socket 綁定與背景接收。
    //    - 之後用 _imu.stream.listen(...) 取得 ImuPacket。
    await _imu.start();
    _imuSub = _imu.stream.listen(
      (pkt) {
        _lastImu = pkt; // 更新最新封包（給 UI 顯示）
        _imuRing.add(pkt); // 推進環形緩衝

        // 控制緩衝大小：假設 60Hz → 保留 120 筆 ≈ 2 秒
        // 若 ESP32 端實際頻率不同，這個數字要一起調整。
        while (_imuRing.length > 120) {
          _imuRing.removeAt(0);
        }

        setState(() {}); // 有新 IMU 就刷新 UI（顯示數值）
      },
      // 錯誤處理與完成事件（建議加上，避免靜默失敗）
      onError: (e, st) {
        debugPrint('IMU stream error: $e');
        // 可選：出現錯誤自動停用或重試
      },
      cancelOnError: false,
    );

    // 2) 啟動 MJPEG 串流
    //    - _mjpeg.start() 會回傳 Stream<Uint8List>，每個事件是一幀 JPEG。
    //    - 這裡只保留「最新幀」在 _lastFrame，畫面顯示即時影像。
    _frameSub = _mjpeg.start().listen(
      (jpeg) {
        _lastFrame = jpeg; // 更新最新畫面
        setState(() {}); // 刷新影像
      },
      onError: (e, st) {
        debugPrint('MJPEG stream error: $e');
        // 可選：顯示錯誤、重連、退回「No video」等策略
      },
      cancelOnError: false,
    );
  }

  /// 停止收資料：取消訂閱 + 關閉底層連線/Socket
  Future<void> _stop() async {
    // 先把 MJPEG 停掉
    await _frameSub?.cancel();
    _frameSub = null;
    await _mjpeg.stop(); // 如內部有 HTTP client 或 Isolate，要記得關閉

    // 再把 IMU 停掉
    await _imuSub?.cancel();
    _imuSub = null;
    await _imu.stop(); // 關閉 UDP socket 等資源

    setState(() => _running = false);
  }

  @override
  void dispose() {
    // 畫面銷毀時保險關閉串流，避免：
    // - 背景仍在收資料（浪費電/網路）
    // - 記憶體外洩或重複訂閱
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 版面切兩半：上影像、下 IMU
    return Scaffold(
      appBar: AppBar(title: const Text('AuraMap MVP')),
      body: Column(
        children: [
          // 上半部：MJPEG 影像預覽
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child:
                  _lastFrame == null
                      // 尚未接到影像（或串流中斷）
                      ? const Text(
                        'No video',
                        style: TextStyle(color: Colors.white70),
                      )
                      // 顯示最新一幀 JPEG
                      : Image.memory(
                        _lastFrame!,
                        // gaplessPlayback：避免圖片來源替換時閃爍
                        gaplessPlayback: true,
                        fit: BoxFit.contain,
                      ),
            ),
          ),

          // 下半部：IMU 資料（最新一筆）
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyLarge!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顯示運行狀態（Start/Stop）
                    Text('Running: $_running'),
                    const SizedBox(height: 8),

                    if (_lastImu == null)
                      // 還沒收到任何 IMU 封包
                      const Text('No IMU packets')
                    else ...[
                      // 最新 IMU 封包的序號與時間戳（ESP32 端定義）
                      Text('Seq: ${_lastImu!.seq}  tMs: ${_lastImu!.tMs}'),
                      const SizedBox(height: 8),

                      // 原始值（一般為未換算的 ADC/LSB 或感測器原本單位）
                      Text(
                        'Accel raw: ax=${_lastImu!.ax} ay=${_lastImu!.ay} az=${_lastImu!.az}',
                      ),
                      Text(
                        'Gyro  raw: gx=${_lastImu!.gx} gy=${_lastImu!.gy} gz=${_lastImu!.gz}',
                      ),
                      const SizedBox(height: 8),

                      // 換算後（例如 axG：g，gxDps：度/秒）
                      // 注意：換算邏輯在 ImuPacket 內部（或解析器），
                      // 若 IMU 改機種/量程，記得同步調整係數。
                      Text(
                        'Accel g: ax=${_lastImu!.axG.toStringAsFixed(3)} '
                        'ay=${_lastImu!.ayG.toStringAsFixed(3)} '
                        'az=${_lastImu!.azG.toStringAsFixed(3)}',
                      ),
                      Text(
                        'Gyro dps: gx=${_lastImu!.gxDps.toStringAsFixed(2)} '
                        'gy=${_lastImu!.gyDps.toStringAsFixed(2)} '
                        'gz=${_lastImu!.gzDps.toStringAsFixed(2)}',
                      ),
                    ],

                    const Spacer(),

                    // 控制列：Start/Stop（依 _running 狀態做 disable）
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _running ? null : _start, // 避免重複 start
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _running ? _stop : null, // 只有運行中才可停
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
