import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shengwang_rtc_engine/agora_rtc_engine.dart';
import '../../utils/http_util.dart';
import '../../utils/api_util.dart';
import '../../utils/toast_util.dart';

class RtcWidget extends StatefulWidget {
  final String channelId;
  final String robotId;

  const RtcWidget({
    Key? key,
    required this.channelId,
    required this.robotId,
  }) : super(key: key);

  @override
  State<RtcWidget> createState() => _RtcWidgetState();
}

class _RtcWidgetState extends State<RtcWidget> {
  static const String _appId = "afa2394f5e034fb4bd6a72593adbef57";
  late final RtcEngine _engine;
  
  bool _isInit = false;
  bool _joined = false;
  int? _remoteUid;
  bool _isMuted = false;
  String _statusMessage = "正在初始化音视频引擎...";
  String _shengwangToken = "";

  Future<String> getShengwangToken({required Function? callBack}) async {
    Completer<String> completer = Completer<String>();
    HttpUtil.getInstance()?.post(ApiUtil.shengWangToken, {
      'roomName': widget.channelId,
    }, (data) {
      _shengwangToken = data ?? '';
      callBack?.call();
      completer.complete(_shengwangToken);
    }, (msg, code) {
      ToastUtil.show(msg.toString());
      completer.completeError(msg);
    });
    return completer.future;
  }

  @override
  void initState() {
    super.initState();
    _initRtc();
  }

  Future<void> _initRtc() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("Successfully joined channel: ${connection.channelId}");
            if (mounted) {
              setState(() {
                _joined = true;
                _statusMessage = "已进入频道，正在等待机器人画面...";
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("Remote user joined: $remoteUid");
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _statusMessage = "已连接机器人";
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("Remote user offline: $remoteUid");
            if (mounted) {
              setState(() {
                _remoteUid = null;
                _statusMessage = "机器人已断开连接";
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("RTC error: $err, msg: $msg");
            if (mounted) {
              setState(() {
                _statusMessage = "连接出错: $msg";
              });
            }
          },
        ),
      );

      // Enable video support (not pushing, only pulling)
      await _engine.enableVideo();

      // Configure media options: pull-only stream, do not push local audio/video
      const ChannelMediaOptions options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
      );

      if (mounted) {
        setState(() {
          _statusMessage = "正在获取声网Token...";
        });
      }

      String token = "";
      try {
        token = await getShengwangToken(callBack: () {
          debugPrint("Shengwang Token fetched successfully");
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = "获取Token失败: $e";
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = "正在加入频道 ${widget.channelId}...";
          _isInit = true;
        });
      }

      await _engine.joinChannel(
        token: token,
        channelId: widget.channelId,
        uid: 0, // 0 lets engine generate a unique UID
        options: options,
      );
    } catch (e) {
      debugPrint("Error initializing RTC: $e");
      if (mounted) {
        setState(() {
          _statusMessage = "初始化失败: $e";
        });
      }
    }
  }

  void _toggleMute() {
    if (_remoteUid == null) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteRemoteAudioStream(uid: _remoteUid!, mute: _isMuted);
  }

  @override
  void dispose() {
    _leaveChannel();
    super.dispose();
  }

  Future<void> _leaveChannel() async {
    if (_isInit) {
      try {
        await _engine.leaveChannel();
        await _engine.release();
      } catch (e) {
        debugPrint("Error releasing RTC engine: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: _remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: _remoteUid),
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
                Container(
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
                          color: _remoteUid != null ? Colors.greenAccent : Colors.amberAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Text(
                      //   "监控频道: ${widget.channelId}",
                      //   style: const TextStyle(
                      //     color: Colors.white,
                      //     fontSize: 13,
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
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
          if (_remoteUid != null)
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
          _statusMessage,
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
