import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shengwang_rtc_engine/agora_rtc_engine.dart';
import '../../utils/toast_util.dart';
import '../../controllers/mqtt_controller.dart';

class CameraStreamWidget extends StatefulWidget {
  final String channelId;
  final String robotId;
  final RtcEngine? engine;
  final int? remoteUid;
  final bool isReady;
  final String statusMessage;

  const CameraStreamWidget({
    Key? key,
    required this.channelId,
    required this.robotId,
    this.engine,
    this.remoteUid,
    required this.isReady,
    required this.statusMessage,
  }) : super(key: key);

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {
  bool _isMuted = false;

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
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: hasVideo
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: widget.engine!,
                      canvas: VideoCanvas(
                        uid: widget.remoteUid,
                        renderMode: RenderModeType.renderModeFit,
                      ),
                      connection: RtcConnection(channelId: widget.channelId),
                    ),
                  )
                : _buildLoadingState(),
          ),
          if (hasVideo)
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
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "正在拉流",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.blueAccent),
        const SizedBox(height: 16),
        Text(widget.statusMessage, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}

class ScreenControlStreamWidget extends StatefulWidget {
  final String channelId;
  final String robotId;
  final RtcEngine? engine;
  final int? remoteUid;
  final bool isReady;
  final String statusMessage;

  const ScreenControlStreamWidget({
    Key? key,
    required this.channelId,
    required this.robotId,
    this.engine,
    this.remoteUid,
    required this.isReady,
    required this.statusMessage,
  }) : super(key: key);

  @override
  State<ScreenControlStreamWidget> createState() => _ScreenControlStreamWidgetState();
}

class _ScreenControlStreamWidgetState extends State<ScreenControlStreamWidget> {
  late final MqttController _mqttController;
  bool _mqttConnected = false;
  final GlobalKey _viewportKey = GlobalKey();

  int _videoWidth = 1280;
  int _videoHeight = 720;
  late final RtcEngineEventHandler _rtcEventHandler;

  @override
  void initState() {
    super.initState();
    try {
      _mqttController = Get.find<MqttController>();
      _mqttConnected = true;
    } catch (e) {
      debugPrint("Error finding MqttController: $e");
    }

    _rtcEventHandler = RtcEngineEventHandler(
      onVideoSizeChanged: (RtcConnection connection, VideoSourceType sourceType, int uid, int width, int height, int rotation) {
        if (uid == widget.remoteUid) {
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
        debugPrint("Error unregistering event handler: $e");
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

    double videoWidth = containerWidth;
    double videoHeight = containerHeight;
    double videoLeft = 0;
    double videoTop = 0;

    if (_videoWidth > 0 && _videoHeight > 0) {
      final double videoAspectRatio = _videoWidth.toDouble() / _videoHeight.toDouble();
      final double containerAspectRatio = containerWidth / containerHeight;

      if (containerAspectRatio > videoAspectRatio) {
        videoHeight = containerHeight;
        videoWidth = containerHeight * videoAspectRatio;
        videoLeft = (containerWidth - videoWidth) / 2;
      } else {
        videoWidth = containerWidth;
        videoHeight = containerWidth / videoAspectRatio;
        videoTop = (containerHeight - videoHeight) / 2;
      }
    }

    final double relativeX = localPosition.dx - videoLeft;
    final double relativeY = localPosition.dy - videoTop;
    final double normalizedX = relativeX / videoWidth;
    final double normalizedY = relativeY / videoHeight;

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

  @override
  Widget build(BuildContext context) {
    final bool hasVideo = widget.isReady && widget.remoteUid != null && widget.engine != null;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: hasVideo
                ? Listener(
                    onPointerDown: (event) => _sendControlMessage('DOWN', event.localPosition),
                    onPointerMove: (event) => _sendControlMessage('MOVE', event.localPosition),
                    onPointerUp: (event) => _sendControlMessage('UP', event.localPosition),
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
                : _buildLoadingState(),
          ),
          if (hasVideo)
            Positioned(
              bottom: 16,
              left: 16,
              child: Row(
                children: [
                  _buildHardwareButton(Icons.arrow_back_ios_rounded, '返回', () => _sendHardwareKey(4)),
                  const SizedBox(width: 8),
                  _buildHardwareButton(Icons.home_rounded, '桌面', () => _sendHardwareKey(3)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHardwareButton(IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
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
      icon: Icon(icon, size: 12),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.blueAccent),
        const SizedBox(height: 16),
        Text(widget.statusMessage, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}
