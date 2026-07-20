import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shengwang_rtc_engine/agora_rtc_engine.dart';
import '../../utils/toast_util.dart';
import '../../controllers/mqtt_controller.dart';

class MonitoringControlWidget extends StatefulWidget {
  final String channelId;
  final String robotId;
  final RtcEngine? engine;
  final int? remoteUid;
  final bool isReady;
  final String statusMessage;
  final VoidCallback? onClose;
  final Function(Offset delta)? onDrag;
  final int initialMode; // 0 for Camera Monitoring, 1 for Screen Control
  final int userId;

  const MonitoringControlWidget({
    Key? key,
    required this.channelId,
    required this.robotId,
    this.engine,
    this.remoteUid,
    required this.isReady,
    required this.statusMessage,
    this.onClose,
    this.onDrag,
    required this.userId,
    this.initialMode = 0,
  }) : super(key: key);

  @override
  State<MonitoringControlWidget> createState() => _MonitoringControlWidgetState();
}

class _MonitoringControlWidgetState extends State<MonitoringControlWidget> {
  late final MqttController _mqttController;
  bool _mqttConnected = false;
  late int _currentMode; // 0: Monitoring, 1: Control
  bool _isMuted = false;
  final GlobalKey _viewportKey = GlobalKey();

  // Screen resolution dimensions of the remote video stream
  int _videoWidth = 1280;
  int _videoHeight = 720;
  late final RtcEngineEventHandler _rtcEventHandler;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    try {
      _mqttController = Get.find<MqttController>();
      _mqttConnected = true;
    } catch (e) {
      debugPrint("Error finding MqttController: $e");
    }

    _rtcEventHandler = RtcEngineEventHandler(
      onRemoteVideoSizeChanged: (RtcConnection connection, int remoteUid, int width, int height, int rotation) {
        if (remoteUid == widget.remoteUid) {
          debugPrint("MonitoringControlWidget Remote video size changed: ${width}x${height}");
          if (mounted) {
            setState(() {
              _videoWidth = width;
              _videoHeight = height;
            });
          }
        }
      },
    );

    if (widget.engine != null) {
      widget.engine!.registerEventHandler(_rtcEventHandler);
    }
  }

  @override
  void dispose() {
    if (widget.engine != null) {
      try {
        widget.engine!.unregisterEventHandler(_rtcEventHandler);
      } catch (e) {
        debugPrint("Error unregistering event handler in MonitoringControlWidget: $e");
      }
    }
    super.dispose();
  }

  void _sendControlMessage(String action, Offset localPosition) {
    if (!_mqttConnected) return;

    final RenderBox? renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final double containerWidth = renderBox.size.width;
    final double containerHeight = renderBox.size.height;

    // Calculate the actual scaled dimensions and offsets of the video stream under RenderModeType.renderModeFit
    double videoWidth = containerWidth;
    double videoHeight = containerHeight;
    double videoLeft = 0;
    double videoTop = 0;

    if (_videoWidth > 0 && _videoHeight > 0) {
      final double videoAspectRatio = _videoWidth.toDouble() / _videoHeight.toDouble();
      final double containerAspectRatio = containerWidth / containerHeight;

      if (containerAspectRatio > videoAspectRatio) {
        // Pillarboxing (black bars on left/right sides)
        videoHeight = containerHeight;
        videoWidth = containerHeight * videoAspectRatio;
        videoLeft = (containerWidth - videoWidth) / 2;
      } else {
        // Letterboxing (black bars on top/bottom sides)
        videoWidth = containerWidth;
        videoHeight = containerWidth / videoAspectRatio;
        videoTop = (containerHeight - videoHeight) / 2;
      }
    }

    // Map pointer coordinate relative to the actual video boundary
    final double relativeX = localPosition.dx - videoLeft;
    final double relativeY = localPosition.dy - videoTop;

    // Normalize coordinates relative to the video dimensions
    final double normalizedX = relativeX / videoWidth;
    final double normalizedY = relativeY / videoHeight;

    // Ignore taps/clicks falling outside the actual video content region (black bars)
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
    if (!_mqttConnected) {
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

  void _switchMode(int targetMode) {
    if (_currentMode == targetMode) return;

    setState(() {
      _currentMode = targetMode;
    });

    final String modeType = targetMode == 0 ? "0" : "7";
    final timeTag = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final payload = {
      "cmdId": 66,
      "timeTag": timeTag,
      "body": {
        "type": modeType,
        "subtype": null,
        "params": {
          "userId": widget.userId
        },
        "target": ""
      }
    };

    if (_mqttConnected) {
      _mqttController.publishCommand(widget.robotId, payload);
      ToastUtil.show(targetMode == 0 ? "正在切换至视频监控..." : "正在切换至屏幕控制...");
    }
  }

  void _toggleMute() {
    if (widget.remoteUid == null || widget.engine == null) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    widget.engine!.muteRemoteAudioStream(uid: widget.remoteUid!, mute: _isMuted);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasVideo = widget.isReady && widget.remoteUid != null && widget.engine != null;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation / Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  // Info / Drag handle badge
                  GestureDetector(
                    onPanUpdate: widget.onDrag != null
                        ? (details) => widget.onDrag!(details.delta)
                        : null,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hasVideo ? Colors.greenAccent : Colors.amberAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentMode == 0 ? "监控: ${widget.robotId}" : "控制: ${widget.robotId}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Mode Toggle Segment Control
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        _buildModeButton(
                          label: "查看监控",
                          modeIndex: 0,
                          icon: Icons.videocam_rounded,
                        ),
                        _buildModeButton(
                          label: "屏幕控制",
                          modeIndex: 1,
                          icon: Icons.gamepad_rounded,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Control Action Buttons (Android Key Events) - Only show in Control Mode
                  if (_currentMode == 1 && hasVideo) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 12),
                      label: const Text('返回', style: TextStyle(fontSize: 12)),
                      onPressed: () => _sendHardwareKey(4),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      icon: const Icon(Icons.home_rounded, size: 12),
                      label: const Text('桌面', style: TextStyle(fontSize: 12)),
                      onPressed: () => _sendHardwareKey(3),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Close button
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),

            // Main View Content
            Expanded(
              child: Stack(
                children: [
                  // Video Viewport / Loading State
                  Center(
                    child: hasVideo
                        ? (_currentMode == 1
                            ? Listener(
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
                                      rtcEngine: widget.engine!,
                                      canvas: VideoCanvas(
                                        uid: widget.remoteUid,
                                        renderMode: RenderModeType.renderModeFit,
                                      ),
                                      connection: RtcConnection(channelId: widget.channelId),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.black,
                                child: AgoraVideoView(
                                  controller: VideoViewController.remote(
                                    rtcEngine: widget.engine!,
                                    canvas: VideoCanvas(
                                      uid: widget.remoteUid,
                                      renderMode: RenderModeType.renderModeFit,
                                    ),
                                    connection: RtcConnection(channelId: widget.channelId),
                                  ),
                                ),
                              ))
                        : _buildLoadingState(),
                  ),

                  // Audio Mute Control Overlay (Only in Camera Monitoring mode and when video is ready)
                  if (_currentMode == 0 && hasVideo)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _toggleMute,
                                icon: Icon(
                                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: _isMuted ? Colors.redAccent : Colors.blueAccent,
                                  size: 20,
                                ),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                tooltip: _isMuted ? "取消静音" : "静音",
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "正在拉流",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required int modeIndex,
    required IconData icon,
  }) {
    final bool isSelected = _currentMode == modeIndex;
    return GestureDetector(
      onTap: () => _switchMode(modeIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.statusMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
