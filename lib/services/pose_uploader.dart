/*

📤 功能概要：
此類別負責將「單張關鍵畫面（JPEG）」與「一段 IMU 批次資料」
上傳至後端伺服器的指定端點（通常為 /pose）。

🧠 上傳內容：
- 使用 JSON 格式（Content-Type: application/json）
- 內含：
  • timestamp：上傳當下的本地時間（毫秒）
  • keyframe_jpeg_base64：影像轉成 Base64 字串
  • imu：IMU 資料陣列（每筆含 t、ax/ay/az、gx/gy/gz）

🧱 使用方式：
final uploader = PoseUploader('http://<server>/pose');
await uploader.postKeyframeAndImu(jpeg: frameBytes, imuBatch: imuList);

⚙️ 注意事項：
- Base64 編碼的影像體積約為原始大小的 1.3 倍；
  若影像過大，建議後端設定合理的上傳限制。
- 若伺服器回傳狀態碼 >= 300，會丟出例外（Exception）。
- 若需要頻繁上傳，可考慮重用同一個 PoseUploader 實例。


*/

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/imu_packet.dart';

class PoseUploader {
  final Uri endpoint; // 例如 http://<server>/pose
  final http.Client _client = http.Client();

  PoseUploader(String url) : endpoint = Uri.parse(url);

  Future<void> postKeyframeAndImu({
    required Uint8List jpeg,
    required List<ImuPacket> imuBatch,
  }) async {
    final body = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'keyframe_jpeg_base64': base64Encode(jpeg),
      'imu':
          imuBatch
              .map(
                (p) => {
                  't': p.tMs,
                  'ax': p.axG,
                  'ay': p.ayG,
                  'az': p.azG,
                  'gx': p.gxDps,
                  'gy': p.gyDps,
                  'gz': p.gzDps,
                },
              )
              .toList(),
    });
    final resp = await _client.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (resp.statusCode >= 300) {
      throw Exception('pose upload failed: ${resp.statusCode} ${resp.body}');
    }
  }
}
