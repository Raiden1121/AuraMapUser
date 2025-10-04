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
  bool _imuConnected = false;
  bool _audioConnected = false;

  // 模擬數據（實際應用時替換為真實數據）
  String _currentBuilding = "資訊大樓";
  String _currentFloor = "3F";
  double _nextWaypointDistance = 15.2;
  double _nextWaypointAngle = 45.0;
  double _destinationDistance = 85.5;
  int _batteryLevel = 75;

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
          // 標題和電量
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
              const Spacer(),
              _buildBatteryIndicator(),
            ],
          ),

          const SizedBox(height: 8),

          // 設備連接狀態
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildConnectionStatus(
                icon: Icons.videocam,
                label: '攝影機',
                connected: _cameraConnected,
              ),
              _buildConnectionStatus(
                icon: Icons.sensors,
                label: 'IMU',
                connected: _imuConnected,
              ),
              _buildConnectionStatus(
                icon: Icons.headset,
                label: '耳機',
                connected: _audioConnected,
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

  // 電量指示器
  Widget _buildBatteryIndicator() {
    final color =
        _batteryLevel > 30
            ? Colors.green
            : (_batteryLevel > 15 ? Colors.orange : Colors.red);

    return Row(
      children: [
        Icon(
          _batteryLevel > 60
              ? Icons.battery_full
              : (_batteryLevel > 30
                  ? Icons.battery_5_bar
                  : Icons.battery_2_bar),
          color: color,
          size: 24,
        ),
        const SizedBox(width: 5),
        Text(
          '$_batteryLevel%',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
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
          const SizedBox(height: 4),
          Text(
            '${distance.toStringAsFixed(1)}m',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (angle != null) ...[
            const SizedBox(height: 4),
            _buildDirectionIndicator(angle, color),
          ],
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
