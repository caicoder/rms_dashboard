import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/robot_controller.dart';
import '../../models/anomaly_notification_model.dart';
import '../../utils/toast_util.dart';
import '../details/robot_detail_page.dart';

class AnomalyNotificationPage extends StatefulWidget {
  const AnomalyNotificationPage({Key? key}) : super(key: key);

  @override
  State<AnomalyNotificationPage> createState() => _AnomalyNotificationPageState();
}

class _AnomalyNotificationPageState extends State<AnomalyNotificationPage> {
  final RobotController robotController = Get.find<RobotController>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  
  String _searchKeyword = '';
  String _selectedOrg = '全部'; // '全部' 或具体机构名

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
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

  /// 一键清除所有机构通知的确认弹窗
  void _showClearAllConfirmDialog(BuildContext context) {
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
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('一键清空全部', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '确定要清空所有机构的所有异常通知记录（急停与疑似停止不动）吗？此操作不可撤销。',
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
              robotController.clearAllAnomalyNotifications();
              ToastUtil.show('已清空所有异常通知');
            },
            child: const Text('确认一键清空'),
          ),
        ],
      ),
    );
  }

  /// 清除指定机构全部通知的确认框
  void _showClearOrgConfirmDialog(BuildContext context, String orgName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            const Icon(Icons.business_rounded, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '清空「$orgName」通知',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          '确定要清空机构「$orgName」下的所有急停与静止异常通知吗？',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              robotController.clearAnomalyNotificationsByOrg(orgName);
              ToastUtil.show('已清空 $orgName 的全部通知');
            },
            child: const Text('清空该机构'),
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
            _buildHorizontalOrgBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildMainContent(context)),
          ],
        ),
      ),
    );
  }

  /// 顶部标题及全局操作栏
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.notification_important_rounded, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '设备异常预警',
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
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: const Text(
                    '急停触发 / 疑似停滞',
                    style: TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '按机构区分展示设备急停与停止不动检测，支持分机构清理与一键清除',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        // 搜索框
        Container(
          width: 260,
          height: 40,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '搜索机构/SN/内容...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchKeyword = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (val) {
              setState(() {
                _searchKeyword = val.trim().toLowerCase();
              });
            },
          ),
        ),
        // 一键清除全部按钮
        Obx(() {
          final count = robotController.anomalyNotifications.length;
          if (count == 0) return const SizedBox.shrink();
          return ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
              foregroundColor: const Color(0xFFF87171),
              side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => _showClearAllConfirmDialog(context),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text(
              '一键清除全部',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );
        }),
      ],
    );
  }

  /// 统计卡片栏（急停、疑似停止、涉及机构、涉及设备）
  Widget _buildStatsRow() {
    return Obx(() {
      final list = robotController.anomalyNotifications;
      final estopCount = list.where((e) => e.type == AnomalyType.estop).length;
      final stuckCount = list.where((e) => e.type == AnomalyType.stuck).length;

      final orgsSet = list.map((e) => e.organization.isNotEmpty ? e.organization : '未知机构').toSet();
      final devicesSet = list.map((e) => e.robotId).toSet();

      return Row(
        children: [
          Expanded(child: _buildStatCard('急停通知', '$estopCount', Icons.pan_tool_rounded, const Color(0xFFEF4444))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('疑似停止不动', '$stuckCount', Icons.pause_circle_outline_rounded, const Color(0xFFF59E0B))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('异常涉及机构', '${orgsSet.length}', Icons.business_rounded, const Color(0xFF3B82F6))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('异常涉及设备', '${devicesSet.length}', Icons.precision_manufacturing_rounded, const Color(0xFF8B5CF6))),
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

  /// 横向排开机构栏（显示机构名与通知数量小消息徽标）
  Widget _buildHorizontalOrgBar() {
    return Obx(() {
      final list = robotController.anomalyNotifications;
      if (list.isEmpty) return const SizedBox.shrink();

      // 统计各机构通知数
      final Map<String, int> orgCountMap = {};
      for (var item in list) {
        final org = item.organization.isNotEmpty ? item.organization : '未知机构';
        orgCountMap[org] = (orgCountMap[org] ?? 0) + 1;
      }

      final orgList = orgCountMap.keys.toList();
      final totalCount = list.length;

      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: false,
          child: ListView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            children: [
              // 全部机构 Tab
              _buildOrgChip(
                orgName: '全部',
                count: totalCount,
                isSelected: _selectedOrg == '全部',
                onTap: () => setState(() => _selectedOrg = '全部'),
              ),
              const SizedBox(width: 8),
              // 各机构 Tab 横向排开
              ...orgList.map((org) {
                final count = orgCountMap[org] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildOrgChip(
                    orgName: org,
                    count: count,
                    isSelected: _selectedOrg == org,
                    onTap: () => setState(() => _selectedOrg = org),
                    onClear: () => _showClearOrgConfirmDialog(context, org),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildOrgChip({
    required String orgName,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.6) : Colors.white.withOpacity(0.08),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              orgName == '全部' ? Icons.grid_view_rounded : Icons.business_rounded,
              size: 16,
              color: isSelected ? const Color(0xFF60A5FA) : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              orgName == '全部' ? '全部机构看板' : orgName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 8),
            // 该机构下面多少条通知小消息的徽标
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFEF4444).withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (onClear != null && isSelected) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: '清空 $orgName 的通知',
                child: InkWell(
                  onTap: onClear,
                  child: const Icon(Icons.cancel_rounded, size: 15, color: Color(0xFFF87171)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 页面主体内容：横向排开机构列（全部模式）或单机构纵向列表（选中具体机构模式）
  Widget _buildMainContent(BuildContext context) {
    return Obx(() {
      var list = robotController.anomalyNotifications.toList();

      if (_searchKeyword.isNotEmpty) {
        list = list.where((item) {
          final org = item.organization.toLowerCase();
          final sn = item.robotId.toLowerCase();
          final title = item.title.toLowerCase();
          final msg = item.message.toLowerCase();
          return org.contains(_searchKeyword) ||
              sn.contains(_searchKeyword) ||
              title.contains(_searchKeyword) ||
              msg.contains(_searchKeyword);
        }).toList();
      }

      if (list.isEmpty) {
        return _buildEmptyState();
      }

      // 整理各个机构的数据
      final Map<String, List<AnomalyNotificationItem>> orgGroupMap = {};
      for (var item in list) {
        final org = item.organization.isNotEmpty ? item.organization : '未知机构';
        orgGroupMap.putIfAbsent(org, () => []).add(item);
      }

      // 如果选中了具体机构
      if (_selectedOrg != '全部' && orgGroupMap.containsKey(_selectedOrg)) {
        final orgItems = orgGroupMap[_selectedOrg]!;
        return _buildSingleOrgView(context, _selectedOrg, orgItems);
      }

      // 默认“全部”：横向排开机构列看板（每列纵向显示该机构下的通知卡片）
      final orgNames = orgGroupMap.keys.toList();
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: orgNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final orgName = orgNames[index];
          final items = orgGroupMap[orgName]!;
          return _buildOrgKanbanColumn(context, orgName, items);
        },
      );
    });
  }

  /// 单机构视图（选中具体机构时）
  Widget _buildSingleOrgView(
    BuildContext context,
    String orgName,
    List<AnomalyNotificationItem> items,
  ) {
    return Column(
      children: [
        // 机构专属顶部信息栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.business_rounded, color: Color(0xFF60A5FA), size: 20),
              const SizedBox(width: 10),
              Text(
                orgName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} 条通知',
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              // 清除该机构全部按钮
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => _showClearOrgConfirmDialog(context, orgName),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('清除该机构全部', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        // 纵向列表
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildNotificationCard(items[index]);
            },
          ),
        ),
      ],
    );
  }

  /// 横向排开的机构看板列（Kanban Column）
  Widget _buildOrgKanbanColumn(
    BuildContext context,
    String orgName,
    List<AnomalyNotificationItem> items,
  ) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 机构列 Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_rounded, color: Color(0xFF60A5FA), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orgName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // 机构下面多少条通知徽标
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: Text(
                    '${items.length}条',
                    style: const TextStyle(color: Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                // 某个机构全部清除按钮
                Tooltip(
                  message: '清除「$orgName」全部通知',
                  child: InkWell(
                    onTap: () => _showClearOrgConfirmDialog(context, orgName),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFF87171), size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 纵向显示该机构下的通知内容
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildNotificationCard(items[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 单条通知卡片
  Widget _buildNotificationCard(AnomalyNotificationItem item) {
    final isEstop = item.type == AnomalyType.estop;
    final primaryColor = isEstop ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final badgeText = isEstop ? '急停触发' : '疑似停止不动';
    final badgeIcon = isEstop ? Icons.pan_tool_rounded : Icons.pause_circle_outline_rounded;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：状态徽章 + SN + 时间
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: primaryColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: primaryColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.precision_manufacturing_rounded, size: 13, color: Colors.white54),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          item.robotId,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: item.robotId));
                          ToastUtil.show('SN已复制');
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.copy_rounded, size: 12, color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getRelativeTime(item.time),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.time),
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 第二行：标题
            Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // 第三行：内容详情
            Text(
              item.message,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            // 第四行：坐标与快捷操作
            Row(
              children: [
                if (item.positionX != null && item.positionY != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'X: ${item.positionX!.toStringAsFixed(2)}, Y: ${item.positionY!.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontFamily: 'monospace'),
                    ),
                  ),
                const Spacer(),
                // 查看设备
                InkWell(
                  onTap: () {
                    Get.to(() => RobotDetailPage(robotId: item.robotId));
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 13, color: Colors.blueAccent),
                        SizedBox(width: 2),
                        Text('查看', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 单条删除
                InkWell(
                  onTap: () {
                    robotController.removeAnomalyNotification(item.id);
                    ToastUtil.show('已清除该条通知');
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.close_rounded, size: 14, color: Colors.white38),
                  ),
                ),
              ],
            ),
          ],
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
            '暂无设备异常预警',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            '所有机构设备运行正常，未检测到急停触发或停止不动异常',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
