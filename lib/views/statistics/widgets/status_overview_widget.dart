import 'package:flutter/material.dart';
import '../../../models/dashboard_stats_model.dart';

class StatusOverviewWidget extends StatelessWidget {
  final StatusOverview? overview;

  const StatusOverviewWidget({Key? key, this.overview}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = overview ?? StatusOverview();

    final List<Map<String, dynamic>> items = [
      {
        'title': '总设备数',
        'value': data.totalDeviceCount,
        'icon': Icons.devices_other_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': '在线设备',
        'value': data.onlineDeviceCount,
        'icon': Icons.check_circle_outline_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': '离线 (≤1小时)',
        'value': data.offlineWithinHourCount,
        'icon': Icons.access_time_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': '离线 (>1小时)',
        'value': data.offlineOverHourCount,
        'icon': Icons.cloud_off_rounded,
        'color': const Color(0xFF64748B),
      },
      {
        'title': '异常停用设备',
        'value': data.abnormalDisabledCount,
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'title': '低电量设备',
        'value': data.lowBatteryCount,
        'icon': Icons.battery_alert_rounded,
        'color': const Color(0xFFF97316),
      },
      {
        'title': '急停触发设备',
        'value': data.disableTriggerCount,
        'icon': Icons.stop_circle_outlined,
        'color': const Color(0xFFE11D48),
      },
      {
        'title': '存在异常设备总数',
        'value': data.totalAbnormalDeviceCount,
        'icon': Icons.error_outline_rounded,
        'color': const Color(0xFFA855F7),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '一、设备状态概览（所选周期内）',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 8;
              if (constraints.maxWidth < 600) {
                crossAxisCount = 2;
              } else if (constraints.maxWidth < 900) {
                crossAxisCount = 4;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: crossAxisCount >= 8 ? 1.2 : 1.6,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final Color itemColor = item['color'] as Color;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: itemColor.withOpacity(0.25)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item['icon'] as IconData, size: 16, color: itemColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item['title'] as String,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item['value']}',
                          style: TextStyle(
                            color: itemColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
