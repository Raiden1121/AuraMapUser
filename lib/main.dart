import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'services/mjpeg_client.dart';
import 'services/imu_udp.dart';
import 'models/imu_packet.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuraMap 室內導航系統',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF16213E),
      ),
      home: const AuraMapScreen(),
    );
  }
}

class AuraMapScreen extends StatefulWidget {
  const AuraMapScreen({super.key});

  @override
  State<AuraMapScreen> createState() => _AuraMapScreenState();
}

class _AuraMapScreenState extends State<AuraMapScreen> {
  // 連線服務
  final _mjpeg = MjpegClient('http://192.168.4.1:81/stream');
  final _imu = ImuUdpService(port: 9000);

  // 串流訂閱
  StreamSubscription<Uint8List>? _frameSub;
  StreamSubscription<ImuPacket>? _imuSub;

  // 資料狀態
  Uint8List? _lastFrame;
  bool _cameraConnected = false;
  bool _imuConnected = true; // 測試用：模擬IMU已連接
  bool _audioConnected = true; // 測試用：模擬耳機已連接

  // 模擬數據（實際應用時替換為真實數據）
  String _currentBuilding = "資訊大樓";
  String _currentFloor = "3F";
  double _nextWaypointDistance = 15.2;
  double _nextWaypointAngle = 45.0;
  double _destinationDistance = 85.5;
  int _batteryLevel = 75;
  int _esp32BatteryLevel = 85;
  int _headsetBatteryLevel = 90;

  // AI 對話記錄
  final List<ChatMessage> _chatMessages = [
    ChatMessage(isUser: false, text: "歡迎使用 AuraMap 導航系統"),
    ChatMessage(isUser: true, text: "我要去資訊大樓 305 教室"),
    ChatMessage(isUser: false, text: "正在為您規劃路線..."),
    ChatMessage(isUser: false, text: "請向前直走 15 公尺，然後右轉"),
  ];

  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startServices();
    _simulateDataUpdates();
  }

  // 啟動服務
  Future<void> _startServices() async {
    // 啟動 IMU
    await _imu.start();
    _imuSub = _imu.stream.listen(
      (pkt) {
        setState(() {
          _imuConnected = true;
        });
      },
      onError: (e) {
        setState(() => _imuConnected = false);
      },
    );

    // 啟動 MJPEG
    _frameSub = _mjpeg.start().listen(
      (jpeg) {
        setState(() {
          _lastFrame = jpeg;
          _cameraConnected = true;
        });
      },
      onError: (e) {
        setState(() => _cameraConnected = false);
      },
    );
  }

  // 模擬數據更新（實際應用時替換為真實數據源）
  void _simulateDataUpdates() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          // 模擬距離更新
          if (_nextWaypointDistance > 0) {
            _nextWaypointDistance = math.max(0, _nextWaypointDistance - 2.5);
          }
          if (_destinationDistance > 0) {
            _destinationDistance = math.max(0, _destinationDistance - 2.5);
          }
          // 模擬角度變化
          _nextWaypointAngle = (_nextWaypointAngle + 5) % 360;
          // 模擬電量消耗
          if (_batteryLevel > 0) {
            _batteryLevel = math.max(0, _batteryLevel - 1);
          }
          if (_esp32BatteryLevel > 0) {
            _esp32BatteryLevel = math.max(0, _esp32BatteryLevel - 2);
          }
          if (_headsetBatteryLevel > 0) {
            _headsetBatteryLevel = math.max(0, _headsetBatteryLevel - 1);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    _imuSub?.cancel();
    _mjpeg.stop();
    _imu.stop();
    _messageController.dispose();
    super.dispose();
  }

  // 發送訊息
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add(ChatMessage(isUser: true, text: text));
      // 模擬 AI 回應
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _chatMessages.add(
              ChatMessage(isUser: false, text: "收到您的訊息：「$text」，正在處理中..."),
            );
          });
        }
      });
    });
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 頂部狀態列
            _buildStatusBar(),

            // 測試按鈕（僅用於測試）
            _buildTestButtons(),

            // 攝影畫面
            _buildCameraView(),

            // 位置與導航資訊
            _buildNavigationInfo(),

            // AI 對話
            Expanded(child: _buildChatInterface()),
          ],
        ),
      ),
    );
  }

  // 測試按鈕（僅用於測試連接狀態）
  Widget _buildTestButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cameraConnected = !_cameraConnected;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cameraConnected ? Colors.green : Colors.red,
                ),
                child: Text(
                  _cameraConnected ? '攝影機: 已連接' : '攝影機: 未連接',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _imuConnected = !_imuConnected;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _imuConnected ? Colors.green : Colors.red,
                ),
                child: Text(
                  _imuConnected ? 'IMU: 已連接' : 'IMU: 未連接',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _audioConnected = !_audioConnected;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _audioConnected ? Colors.green : Colors.red,
                ),
                child: Text(
                  _audioConnected ? '耳機: 已連接' : '耳機: 未連接',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              // Aura電量顯示狀態指示
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      (_cameraConnected && _imuConnected)
                          ? Colors.green
                          : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (_cameraConnected && _imuConnected)
                      ? 'Aura電量: 顯示'
                      : 'Aura電量: 隱藏',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 頂部狀態列
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          // 標題
          Row(
            children: [
              const Text(
                'AuraMap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 設備連接狀態和電量
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Aura電量 + 攝影機
              Row(
                children: [
                  if (_cameraConnected && _imuConnected) ...[
                    _buildSingleBatteryIndicator(level: _esp32BatteryLevel),
                    const SizedBox(width: 8),
                  ],
                  _buildConnectionStatus(
                    icon: Icons.videocam,
                    label: '攝影機',
                    connected: _cameraConnected,
                  ),
                ],
              ),
              _buildConnectionStatus(
                icon: Icons.sensors,
                label: 'IMU',
                connected: _imuConnected,
              ),
              // 耳機 + 耳機電量
              Row(
                children: [
                  _buildConnectionStatus(
                    icon: Icons.headset,
                    label: '耳機',
                    connected: _audioConnected,
                  ),
                  if (_audioConnected) ...[
                    const SizedBox(width: 8),
                    _buildSingleBatteryIndicator(level: _headsetBatteryLevel),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 連接狀態指示器
  Widget _buildConnectionStatus({
    required IconData icon,
    required String label,
    required bool connected,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: connected ? Colors.green : Colors.red),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: connected ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 單個電量指示器
  Widget _buildSingleBatteryIndicator({required int level}) {
    final color =
        level > 30 ? Colors.green : (level > 15 ? Colors.orange : Colors.red);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          level > 60
              ? Icons.battery_full
              : (level > 30 ? Icons.battery_5_bar : Icons.battery_2_bar),
          color: color,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$level%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // 攝影畫面
  Widget _buildCameraView() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(8),
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.camera_alt, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '攝影機畫面',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _cameraConnected ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _cameraConnected ? '已連接' : '未連接',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      _lastFrame == null
                          ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.videocam_off,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '等待影像串流...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _lastFrame!,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                              ),
                              // 準心標記
                              Center(
                                child: Icon(
                                  Icons.center_focus_strong,
                                  color: Colors.green.withOpacity(0.6),
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 導航資訊
  Widget _buildNavigationInfo() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 位置資訊
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                const Text(
                  '目前位置',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.business, color: Colors.blue[300], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_currentBuilding - $_currentFloor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 導航指示
            Row(
              children: [
                const Icon(Icons.navigation, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text(
                  '導航資訊',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 導航項目 - 水平排列
            Row(
              children: [
                // 下一個 waypoint
                Expanded(
                  child: _buildNavigationItem(
                    icon: Icons.flag,
                    label: '下一個導航點',
                    distance: _nextWaypointDistance,
                    angle: _nextWaypointAngle,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                // 終點
                Expanded(
                  child: _buildNavigationItem(
                    icon: Icons.location_searching,
                    label: '終點',
                    distance: _destinationDistance,
                    angle: null,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 導航項目
  Widget _buildNavigationItem({
    required IconData icon,
    required String label,
    required double distance,
    double? angle,
    required Color color,
  }) {
    return Container(
      height: 120, // 固定高度確保兩個項目大小一致
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            '${distance.toStringAsFixed(1)}m',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (angle != null)
            _buildDirectionIndicator(angle, color)
          else
            const SizedBox(height: 30), // 為沒有方向指示器的項目預留空間
        ],
      ),
    );
  }

  // 方向指示器
  Widget _buildDirectionIndicator(double angle, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Icon(Icons.navigation, color: color, size: 16),
      ),
    );
  }

  // AI 對話介面
  Widget _buildChatInterface() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assistant, color: Colors.purple, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'AI 助理',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 對話記錄
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final message = _chatMessages[index];
                    return _buildChatBubble(message);
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 輸入框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '輸入訊息...',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, size: 20),
                  color: Colors.blue,
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 對話氣泡
  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        decoration: BoxDecoration(
          color:
              message.isUser
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.purple.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: const TextStyle(fontSize: 11),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// 對話訊息模型
class ChatMessage {
  final bool isUser;
  final String text;

  ChatMessage({required this.isUser, required this.text});
}
