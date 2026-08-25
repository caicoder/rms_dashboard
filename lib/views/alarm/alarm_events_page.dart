import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/robot_controller.dart';
import '../../models/robot_model.dart';
import '../../utils/toast_util.dart';
import '../details/robot_detail_page.dart';

class AlarmEventsPage extends StatefulWidget {
  const AlarmEventsPage({Key? key}) : super(key: key);

  @override
  State<AlarmEventsPage> createState() => _AlarmEventsPageState();
}

class _AlarmEventsPageState extends State<AlarmEventsPage> {
  final RobotController robotController = Get.find<RobotController>();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = '全部';
  String _searchKeyword = '';

  static const String _cosImagePrefix =
      'https://huaxi-1330823579.cos.ap-shanghai.myqcloud.com/robot';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getImageUrls(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return [];
    final parts = rawUrl.split(RegExp(r'[,;]'));
    final List<String> list = [];
    for (var part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        list.add(trimmed);
      } else {
        list.add('$_cosImagePrefix${trimmed.startsWith('/') ? '' : '/'}$trimmed');
      }
    }
    return list;
  }

  Color _getAlarmColor(String title) {
    if (title.contains('跌倒')) return const Color(0xFFEF4444);
    if (title.contains('火焰') || title.contains('火警')) return const Color(0xFFF97316);
    if (title.contains('烟雾')) return const Color(0xFFEAB308);
    return const Color(0xFF3B82F6);
  }

  IconData _getAlarmIcon(String title) {
    if (title.contains('跌倒')) return Icons.personal_injury_rounded;
    if (title.contains('火焰') || title.contains('火警')) return Icons.local_fire_department_rounded;
    if (title.contains('烟雾')) return Icons.cloud_queue_rounded;
    return Icons.warning_amber_rounded;
  }

  void _showLargeImageDialog(
    BuildContext context, {
    required List<String> imageUrls,
    required ActiveAlarmItem alarm,
    int initialIndex = 0,
  }) {
    if (imageUrls.isEmpty) return;
    final alarmColor = _getAlarmColor(alarm.alarmTitle);
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(alarm.time);
    final PageController pageController = PageController(initialPage: initialIndex);
    int activeIndex = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentUrl = imageUrls[activeIndex];

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 950,
                  maxHeight: 720,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: alarmColor.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: alarmColor.withOpacity(0.25),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.8),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: alarmColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: alarmColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getAlarmIcon(alarm.alarmTitle), size: 16, color: alarmColor),
                                const SizedBox(width: 6),
                                Text(
                                  alarm.alarmTitle,
                                  style: TextStyle(
                                    color: alarmColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'SN: ${alarm.robotId}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (alarm.organization.isNotEmpty)
                                  Text(
                                    alarm.organization,
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (imageUrls.length > 1) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                '${activeIndex + 1} / ${imageUrls.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            timeStr,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Large Image Viewport (Interactive Zoom/Pan + PageView with Navigation Arrows)
                    Expanded(
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: pageController,
                            itemCount: imageUrls.length,
                            onPageChanged: (idx) {
                              setDialogState(() {
                                activeIndex = idx;
                              });
                            },
                            itemBuilder: (context, idx) {
                              final url = imageUrls[idx];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.center,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        final percent = progress.expectedTotalBytes != null
                                            ? (progress.cumulativeBytesLoaded / progress.expectedTotalBytes!)
                                            : null;
                                        return Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(
                                                value: percent,
                                                color: alarmColor,
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                '正在加载高清告警抓拍图像...',
                                                style: TextStyle(color: Colors.white60, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                                            const SizedBox(height: 10),
                                            const Text(
                                              '图片加载失败或已过期',
                                              style: TextStyle(color: Colors.white54, fontSize: 13),
                                            ),
                                            const SizedBox(height: 8),
                                            SelectableText(
                                              url,
                                              style: const TextStyle(color: Colors.white30, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Left navigation arrow button
                          if (imageUrls.length > 1 && activeIndex > 0)
                            Positioned(
                              left: 20,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: InkWell(
                                  onTap: () {
                                    pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ),

                          // Right navigation arrow button
                          if (imageUrls.length > 1 && activeIndex < imageUrls.length - 1)
                            Positioned(
                              right: 20,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: InkWell(
                                  onTap: () {
                                    pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Dialog Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.8),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '💡 提示：双指捏合或滚轮可自由放大/缩小查看现场细节',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: currentUrl));
                              ToastUtil.show('图片链接已复制到剪贴板');
                            },
                            icon: const Icon(Icons.link_rounded, size: 16, color: Color(0xFF38BDF8)),
                            label: const Text('复制图片链接', style: TextStyle(color: Color(0xFF38BDF8))),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Get.to(() => RobotDetailPage(robotId: alarm.robotId));
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('前往设备详情'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showClearAllConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('清空所有告警', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          '确定要一键解除并清空当前列表中的所有告警记录吗？此操作无法撤回。',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              robotController.clearAllActiveAlarms();
              ToastUtil.show('已清空全部告警记录');
            },
            child: const Text('确定清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 768;

    return Container(
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
            // Top Header Bar
            _buildTopBar(context, isSmallScreen),

            // Main Content Area
            Expanded(
              child: Obx(() {
                final allAlarms = robotController.activeAlarms;
                final filteredAlarms = allAlarms.where((alarm) {
                  // Filter by Type
                  if (_selectedFilter != '全部') {
                    if (!alarm.alarmTitle.contains(_selectedFilter.replaceAll('告警', ''))) {
                      return false;
                    }
                  }

                  // Filter by Search Keyword
                  if (_searchKeyword.isNotEmpty) {
                    final kw = _searchKeyword.toLowerCase();
                    final matchSn = alarm.robotId.toLowerCase().contains(kw);
                    final matchOrg = alarm.organization.toLowerCase().contains(kw);
                    final matchTitle = alarm.alarmTitle.toLowerCase().contains(kw);
                    if (!matchSn && !matchOrg && !matchTitle) return false;
                  }

                  return true;
                }).toList();

                // Sort by time descending (latest first)
                filteredAlarms.sort((a, b) => b.time.compareTo(a.time));

                if (filteredAlarms.isEmpty) {
                  return _buildEmptyState(allAlarms.isEmpty);
                }

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16.0 : 24.0,
                    vertical: 16.0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.86,
                        ),
                        itemCount: filteredAlarms.length,
                        itemBuilder: (context, index) {
                          final alarm = filteredAlarms[index];
                          return _buildAlarmCard(context, alarm);
                        },
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isSmallScreen) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 24.0,
            vertical: isSmallScreen ? 12.0 : 16.0,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.7),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Quick Actions Row
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '告警事件中心',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Obx(() {
                    final count = robotController.activeAlarms.length;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: count > 0
                            ? const Color(0xFFEF4444).withOpacity(0.2)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: count > 0
                              ? const Color(0xFFEF4444).withOpacity(0.4)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        count > 0 ? '$count 起未解除' : '全部正常',
                        style: TextStyle(
                          color: count > 0 ? const Color(0xFFF87171) : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  // Clear All Button
                  Obx(() {
                    if (robotController.activeAlarms.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                      ),
                      onPressed: () => _showClearAllConfirmDialog(context),
                      icon: const Icon(Icons.cleaning_services_rounded, size: 15),
                      label: const Text('一键清空', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 14),

              // Filter & Search Controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Filter Chips
                  _buildFilterChip('全部'),
                  _buildFilterChip('跌倒告警'),
                  _buildFilterChip('火焰告警'),
                  _buildFilterChip('烟雾告警'),

                  // Search Box
                  Container(
                    width: isSmallScreen ? double.infinity : 220,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '搜索 SN 或机构名称...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 16),
                        suffixIcon: _searchKeyword.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchKeyword = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        setState(() => _searchKeyword = val.trim());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return Obx(() {
      int count = 0;
      final alarms = robotController.activeAlarms;
      if (label == '全部') {
        count = alarms.length;
      } else {
        count = alarms.where((a) => a.alarmTitle.contains(label.replaceAll('告警', ''))).length;
      }

      return InkWell(
        onTap: () {
          setState(() => _selectedFilter = label);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3B82F6).withOpacity(0.2)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6).withOpacity(0.6)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF93C5FD) : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAlarmCard(BuildContext context, ActiveAlarmItem alarm) {
    final alarmColor = _getAlarmColor(alarm.alarmTitle);
    final iconData = _getAlarmIcon(alarm.alarmTitle);
    final timeStr = DateFormat('HH:mm:ss').format(alarm.time);
    final imageUrls = _getImageUrls(alarm.imgUrl);
    final hasImage = imageUrls.isNotEmpty;
    final firstImageUrl = hasImage ? imageUrls.first : '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alarmColor.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: alarmColor.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Badge & Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: alarmColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: alarmColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconData, size: 13, color: alarmColor),
                      const SizedBox(width: 4),
                      Text(
                        alarm.alarmTitle,
                        style: TextStyle(
                          color: alarmColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.access_time_rounded, color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Device Info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing_rounded, size: 14, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'SN: ${alarm.robotId}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (alarm.organization.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    alarm.organization,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Image Snapshot Section (Directly displays image & clickable for zoom modal)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: hasImage
                  ? Tooltip(
                      message: '点击放大查看现场抓拍大图',
                      child: InkWell(
                        onTap: () {
                          _showLargeImageDialog(
                            context,
                            imageUrls: imageUrls,
                            alarm: alarm,
                            initialIndex: 0,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                firstImageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.black26,
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: alarmColor,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.white.withOpacity(0.04),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.image_not_supported_outlined, color: Colors.white30, size: 28),
                                        SizedBox(height: 4),
                                        Text('抓拍图片失效', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Multi-photo count badge (if > 1)
                              if (imageUrls.length > 1)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.photo_library_rounded, size: 11, color: Colors.white70),
                                        const SizedBox(width: 3),
                                        Text(
                                          '共 ${imageUrls.length} 张',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Hover / Tap overlay indicator
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                                      SizedBox(width: 3),
                                      Text('点击放大', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 30),
                          SizedBox(height: 6),
                          Text('暂无现场抓拍图片', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
            ),
          ),

          // Card Footer Actions
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Get.to(() => RobotDetailPage(robotId: alarm.robotId));
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text(
                            '详情',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    robotController.removeActiveAlarm(alarm);
                    ToastUtil.show('已解除告警');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          '知道了',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
            ),
            child: const Center(
              child: Icon(
                Icons.verified_user_rounded,
                size: 42,
                color: Color(0xFF34D399),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isCompletelyEmpty ? '暂无未处理告警事件' : '未找到符合条件的告警记录',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompletelyEmpty ? '所有巡检机器人均处于平稳运行状态' : '请尝试调整筛选条件或搜索关键词',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
