/*

🎥 功能概要：
以 HTTP GET 連接 ESP32-CAM 等裝置提供的
`multipart/x-mixed-replace; boundary=...` MJPEG 串流，
解析每個 part，並把其中的 JPEG 影像（Uint8List）逐幀輸出成 Stream。

🧠 運作流程：
1) 建立 http.Client，送出 GET 請求
2) 從 response 的 Content-Type 解析 boundary
3) 連續讀取位元串流，尋找 `--boundary ... --boundary` 的分段
4) 以 `\r\n\r\n` (CRLFCRLF) 分隔出 header 與 body
5) 將 body（JPEG）推送到 Stream<Uint8List>

🧱 預設行為與特點：
- 使用 broadcast Stream，允許多處同時訂閱
- `start()` 啟動解析；`stop()` 會取消訂閱/關閉 client/關閉 controller
- 若 Content-Type 無 boundary，預設使用 'frame'

⚙️ 常見擴充點（可依需求加上）：
- 加入超時/重連（例如 server 端中斷、自動 backoff）
- 驗證 Content-Length（避免殘缺影像）
- 記憶體防護：限制 buffer 最大長度，避免異常時無限成長
- FPS 節流（只取每 N 幀，減少 UI 更新頻率）
- HTTPS 或基本驗證（若有安全性需求）

*/

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// 解析 multipart/x-mixed-replace; boundary=... 的 MJPEG 串流，逐幀輸出 JPEG bytes。
class MjpegClient {
  final Uri url;
  http.Client? _client;
  StreamController<Uint8List>? _controller;
  StreamSubscription<List<int>>? _sub;

  MjpegClient(String urlStr) : url = Uri.parse(urlStr);

  /// 開始連線並回傳逐幀 JPEG 的 Stream。
  /// 注意：呼叫者應保存回傳的 Stream 以便訂閱；停止時請呼叫 [stop]。
  Stream<Uint8List> start() {
    _client = http.Client();

    // broadcast 讓多個監聽者可以同時訂閱；onCancel 觸發時會自動 stop
    _controller = StreamController.broadcast(onCancel: stop);

    () async {
      final req = http.Request('GET', url);
      final resp = await _client!.send(req);

      // 解析 boundary（e.g., "multipart/x-mixed-replace; boundary=frame"）
      final ct = resp.headers['content-type'] ?? '';
      final bMatch = RegExp(r'boundary=([^;]+)').firstMatch(ct);
      final boundary = bMatch != null ? bMatch.group(1)!.trim() : 'frame';
      final boundaryBytes = ascii.encode('--$boundary');

      // 累積資料的暫存區（逐塊 chunk 追加，找出完整 part）
      final buffer = <int>[];

      // 監聽位元流；每來一個 chunk 就嘗試「掏」出完整的 frame
      _sub = resp.stream.listen(
        (chunk) {
          buffer.addAll(chunk);
          _drainFrames(buffer, boundaryBytes);
        },
        onError: (e, st) => _controller?.addError(e, st),
        onDone: stop,
      );
    }();

    return _controller!.stream;
  }

  /// 從暫存 buffer 中反覆尋找 `boundary ... boundary` 的完整分段，解析並發出 JPEG。
  void _drainFrames(List<int> buffer, List<int> boundary) {
    // 連續找 boundary，擷取 header + JPEG payload
    while (true) {
      final start = _indexOf(buffer, boundary, 0);
      if (start < 0) return;

      final next = _indexOf(buffer, boundary, start + boundary.length);
      if (next < 0) return; // 尚未到下一個 boundary，資料不完整，等待更多 chunk

      // 擷取一個 part 區塊（去掉前後 boundary）
      final part = buffer.sublist(start + boundary.length, next);

      // 將已處理的資料丟掉，避免 buffer 無限成長
      buffer.removeRange(0, next);

      // 解析 header/body；以 CRLFCRLF 分隔
      final sep = _indexOf(part, const [13, 10, 13, 10], 0); // \r\n\r\n
      if (sep < 0) continue; // 不完整（header 還沒收齊）

      // 若要檢查 Content-Length 可在此解析 headersBytes
      // final headersBytes = part.sublist(0, sep);
      final body = part.sublist(sep + 4);

      // ✅ 發出 JPEG（若需要篩選/降頻，可在這裡做）
      if (body.isNotEmpty) {
        _controller?.add(Uint8List.fromList(body));
      }
    }
  }

  /// 在 data 中由 [start] 位置起尋找 pattern，回傳起始索引；找不到回傳 -1。
  int _indexOf(List<int> data, List<int> pattern, int start) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool ok = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  /// 停止串流並釋放資源（取消訂閱、關閉 HTTP client 與 controller）。
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;

    _client?.close();
    _client = null;

    await _controller?.close();
    _controller = null;
  }
}
