import 'package:flutter/material.dart';
import 'package:shengwang_rtc_engine/agora_rtc_engine.dart';

class RtcWidget extends StatefulWidget {
  final String channelId;
  final String robotId;
  final RtcEngine? engine;
  final int? remoteUid;
  final bool isReady;
  final String statusMessage;
  final VoidCallback? onClose;
  final Function(Offset delta)? onDrag;

  const RtcWidget({
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
  State<RtcWidget> createState() => _RtcWidgetState();
}

class _RtcWidgetState extends State<RtcWidget> {
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
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Stack(
        children: [
          // Video player or loading state
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

          // Top action bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Channel ID details
                GestureDetector(
                  onPanUpdate: widget.onDrag != null
                      ? (details) => widget.onDrag!(details.delta)
                      : null,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.remoteUid != null ? Colors.greenAccent : Colors.amberAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "监控: ${widget.robotId}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Close button
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          // Bottom status and action controls
          if (widget.remoteUid != null)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                          size: 24,
                        ),
                        tooltip: _isMuted ? "取消静音" : "静音",
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "正在拉流",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
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
    );
  }

  Widget _buildLoadingState() {
    return Column(
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
    );
  }
}
