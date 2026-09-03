import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/robot_controller.dart';
import '../../models/docking_notification_model.dart';
import '../../utils/toast_util.dart';
import '../details/robot_detail_page.dart';

class DockingNotificationPage extends StatefulWidget {
  const DockingNotificationPage({Key? key}) : super(key: key);

  @override
  State<DockingNotificationPage> createState() => _DockingNotificationPageState();
}

class _DockingNotificationPageState extends State<DockingNotificationPage> {
  final RobotController robotController = Get.find<RobotController>();
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
  }

  String _getRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 8),
            Text('清空确认', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '确定要清空所有的充电对桩超时通知记录吗？此操作不可恢复。',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              robotController.clearDockingNotifications();
              ToastUtil.show('对桩通知已清空');
            },
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildNotificationList()),
          ],
        ),
      ),
    );
  }

  /// 顶部标题及全局操作按钮
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.ev_station_rounded, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '充电对桩通知',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: const Text(
                    'cmdId: 88',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '实时监控机器人充电对接状态，捕获对桩超时及失败原因',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        // 一键清空按钮
        Obx(() {
          final count = robotController.dockingNotifications.length;
          if (count == 0) return const SizedBox.shrink();
          return OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => _showClearConfirmDialog(context),
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18),
            label: const Text(
              '清空记录',
              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );
        }),
      ],
    );
  }

  /// 顶部统计卡片（总计、今日上报、涉及机构、涉及设备）
  Widget _buildStatsRow() {
    return Obx(() {
      final list = robotController.dockingNotifications;
      final total = list.length;

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final todayCount = list.where((item) => item.time.isAfter(startOfToday)).length;

      final orgsSet = list.map((e) => e.organization).toSet();
      final devicesSet = list.map((e) => e.sn).toSet();

      return Row(
        children: [
          Expanded(child: _buildStatCard('通知总数', '$total', Icons.receipt_long_rounded, const Color(0xFF3B82F6))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('今日上报', '$todayCount', Icons.today_rounded, const Color(0xFFF59E0B))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('涉及机构', '${orgsSet.length}', Icons.business_rounded, const Color(0xFF10B981))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('涉及设备', '${devicesSet.length}', Icons.precision_manufacturing_rounded, const Color(0xFF8B5CF6))),
        ],
      );
    });
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 搜索框
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索机构名称、设备 SN 或原因内容...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
          suffixIcon: _searchKeyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchKeyword = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (val) {
          setState(() {
            _searchKeyword = val.trim().toLowerCase();
          });
        },
      ),
    );
  }

  /// 通知列表
  Widget _buildNotificationList() {
    return Obx(() {
      var list = robotController.dockingNotifications.toList();

      if (_searchKeyword.isNotEmpty) {
        list = list.where((item) {
          final org = item.organization.toLowerCase();
          final sn = item.sn.toLowerCase();
          final reason = item.reason.toLowerCase();
          return org.contains(_searchKeyword) || sn.contains(_searchKeyword) || reason.contains(_searchKeyword);
        }).toList();
      }

      if (list.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildNotificationCard(item);
        },
      );
    });
  }

  /// 单条通知卡片
  Widget _buildNotificationCard(DockingNotificationItem item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：机构名（突出显示）、设备SN、时间
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_rounded, color: Color(0xFF60A5FA), size: 18),
                    ),
                    const SizedBox(width: 10),
                    // 机构名加粗突出
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.organization.isNotEmpty ? item.organization : '未知机构',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.precision_manufacturing_rounded, size: 13, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(
                                'SN: ${item.sn}',
                                style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace'),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: item.sn));
                                  ToastUtil.show('SN已复制到剪贴板');
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.copy_rounded, size: 13, color: Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 状态徽章与时间
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_off_rounded, color: Color(0xFFF87171), size: 12),
                              SizedBox(width: 4),
                              Text(
                                '对桩超时',
                                style: TextStyle(color: Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _getRelativeTime(item.time),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(item.time),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 第二行：重点展示 reason 内容
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.report_problem_rounded, color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '超时原因 (Reason):',
                              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              item.reason.isNotEmpty ? item.reason : '未提供详细原因说明',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '复制原因',
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFFFBBF24), size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: item.reason));
                          ToastUtil.show('原因已复制');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 第三行：底部标签与操作
                Row(
                  children: [
                    if (item.taskId.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.task_alt_rounded, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              'TaskId: ${item.taskId}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Type: ${item.type} / Subtype: ${item.subtype}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                    const Spacer(),
                    // 查看设备按钮
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () {
                        Get.to(() => RobotDetailPage(robotId: item.sn));
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('查看设备', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    // 删除此条按钮
                    IconButton(
                      tooltip: '删除此条记录',
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
                      onPressed: () {
                        robotController.removeDockingNotification(item.id);
                        ToastUtil.show('已删除');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无对桩超时通知',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            '所有机器人充电对桩运行良好，未检测到超时上报 (cmdId: 88)',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
