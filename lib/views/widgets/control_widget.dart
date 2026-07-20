import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shengwang_rtc_engine/agora_rtc_engine.dart';
import '../../utils/toast_util.dart';
import '../../controllers/mqtt_controller.dart';

class ControlWidget extends StatefulWidget {
  final String channelId;
  final String robotId;
  final RtcEngine? engine;
  final int? remoteUid;
  final bool isReady;
  final String statusMessage;
  final VoidCallback? onClose;
  final Function(Offset delta)? onDrag;

  const ControlWidget({
    Key? key,
    required this.channelId,
    required this.robotId,
    this.engine,
    this.remoteUid,
    required this.isReady,
    required this.statusMessage,
    this.onClose,
    this.onDrag,
  }) : super(key: key);

  @override
  State<ControlWidget> createState() => _ControlWidgetState();
}

class _ControlWidgetState extends State<ControlWidget> {
  late final MqttController _mqttController;
  bool _mqttConnected = false;

  final GlobalKey _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    try {
      _mqttController = Get.find<MqttController>();
      _mqttConnected = true;
    } catch (e) {
      debugPrint("Error finding MqttController: $e");
    }
  }

  void _sendControlMessage(String action, Offset localPosition) {
    if (!_mqttConnected) return;

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
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Column(
        children: [
          // Top action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                // Info Badge (Draggable handle)
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
                              color: hasVideo 
                                  ? (_mqttConnected ? Colors.greenAccent : Colors.orangeAccent) 
                                  : Colors.amberAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasVideo 
                                ? (_mqttConnected 
                                    ? "控制: ${widget.robotId}" 
                                    : "控制: ${widget.robotId} (无控制)") 
                                : "连接中...",
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

                const Spacer(),

                // Control Action Buttons (Android Key Events)
                if (hasVideo) ...[
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

          // Screenshare preview and interactive viewport
          Expanded(
            child: hasVideo
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
                            rtcEngine: widget.engine!,
                            canvas: VideoCanvas(
                              uid: widget.remoteUid,
                              renderMode: RenderModeType.renderModeFit,
                            ),
                            connection: RtcConnection(channelId: widget.channelId),
                          ),
                        ),
                      ),
                    ),
                  )
                : _buildLoadingState(),
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
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.statusMessage,
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
