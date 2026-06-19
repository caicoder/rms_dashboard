import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dart:ui';
import 'dart:convert';
import '../../controllers/robot_controller.dart';
import '../../controllers/mqtt_controller.dart';
import 'widgets/robot_card.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({Key? key}) : super(key: key);

  final RobotController robotController = Get.put(RobotController());
  final MqttController mqttController = Get.put(MqttController());

  void _showAddRobotDialog(BuildContext context) {
    final TextEditingController snController = TextEditingController();
    final TextEditingController orgController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('添加机器人 (Add Robot)', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: snController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '输入设备 SN 码 (e.g., SN001234)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: orgController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '输入机构名称 (Organization)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消 (Cancel)', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (snController.text.trim().isNotEmpty) {
                robotController.addRobotBySn(snController.text.trim(), orgController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('添加 (Add)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBatchAddDialog(BuildContext context) {
    final TextEditingController jsonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('批量添加设备 (Batch Add)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 300,
          child: TextField(
            controller: jsonController,
            maxLines: 15,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: '请输入 JSON 数组，例如：\n[\n  {"name": "深圳市XX机构", "SN": "ZJX110..."}\n]',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消 (Cancel)', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              try {
                var list = jsonDecode(jsonController.text.trim());
                if (list is List) {
                  int successCount = 0;
                  int skipCount = 0;
                  for (var item in list) {
                    if (item is Map && item['SN'] != null) {
                      String sn = item['SN'].toString().trim();
                      String name = item['name']?.toString().trim() ?? '';
                      if (sn.isNotEmpty) {
                        if (!robotController.robots.any((r) => r.id == sn)) {
                          robotController.addRobotBySn(sn, name);
                          successCount++;
                        } else {
                          skipCount++;
                        }
                      }
                    }
                  }
                  Navigator.pop(context);
                  Get.snackbar('批量添加完成', '成功导入 $successCount 个设备，跳过已存在 $skipCount 个', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
                } else {
                  Get.snackbar('格式错误', 'JSON 必须是一个数组 []', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
                }
              } catch (e) {
                Get.snackbar('解析失败', '请输入合法的 JSON 格式', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
              }
            },
            child: const Text('导入 (Import)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: GestureDetector(
        onLongPress: () => _showBatchAddDialog(context),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddRobotDialog(context),
          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
          label: const Text('添加设备', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF3B82F6),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Obx(() {
                  final robots = robotController.robots; // View all robots for pagination
                  if (robots.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 450, // 自动拉伸，最大宽度450
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.1, // 调整卡片的长宽比以自适应内容
                      ),
                      itemCount: robots.length,
                      itemBuilder: (context, index) {
                        return Hero(
                          tag: 'robot_${robots[index].id}',
                          child: RobotCard(
                            key: ValueKey(robots[index].id),
                            robot: robots[index],
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.5),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.dashboard_rounded, color: Color(0xFF3B82F6), size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '骅羲监控系统',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Obx(() {
                final isConnected = mqttController.connectionState.value == MqttConnectionState.connected;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isConnected ? Colors.green : Colors.red).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (isConnected ? Colors.green : Colors.red).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? Colors.greenAccent : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: (isConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isConnected ? 'MQTT 连接正常' : 'MQTT 已断开',
                        style: TextStyle(
                          color: isConnected ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    ],
                  ),
                );
              })
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.satellite_alt_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 24),
          const Text(
            '尚未添加设备',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右下角的"添加设备"按钮输入 SN 码，开始监听机器人状态。',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Obx(() {
      if (robotController.totalPages <= 1) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.swipe_rounded, color: Colors.white54, size: 20),
            const SizedBox(width: 16),
            Text(
              '当前页数: ${robotController.currentPage.value + 1} / ${robotController.totalPages} (可侧滑翻页)',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    });
  }
}
