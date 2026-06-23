import 'dart:convert';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/robot_model.dart';
import '../../models/map_data.dart';
import '../../controllers/robot_controller.dart';
import '../../controllers/mqtt_controller.dart';
import '../widgets/tv_focus_helper.dart';
import 'flame/robot_map_game.dart';

class RobotDetailPage extends StatefulWidget {
  final String robotId;

  const RobotDetailPage({Key? key, required this.robotId}) : super(key: key);

  @override
  State<RobotDetailPage> createState() => _RobotDetailPageState();
}

class _RobotDetailPageState extends State<RobotDetailPage> {
  final RobotController robotController = Get.find<RobotController>();
  final MqttController mqttController = Get.find<MqttController>();
  RobotMapGame? _game;
  bool _isLoadingMap = true;
  bool _mapLoadFailed = false;

  // 侧边栏状态
  String? _activePanel; // 'alarm', 'patrol', 'health', 'trajectory', 'command'
  bool _isPanelOpen = false;

  // 指令面板状态
  bool _isSendingCommand = false;
  final List<Map<String, dynamic>> _commandLog = [];
  final TextEditingController _customMsgController = TextEditingController();
  final FocusNode _mapFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    final robotIndex = robotController.robots.indexWhere((r) => r.id == widget.robotId);
    if (robotIndex < 0) return;
    final robot = robotController.robots[robotIndex];

    try {
      final mapData = await MapData.loadFromCloud(robot.id);
      if (mapData != null && mounted) {
        setState(() {
          _game = RobotMapGame(mapData, robot, onPointClicked: (pt) {
            _showPointDetailsDialog(pt, robot);
          });
          _isLoadingMap = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMap = false;
            _mapLoadFailed = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMap = false;
          _mapLoadFailed = true;
        });
      }
    }
  }

  void _togglePanel(String panelName) {
    setState(() {
      if (_activePanel == panelName && _isPanelOpen) {
        _isPanelOpen = false;
      } else {
        _activePanel = panelName;
        _isPanelOpen = true;
      }
    });
  }

  @override
  void dispose() {
    // 显式释放 C++ 层的图片图形内存，防止不断进出详情页导致 OOM
    _game?.mapData.image.dispose();
    _customMsgController.dispose();
    _mapFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设备详情: ${widget.robotId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Obx(() {
        final robotIndex = robotController.robots.indexWhere((r) => r.id == widget.robotId);
        if (robotIndex < 0) {
          return const Center(child: Text('设备不存在', style: TextStyle(color: Colors.white)));
        }
        final robot = robotController.robots[robotIndex];

        return Stack(
          children: [
            // 1. 地图背景
            _buildMapBackground(),

            // 2. 左上角基础状态信息
            Positioned(
              top: 16,
              left: 16,
              child: _buildFloatingStatus(robot),
            ),

            // 3. 右侧面板
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 0,
              bottom: 0,
              right: _isPanelOpen ? 0 : -350,
              width: 350,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                  ],
                ),
                child: _buildPanelContent(robot),
              ),
            ),

            // 4. 右侧悬浮按钮组
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              right: _isPanelOpen ? 366 : 16,
              top: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSideButton('报警事件', Icons.warning_amber_rounded, Colors.redAccent, 'alarm'),
                  const SizedBox(height: 16),
                  _buildSideButton('巡逻事件', Icons.route_rounded, Colors.blueAccent, 'patrol'),
                  const SizedBox(height: 16),
                  _buildSideButton('健康检测上报', Icons.monitor_heart_rounded, Colors.greenAccent, 'health'),
                  const SizedBox(height: 16),
                  _buildSideButton('最近轨迹', Icons.insights_rounded, Colors.purpleAccent, 'trajectory'),
                  const SizedBox(height: 16),
                  _buildSideButton('指令控制', Icons.terminal_rounded, Colors.amberAccent, 'command'),
                ],
              ),
            ),

            // 5. 底部地图控制按钮（仅大屏/Web显示，手机端用双指手势）
            if (kIsWeb || MediaQuery.of(context).size.width >= 600)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildMapControls(),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildMapBackground() {
    if (_isLoadingMap) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 16),
            Text('正在从云端加载高精度地图...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_mapLoadFailed || _game == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text('地图加载失败', style: TextStyle(color: Colors.white70, fontSize: 18)),
          ],
        ),
      );
    }

    // Wrap GameWidget properly
    return Positioned.fill(
      child: Focus(
        focusNode: _mapFocusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.dpadUp) {
              _game!.moveUp();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.dpadDown) {
              _game!.moveDown();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.dpadLeft) {
              _game!.moveLeft();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.dpadRight) {
              _game!.moveRight();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.dpadCenter) {
              _game!.zoomIn();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFocused ? Colors.greenAccent : Colors.transparent,
                  width: 3.0,
                ),
              ),
              child: GameWidget(game: _game!),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    if (_game == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(Icons.zoom_in_rounded, '放大', () => _game!.zoomIn()),
          _buildControlButton(Icons.zoom_out_rounded, '缩小', () => _game!.zoomOut()),
          Container(width: 1, height: 24, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8)),
          _buildControlButton(Icons.arrow_upward_rounded, '上移', () => _game!.moveUp()),
          _buildControlButton(Icons.arrow_downward_rounded, '下移', () => _game!.moveDown()),
          _buildControlButton(Icons.arrow_back_rounded, '左移', () => _game!.moveLeft()),
          _buildControlButton(Icons.arrow_forward_rounded, '右移', () => _game!.moveRight()),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return TvFocusHelper(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      focusColor: Colors.blueAccent,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildFloatingStatus(RobotModel robot) {
    bool isCritical = robot.eStop || robot.hasFallAlarm;
    Color themeColor = isCritical ? Colors.redAccent : Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCritical ? Icons.warning_rounded : Icons.smart_toy_rounded, color: themeColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(robot.naturalStatus, style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('电量: ${robot.soc}%', style: TextStyle(color: robot.soc < 15 ? Colors.red : Colors.greenAccent, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('急停: ${robot.eStop ? "触发" : "正常"}', style: TextStyle(color: robot.eStop ? Colors.red : Colors.white70, fontSize: 12)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSideButton(String label, IconData icon, Color color, String panelId) {
    bool isActive = _isPanelOpen && _activePanel == panelId;
    bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return TvFocusHelper(
      onTap: () => _togglePanel(panelId),
      borderRadius: BorderRadius.circular(30),
      focusColor: color,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : const Color(0xFF1E293B).withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isActive ? color : color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (!isSmallScreen) ...[
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(RobotModel robot) {
    switch (_activePanel) {
      case 'alarm':
        return _buildAlarmPanel(robot);
      case 'patrol':
        return _buildPatrolPanel(robot);
      case 'health':
        return _buildHealthPanel(robot);
      case 'trajectory':
        return _buildTrajectoryPanel(robot);
      case 'command':
        return _buildCommandPanel(robot);
      default:
        return const SizedBox();
    }
  }

  // ============================
  // 指令控制面板
  // ============================
  Widget _buildCommandPanel(RobotModel robot) {
    return Column(
      children: [
        _buildPanelHeader('指令控制', Icons.terminal_rounded, Colors.amberAccent),
        if (_isSendingCommand)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amberAccent.withOpacity(0.05),
            child: Row(
              children: [
                const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent)),
                const SizedBox(width: 12),
                const Text('正在发送指令...', style: TextStyle(color: Colors.amberAccent, fontSize: 13)),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCommandSection('🚀 巡逻指令', [
                _CommandItem(
                  icon: Icons.play_arrow_rounded,
                  title: '开始巡逻',
                  subtitle: '触发机器人开始默认巡逻任务',
                  color: Colors.greenAccent,
                  onTap: () => _sendCommand(robot.id, '开始巡逻', {
                    'cmdId': 8,
                    'version': 2,
                    'timeTag': DateTime.now().millisecondsSinceEpoch,
                    'body': {'type': 3, 'subtype': 1, 'params': {'patrolId': '1'}},
                  }),
                ),
                _CommandItem(
                  icon: Icons.stop_rounded,
                  title: '停止巡逻',
                  subtitle: '立即停止当前巡逻任务',
                  color: Colors.redAccent,
                  onTap: () => _sendCommand(robot.id, '停止巡逻', {
                    'cmdId': 8,
                    'version': 2,
                    'timeTag': DateTime.now().millisecondsSinceEpoch,
                    'body': {'type': 3, 'subtype': 2},
                  }),
                ),
                _CommandItem(
                  icon: Icons.battery_charging_full_rounded,
                  title: '回去充电',
                  subtitle: '立即召回机器人返回充电桩',
                  color: Colors.amberAccent,
                  onTap: () => _sendCommand(robot.id, '回去充电', {
                    'cmdId': 8,
                    'version': 2,
                    'timeTag': DateTime.now().millisecondsSinceEpoch,
                    'body': {'type': '5', 'subtype': 1, 'params': {}},
                  }),
                ),
              ]),
              const SizedBox(height: 16),
              _buildCommandSection('🔧 系统维护', [
                _CommandItem(
                  icon: Icons.wifi_protected_setup_rounded,
                  title: '同步 WiFi 给 88',
                  subtitle: '通过 SSH 同步 WiFi 配置',
                  color: Colors.cyanAccent,
                  onTap: () => _sendCommand(robot.id, '同步WiFi', {
                    'cmdId': 9,
                    'version': 2,
                    'timeTag': DateTime.now().millisecondsSinceEpoch,
                    'body': {'type': '1'},
                  }),
                ),
                _CommandItem(
                  icon: Icons.restart_alt_rounded,
                  title: '重启 Todesk',
                  subtitle: '通过 SSH 重启远控服务',
                  color: Colors.indigoAccent,
                  onTap: () => _sendCommand(robot.id, '重启Todesk', {
                    'cmdId': 9,
                    'version': 2,
                    'timeTag': DateTime.now().millisecondsSinceEpoch,
                    'body': {'type': '2'},
                  }),
                ),
              ]),
              const SizedBox(height: 16),
              _buildCommandSection('📋 日志与诊断', [
                _CommandItem(
                  icon: Icons.calendar_today_rounded,
                  title: '拉取指定日期安卓日志',
                  subtitle: '选择日期拉取指定日期的日志',
                  color: Colors.orangeAccent,
                  onTap: () => _showDateLogDialog(robot.id),
                ),
                _CommandItem(
                  icon: Icons.description_rounded,
                  title: '拉取当天日志',
                  subtitle: '拉取当天的日志内容',
                  color: Colors.blueAccent,
                  onTap: () => _showTodayLogDialog(
                    robot.id,
                    title: '拉取当天日志',
                    hint: '请描述清楚问题',
                    subtype: 1,
                  ),
                ),
                _CommandItem(
                  icon: Icons.radar_rounded,
                  title: '拉取机器人图片',
                  subtitle: '获取机器人 ROS 雷达图',
                  color: Colors.tealAccent,
                  onTap: () => _showTodayLogDialog(
                    robot.id,
                    title: '获取机器人的图片',
                    hint: '请描述清楚问题',
                    subtype: 3,
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _buildCommandSection('📝 自定义指令', [
                _CommandItem(
                  icon: Icons.code_rounded,
                  title: '自定义 JSON 指令',
                  subtitle: '手动编辑并发送原始指令',
                  color: Colors.purpleAccent,
                  onTap: () => _showCustomCommandDialog(robot.id),
                ),
              ]),
              if (_commandLog.isNotEmpty) ...
              [
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    const Text('发送记录', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TvFocusHelper(
                      onTap: () => setState(() => _commandLog.clear()),
                      borderRadius: BorderRadius.circular(8),
                      focusColor: Colors.redAccent,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('清空', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._commandLog.reversed.take(10).map((log) => _buildLogEntry(log)).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommandSection(String title, List<_CommandItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  _buildCommandTile(item),
                  if (i < items.length - 1)
                    Divider(height: 1, color: Colors.white.withOpacity(0.06), indent: 60),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildCommandTile(_CommandItem item) {
    return TvFocusHelper(
      onTap: _isSendingCommand ? () {} : item.onTap,
      borderRadius: BorderRadius.circular(16),
      focusColor: item.color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: item.color.withOpacity(0.3)),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.send_rounded, color: item.color.withOpacity(0.6), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final bool success = log['success'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (success ? Colors.greenAccent : Colors.redAccent).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (success ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? Colors.greenAccent : Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(log['name'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Text(log['time'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _sendCommand(String sn, String name, Map<String, dynamic> payload) async {
    setState(() => _isSendingCommand = true);
    final success = await mqttController.publishCommand(sn, payload);
    setState(() {
      _isSendingCommand = false;
      _commandLog.add({
        'name': name,
        'success': success,
        'time': DateFormat('HH:mm:ss').format(DateTime.now()),
      });
    });
    Get.snackbar(
      success ? '✅ 指令已发送' : '❌ 发送失败',
      success ? '"$name" 指令已成功下发至 $sn' : '请检查 MQTT 连接状态',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: success ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void _showDateLogDialog(String sn) {
    DateTime selectedDate = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_today_rounded, color: Colors.orangeAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('拉取指定日期安卓日志', style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
          content: TvFocusHelper(
            autofocus: true,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.orangeAccent)),
                  child: child!,
                ),
              );
              if (picked != null) setDialogState(() => selectedDate = picked);
            },
            borderRadius: BorderRadius.circular(12),
            focusColor: Colors.orangeAccent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Text('点击更改', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.white54))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('发送'),
              onPressed: () async {
                final dateStr = '${selectedDate.year}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}';
                Navigator.pop(context);
                await _sendCommand(sn, '拉取${selectedDate.month}月${selectedDate.day}日日志', {
                  'cmdId': 8,
                  'version': 2,
                  'timeTag': DateTime.now().millisecondsSinceEpoch,
                  'body': {'type': 7, 'subtype': 2, 'params': {'time': dateStr}},
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTodayLogDialog(String sn, {required String title, required String hint, required int subtype}) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (subtype == 3 ? Colors.tealAccent : Colors.blueAccent).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(subtype == 3 ? Icons.radar_rounded : Icons.description_rounded,
                  color: subtype == 3 ? Colors.tealAccent : Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15))),
          ],
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subtype == 3 ? Colors.tealAccent : Colors.blueAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: subtype == 3 ? Colors.tealAccent : Colors.blueAccent,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('发送'),
            onPressed: () async {
              final message = textController.text.trim();
              if (message.isEmpty) {
                Get.snackbar('提示', '请输入描述内容', snackPosition: SnackPosition.BOTTOM);
                return;
              }
              Navigator.pop(context);
              await _sendCommand(sn, title, {
                'cmdId': 8,
                'version': 2,
                'timeTag': DateTime.now().millisecondsSinceEpoch,
                'body': {'type': 7, 'subtype': subtype, 'params': {'message': message}},
              });
            },
          ),
        ],
      ),
    );
  }

  void _showCustomCommandDialog(String sn) {
    _customMsgController.text = '{\n  "cmdId": 8,\n  "version": 2,\n  "timeTag": ${DateTime.now().millisecondsSinceEpoch},\n  "body": {}\n}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.code_rounded, color: Colors.purpleAccent, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('自定义 JSON 指令', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: _customMsgController,
            autofocus: true,
            maxLines: 12,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, height: 1.6),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.purpleAccent.withOpacity(0.3))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purpleAccent)),
              hintText: '请输入合法的 JSON 指令',
              hintStyle: const TextStyle(color: Colors.white30),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('发送'),
            onPressed: () async {
              try {
                final decoded = jsonDecode(_customMsgController.text.trim()) as Map<String, dynamic>;
                Navigator.pop(context);
                await _sendCommand(sn, '自定义指令', decoded);
              } catch (e) {
                Get.snackbar('格式错误', '请输入合法的 JSON', backgroundColor: Colors.redAccent, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmPanel(RobotModel robot) {
    return Column(
      children: [
        _buildPanelHeader('报警事件', Icons.warning_amber_rounded, Colors.redAccent),
        Expanded(
          child: robot.alarmHistory.isEmpty
            ? const Center(child: Text('暂无历史报警事件', style: TextStyle(color: Colors.white54)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: robot.alarmHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final alarm = robot.alarmHistory[robot.alarmHistory.length - 1 - index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(12), 
                      border: Border.all(color: Colors.red.withOpacity(0.3))
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(alarm.title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            Text(DateFormat('MM-dd HH:mm:ss').format(alarm.time), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(alarm.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        if (alarm.imgUrl != null && alarm.imgUrl!.isNotEmpty)
                          _buildImageList(alarm.imgUrl),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildPatrolPanel(RobotModel robot) {
    return Column(
      children: [
        _buildPanelHeader('巡逻事件', Icons.route_rounded, Colors.blueAccent),
        Expanded(
          child: robot.patrolHistory.isEmpty
            ? const Center(child: Text('暂无巡逻记录', style: TextStyle(color: Colors.white54)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: robot.patrolHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final session = robot.patrolHistory[robot.patrolHistory.length - 1 - index];
                  String timeStr = '';
                  if (session.events.isNotEmpty) {
                    timeStr = DateFormat('MM-dd HH:mm:ss').format(session.events.first.time);
                    if (session.events.length > 1) {
                      timeStr += '\n至 ${DateFormat('MM-dd HH:mm:ss').format(session.events.last.time)}';
                    } else if (session.endTime != null) {
                      timeStr += '\n至 ${DateFormat('MM-dd HH:mm:ss').format(session.endTime!)}';
                    } else {
                      timeStr += '\n(巡逻中)';
                    }
                  } else {
                    timeStr = DateFormat('MM-dd HH:mm:ss').format(session.startTime);
                    if (session.endTime != null) {
                      timeStr += '\n至 ${DateFormat('MM-dd HH:mm:ss').format(session.endTime!)}';
                    }
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2))
                    ),
                    child: ExpansionTile(
                      iconColor: Colors.blueAccent,
                      collapsedIconColor: Colors.white54,
                      title: Text(session.recordId.isEmpty ? '巡逻任务 (本地记录)' : '任务 ID: ${session.recordId}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text('共 ${session.events.length} 个详细事件\n$timeStr', style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                      children: session.events.map((e) {
                        IconData icon;
                        Color iconColor;
                        if (e.eventType == 1) { icon = Icons.play_circle_fill; iconColor = Colors.greenAccent; }
                        else if (e.eventType == 2) { icon = Icons.check_circle; iconColor = Colors.blueAccent; }
                        else if (e.eventType == 3) { icon = Icons.next_plan; iconColor = Colors.orangeAccent; }
                        else if (e.eventType == 4) { icon = Icons.pause_circle_filled; iconColor = Colors.amber; }
                        else if (e.eventType == 5) { icon = Icons.stop_circle; iconColor = Colors.grey; }
                        else if (e.eventType == 6) { icon = Icons.error; iconColor = Colors.redAccent; }
                        else { icon = Icons.info; iconColor = Colors.white54; }

                        return ListTile(
                          leading: Icon(icon, color: iconColor),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(e.title, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                              Text(DateFormat('HH:mm:ss').format(e.time), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e.description != null && e.description!.isNotEmpty) 
                                Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('原因: ${e.description}', style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                              if (e.imgUrl != null && e.imgUrl!.isNotEmpty)
                                _buildImageList(e.imgUrl),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildHealthPanel(RobotModel robot) {
    return Column(
      children: [
        _buildPanelHeader('健康检测上报', Icons.monitor_heart_rounded, Colors.greenAccent),
        Expanded(
          child: robot.healthHistory.isEmpty
            ? const Center(child: Text('暂无健康检测记录', style: TextStyle(color: Colors.white54)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: robot.healthHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final health = robot.healthHistory[robot.healthHistory.length - 1 - index];
                  
                  String typeName = '';
                  String valueStr = '';
                  IconData iconData = Icons.favorite;
                  
                  if (health.subtype == 0) {
                    typeName = '血氧测量';
                    valueStr = '${health.params['blood_oxygen'] ?? '--'} %';
                    iconData = Icons.water_drop;
                  } else if (health.subtype == 1) {
                    typeName = '体温测量';
                    valueStr = '${health.params['body_temperature'] ?? '--'} ℃';
                    iconData = Icons.thermostat;
                  } else if (health.subtype == 2) {
                    typeName = '血压测量';
                    valueStr = '${health.params['systolic_pressure'] ?? '--'}/${health.params['diastolic_pressure'] ?? '--'} mmHg  脉率: ${health.params['pulse'] ?? '--'} bpm';
                    iconData = Icons.monitor_heart;
                  } else if (health.subtype == 3) {
                    typeName = '脉率测量';
                    valueStr = '${health.params['pulse'] ?? '--'} bpm';
                    iconData = Icons.monitor_heart;
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.2))
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.greenAccent.withOpacity(0.2),
                          child: Icon(iconData, color: Colors.greenAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(typeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(DateFormat('MM-dd HH:mm').format(health.time), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('用户 ID: ${health.userId}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(valueStr, style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildTrajectoryPanel(RobotModel robot) {
    return Column(
      children: [
        _buildPanelHeader('最近轨迹', Icons.insights_rounded, Colors.purpleAccent),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.purpleAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '当前共记录了 ${robot.trajectory.length} 个轨迹点。轨迹已在底图上用绿色线条实时绘制。',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('近期坐标列表', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: robot.trajectory.isEmpty
                      ? const Center(child: Text('暂无坐标记录', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: robot.trajectory.length,
                          itemBuilder: (context, index) {
                            // Reverse order to show newest first
                            final pt = robot.trajectory[robot.trajectory.length - 1 - index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purpleAccent.withOpacity(0.2))
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.circle, size: 8, color: Colors.purpleAccent),
                                          const SizedBox(width: 6),
                                          Text(DateFormat('MM-dd HH:mm:ss').format(pt.time), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      Text('X: ${pt.x.toStringAsFixed(2)}  Y: ${pt.y.toStringAsFixed(2)}', style: const TextStyle(color: Colors.purpleAccent, fontFamily: 'monospace', fontSize: 12)),
                                    ]
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildMiniStat('状态', _getNaturalStatus(pt.type, pt.status), Colors.orangeAccent),
                                      _buildMiniStat('任务', _getTaskString(pt.taskList), Colors.blueAccent),
                                      _buildMiniStat('急停', pt.eStop ? '触发' : '正常', pt.eStop ? Colors.redAccent : Colors.greenAccent),
                                      _buildMiniStat('电量', '${pt.soc}%', pt.soc < 20 ? Colors.redAccent : Colors.greenAccent),
                                      if (pt.type == 3 && pt.patrolInfo.isNotEmpty)
                                        _buildMiniStat('巡逻', pt.patrolInfo, Colors.orangeAccent),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
            onPressed: () => setState(() => _isPanelOpen = false),
          ),
        ],
      ),
    );
  }

  String _getTaskString(List<int> tasks) {
    List<String> labels = ['报警', '检测', '人脸', '视频', '召唤'];
    List<String> activeTasks = [];
    for (int i = 0; i < tasks.length && i < labels.length; i++) {
      if (tasks[i] == 1) {
        activeTasks.add(labels[i]);
      }
    }
    return activeTasks.isEmpty ? '无任务' : activeTasks.join(',');
  }

  String _getNaturalStatus(int type, int status) {
    String taskName = "未知状态";
    switch (type) {
      case 0: taskName = "空闲待机"; break;
      case 1: taskName = "回去充电"; break;
      case 3: taskName = "巡逻任务"; break;
      case 7: taskName = "代送任务"; break;
      case 109: taskName = "迎宾点"; break;
      case 110: taskName = "传话"; break;
      case 111: taskName = "拿取"; break;
      case 112: taskName = "告警任务"; break;
      case 113: taskName = "大喇叭"; break;
      case 114: taskName = "导览任务"; break;
      case 115: taskName = "前往目标点"; break;
      case 116: taskName = "带路"; break;
    }
    
    if (type != 0) {
      if (status == 2) taskName += "(已暂停)";
      if (status == 4) taskName += "(异常失败)";
    }
    return taskName;
  }

  void _showPointDetailsDialog(TrajectoryPoint pt, RobotModel robot) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('历史心跳详情 (${DateFormat('HH:mm:ss').format(pt.time)})', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('坐标: (${pt.x.toStringAsFixed(2)}, ${pt.y.toStringAsFixed(2)})', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniStat('急停', pt.eStop ? '触发' : '正常', pt.eStop ? Colors.redAccent : Colors.green),
                _buildMiniStat('充放电', pt.socStaus == 0 ? '未充电' : (pt.socStaus == 1 ? '放电' : '充电'), Colors.greenAccent),
                _buildMiniStat('底盘WiFi', pt.wifi88Status == 1 ? '正常' : '异常', pt.wifi88Status == 1 ? Colors.greenAccent : Colors.redAccent),
                _buildMiniStat('任务', _getTaskString(pt.taskList), Colors.orangeAccent),
              ],
            ),
            if (pt.type == 3 && pt.patrolInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 14, color: Colors.amberAccent),
                      const SizedBox(width: 6),
                      Text(pt.patrolInfo, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Get.back(),
            child: const Text('关闭', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildImageList(String? urls) {
    if (urls == null || urls.isEmpty) return const SizedBox();
    
    final urlList = urls.split(',').where((e) => e.trim().isNotEmpty).toList();
    if (urlList.isEmpty) return const SizedBox();
    
    const String prefix = 'https://huaxi-1330823579.cos.ap-shanghai.myqcloud.com/robot';
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: urlList.map((url) {
          final fullUrl = url.startsWith('http') ? url : prefix + url.trim();
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fullUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 80,
                height: 80,
                color: Colors.white10,
                child: const Icon(Icons.broken_image, color: Colors.white30),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CommandItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CommandItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
