import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shengwang_rtc_engine/agora_rtc_engine.dart';
import '../../utils/http_util.dart';
import '../../utils/api_util.dart';
import '../../utils/toast_util.dart';
import '../../controllers/mqtt_controller.dart';

class ControlWidget extends StatefulWidget {
  final String channelId; // [Robot_SN]_control
  final String robotId;   // Robot_SN

  const ControlWidget({
    Key? key,
    required this.channelId,
    required this.robotId,
  }) : super(key: key);

  @override
  State<ControlWidget> createState() => _ControlWidgetState();
}

class _ControlWidgetState extends State<ControlWidget> {
  static const String _appId = "afa2394f5e034fb4bd6a72593adbef57";
  final int robotUid = 10086; // The robot pushes video using UID 10086

  late RtcEngine _engine;
  late final MqttController _mqttController;

  bool _rtcJoined = false;
  bool _rtmConnected = false;
  bool _isInitError = false;

  String _statusMessage = "正在初始化音视频引擎...";
  String _shengwangToken = "";

  final GlobalKey _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initEngineAndRtm();
  }

  Future<String> getShengwangToken() async {
    Completer<String> completer = Completer<String>();
    HttpUtil.getInstance()?.post(ApiUtil.shengWangToken, {
      'roomName': widget.channelId,
    }, (data) {
      _shengwangToken = data ?? '';
      completer.complete(_shengwangToken);
    }, (msg, code) {
      ToastUtil.show(msg.toString());
      completer.completeError(msg ?? '获取Token失败');
    });
    return completer.future;
  }

  Future<void> _initEngineAndRtm() async {
    try {
      // 1. Fetch token first
      setState(() {
        _statusMessage = "正在获取安全令牌 (Token)...";
      });
      String token = "";
      try {
        token = await getShengwangToken();
      } catch (e) {
        setState(() {
          _statusMessage = "获取Token失败: $e";
          _isInitError = true;
        });
        return;
      }

      // 2. Initialize RTC
      setState(() {
        _statusMessage = "正在初始化 RTC 引擎...";
      });
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("Successfully joined RTC channel: ${connection.channelId}");
            if (mounted) {
              setState(() {
                _rtcJoined = true;
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("RTC error: $err, msg: $msg");
            if (mounted) {
              setState(() {
                _statusMessage = "RTC 连接出错: $msg";
              });
            }
          },
        ),
      );

      await _engine.enableVideo();
      await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);

      // Mute local streams (this side only controls)
      await _engine.muteLocalAudioStream(true);
      await _engine.muteLocalVideoStream(true);

      // Join RTC channel
      await _engine.joinChannel(
        token: token,
        channelId: widget.channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: false,
          autoSubscribeVideo: true,
        ),
      );

      // 3. Initialize MQTT Control Connection
      setState(() {
        _statusMessage = "正在建立远程控制连接 (MQTT)...";
      });

      _mqttController = Get.find<MqttController>();

      if (mounted) {
        setState(() {
          _rtmConnected = true;
        });
      }
      debugPrint('MQTT Control Connected successfully');
    } catch (e) {
      debugPrint("Error initializing screen control: $e");
      if (mounted) {
        setState(() {
          _statusMessage = "控制初始化失败: $e";
          _isInitError = true;
        });
      }
    }
  }

  void _sendControlMessage(String action, Offset localPosition) {
    if (!_rtmConnected) return;

    final RenderBox? renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final double width = renderBox.size.width;
    final double height = renderBox.size.height;

    final double normalizedX = localPosition.dx / width;
    final double normalizedY = localPosition.dy / height;

    // Safety checks
    if (normalizedX < 0 || normalizedX > 1 || normalizedY < 0 || normalizedY > 1) return;

    final Map<String, dynamic> body = {
      'action': action,
      'x': normalizedX,
      'y': normalizedY,
    };

    final Map<String, dynamic> payload = {
      'cmdId': 71,
      'timeTagMs': DateTime.now().millisecondsSinceEpoch,
      'body': body,
    };

    _mqttController.publishCommand(widget.robotId, payload);
  }

  void _sendHardwareKey(int androidKeyCode) {
    if (!_rtmConnected) {
      ToastUtil.show("控制连接未就绪");
      return;
    }

    final Map<String, dynamic> body = {
      'action': 'KEY',
      'code': androidKeyCode,
    };

    final Map<String, dynamic> payload = {
      'cmdId': 71,
      'timeTagMs': DateTime.now().millisecondsSinceEpoch,
      'body': body,
    };

    _mqttController.publishCommand(widget.robotId, payload);
    ToastUtil.show("下发硬件按键: $androidKeyCode");
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  Future<void> _cleanup() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("Error releasing RTC engine: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render screenshare video once RTC channel is joined, even if RTM connection is still connecting/failed
    final bool isReady = _rtcJoined;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Stack(
        children: [
          // Screenshare preview and interactive viewport
          Positioned.fill(
            child: isReady
                ? Center(
                    child: Listener(
                      onPointerDown: (PointerDownEvent event) {
                        _sendControlMessage('DOWN', event.localPosition);
                      },
                      onPointerMove: (PointerMoveEvent event) {
                        _sendControlMessage('MOVE', event.localPosition);
                      },
                      onPointerUp: (PointerUpEvent event) {
                        _sendControlMessage('UP', event.localPosition);
                      },
                      child: Container(
                        key: _viewportKey,
                        color: Colors.black,
                        child: AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine,
                            canvas: VideoCanvas(uid: robotUid),
                            connection: RtcConnection(channelId: widget.channelId),
                          ),
                        ),
                      ),
                    ),
                  )
                : _buildLoadingState(),
          ),

          // Top action bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isReady 
                              ? (_rtmConnected ? Colors.greenAccent : Colors.orangeAccent) 
                              : Colors.amberAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReady 
                            ? (_rtmConnected 
                                ? "控制频道: ${widget.channelId} (连接就绪)" 
                                : "控制频道: ${widget.channelId} (仅画面，控制断开)") 
                            : "控制连接中...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Control Action Buttons (Android Key Events)
                if (isReady)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                        label: const Text('返回 (Back)'),
                        onPressed: () => _sendHardwareKey(4),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        icon: const Icon(Icons.home_rounded, size: 14),
                        label: const Text('桌面 (Home)'),
                        onPressed: () => _sendHardwareKey(3),
                      ),
                    ],
                  ),

                // Close button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.6),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isInitError)
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            ),
          if (_isInitError)
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 50,
            ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
