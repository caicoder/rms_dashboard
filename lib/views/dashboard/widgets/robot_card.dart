import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/robot_model.dart';
import 'package:get/get.dart';
import '../../details/robot_detail_page.dart';
import '../../../controllers/robot_controller.dart';

class RobotCard extends StatelessWidget {
  final RobotModel robot;

  const RobotCard({Key? key, required this.robot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isCritical = robot.eStop || robot.hasFallAlarm;
    bool isOffline = robot.isOffline;
    bool isLowBattery = robot.soc < 15;

    Color themeColor = isCritical 
        ? const Color(0xFFEF4444) 
        : (isOffline ? Colors.grey : const Color(0xFF3B82F6));
        
    return GestureDetector(
      onTap: () {
        Get.to(() => RobotDetailPage(robotId: robot.id));
      },
      onLongPress: () {
        Get.dialog(
          AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('删除设备', style: TextStyle(color: Colors.white)),
            content: Text('确定要删除设备 ${robot.id} 吗？\n将停止接收它的消息。', style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消', style: TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () {
                  Get.back(); // 必须先关弹窗，否则后续的 snackbar 会拦截这个 back 事件
                  Get.find<RobotController>().removeRobot(robot.id);
                },
                child: const Text('删除', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: themeColor.withOpacity(isCritical ? 0.8 : 0.3),
          width: isCritical ? 2 : 1,
        ),
        boxShadow: [
          if (isCritical && !isOffline)
            BoxShadow(
              color: themeColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  themeColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Opacity(
              opacity: isOffline ? 0.5 : 1.0,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(child: _buildStatusBadge(isOffline, isCritical, robot)),
                        const SizedBox(width: 8),
                        _buildBatteryIndicator(isLowBattery),
                      ],
                    ),
                    
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              robot.organization.isNotEmpty ? robot.organization : '未分配机构',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SN: ${robot.id}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            // 所有的心跳字段分两行显示
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMiniStat('急停', robot.eStop ? '触发' : '正常', robot.eStop ? Colors.redAccent : Colors.green),
                                const SizedBox(width: 8),
                                _buildMiniStat('充放电', robot.socStaus == 0 ? '未充电' : (robot.socStaus == 1 ? '放电' : '充电'), Colors.greenAccent),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMiniStat('底盘WiFi', robot.wifi88Status == 1 ? '正常' : '异常', robot.wifi88Status == 1 ? Colors.greenAccent : Colors.redAccent),
                                const SizedBox(width: 8),
                                _buildMiniStat('任务', _getTaskString(robot.taskList), Colors.orangeAccent),
                              ],
                            ),
                            if (robot.type == 3 && robot.patrolInfo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.place_rounded, size: 12, color: Colors.amberAccent),
                                      const SizedBox(width: 4),
                                      Text(robot.patrolInfo, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPositionStat('Axis X', robot.positionX, themeColor),
                              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
                              _buildPositionStat('Axis Y', robot.positionY, themeColor),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sync_rounded, size: 12, color: Colors.white38),
                              const SizedBox(width: 4),
                              Text(
                                '最新更新时间 ${robot.lastUpdated.hour.toString().padLeft(2, '0')}:${robot.lastUpdated.minute.toString().padLeft(2, '0')}:${robot.lastUpdated.second.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

  Widget _buildStatusBadge(bool isOffline, bool isCritical, RobotModel robot) {
    String text = robot.naturalStatus;
    Color color = const Color(0xFF10B981); // Emerald green
    IconData icon = Icons.check_circle_outline_rounded;

    if (isOffline) {
      color = Colors.grey;
      icon = Icons.cloud_off_rounded;
    } else if (robot.hasFallAlarm) {
      color = const Color(0xFFEF4444);
      icon = Icons.priority_high_rounded;
    } else if (robot.eStop) {
      color = const Color(0xFFEF4444);
      icon = Icons.stop_circle_rounded;
    } else if (robot.status != 1 || robot.type == 0) {
      color = const Color(0xFFF59E0B); // Amber
      icon = Icons.pause_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator(bool isLow) {
    IconData batteryIcon = robot.socStaus == 0 || robot.socStaus == 2 
        ? Icons.battery_charging_full_rounded 
        : Icons.battery_full_rounded;
    Color batteryColor = isLow ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(batteryIcon, color: batteryColor, size: 16),
          const SizedBox(width: 6),
          Text(
            '${robot.soc}%',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionStat(String label, double value, Color themeColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 18, 
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
