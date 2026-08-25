import 'package:flutter/material.dart';
import '../../../models/dashboard_stats_model.dart';

class AbnormalSummaryWidget extends StatelessWidget {
  final AbnormalSummary? summary;

  const AbnormalSummaryWidget({Key? key, this.summary}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = summary ?? AbnormalSummary();

    final List<Map<String, dynamic>> items = [
      {'title': '急停总次数', 'value': data.emergencyStopCount, 'color': const Color(0xFFEF4444)},
      {'title': '规划失败总次数', 'value': data.planningFailCount, 'color': const Color(0xFFF97316)},
      {'title': '定位丢失总次数', 'value': data.locationLostCount, 'color': const Color(0xFFEAB308)},
      {'title': '网络异常总次数', 'value': data.networkAbnormalCount, 'color': const Color(0xFF3B82F6)},
      {'title': '低电量告警总次数', 'value': data.lowBatteryAlarmCount, 'color': const Color(0xFFF59E0B)},
      {'title': 'AI 事件未解除总数', 'value': data.aiEventUnresolvedCount, 'color': const Color(0xFFA855F7)},
      {'title': '火焰告警总次数', 'value': data.lightTapAlarmCount, 'color': const Color(0xFFDC2626)},
      {'title': '跌倒告警总次数', 'value': data.fallAlarmCount, 'color': const Color(0xFFEC4899)},
      {'title': '甲烷告警总次数', 'value': data.methaneAlarmCount, 'color': const Color(0xFF14B8A6)},
      {'title': '烟雾告警总次数', 'value': data.smokeAlarmCount, 'color': const Color(0xFF64748B)},
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
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '二、异常类型累计汇总（所选周期内全设备总次数）',
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

          // Blueprint Table matching the screenshot
          _buildStructuredSummaryTable(items),
        ],
      ),
    );
  }

  Widget _buildStructuredSummaryTable(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4), width: 1.2),
        ),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.3), width: 1),
            verticalInside: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.3), width: 1),
          ),
          children: [
            // Header Row: 异常类型 + All titles
            TableRow(
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.15),
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Center(
                    child: Text(
                      '异常类型',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                ...items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Center(
                      child: Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
            // Value Row: 累计值 + All values
            TableRow(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Center(
                    child: Text(
                      '累计值',
                      style: TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                ...items.map((item) {
                  final Color c = item['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Center(
                      child: Text(
                        '${item['value']}',
                        style: TextStyle(
                          color: c,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
