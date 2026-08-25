import 'package:flutter/material.dart';
import '../../../models/dashboard_stats_model.dart';
import '../../../utils/todesk_helper.dart';

class MainStatisticsTableWidget extends StatelessWidget {
  final List<DeviceStatisticsItem> items;

  const MainStatisticsTableWidget({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '主统计表格',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '共 ${items.length} 台设备',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  const Text(
                    '暂无设备统计数据',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 80),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.25),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        dataTableTheme: const DataTableThemeData(
                          dividerThickness: 0.0,
                        ),
                      ),
                      child: DataTable(
                        horizontalMargin: 16,
                        columnSpacing: 24,
                        headingRowHeight: 48,
                        dataRowMinHeight: 50,
                        dataRowMaxHeight: 54,
                        dividerThickness: 0.0,
                        border: const TableBorder(
                          horizontalInside: BorderSide.none,
                          verticalInside: BorderSide.none,
                          top: BorderSide.none,
                          bottom: BorderSide.none,
                          left: BorderSide.none,
                          right: BorderSide.none,
                        ),
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFF1E3A8A).withOpacity(0.35),
                        ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            '序号',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '设备名称',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '设备 SN',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ToDesk 号码',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '在线状态（含离线时长）',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '当前电量',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '急停状态',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '导航功能',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '离线点距离',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '急停次数',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '规划失败',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '定位丢失',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                      rows: items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isEven = idx % 2 == 0;
                        final isOnline = item.onlineStatus.contains('在线') && !item.onlineStatus.contains('离线');
                        final isEStopTriggered = item.disableStatus == '拍下' || item.disableStatus == '触发' || item.disableStatus == '异常';
                        
                        int batteryVal = 0;
                        if (item.currentBattery is int) {
                          batteryVal = item.currentBattery as int;
                        } else if (item.currentBattery != null) {
                          batteryVal = int.tryParse(item.currentBattery.toString().replaceAll('%', '')) ?? 0;
                        }

                        Color batteryColor = const Color(0xFF10B981);
                        if (batteryVal < 20) {
                          batteryColor = const Color(0xFFEF4444);
                        } else if (batteryVal < 50) {
                          batteryColor = const Color(0xFFF59E0B);
                        }

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                            if (states.contains(WidgetState.hovered)) {
                              return const Color(0xFF3B82F6).withOpacity(0.18);
                            }
                            // 一行深色，一行浅色交叉高质感斑马纹
                            return isEven
                                ? const Color(0xFF1E293B).withOpacity(0.55)
                                : const Color(0xFF0F172A).withOpacity(0.35);
                          }),
                      cells: [
                        // 序号
                        DataCell(
                          Text(
                            '${item.index}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        // 设备名称
                        DataCell(
                          Text(
                            item.deviceName.isNotEmpty ? item.deviceName : '--',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // 设备 SN
                        DataCell(
                          Text(
                            item.deviceSn.isNotEmpty ? item.deviceSn : '--',
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // ToDesk 号码
                        DataCell(
                          _TodeskCellWidget(
                            deviceSn: item.deviceSn,
                            defaultToDeskNumber: item.toDeskNumber,
                          ),
                        ),
                        // 在线状态
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.onlineStatus.isNotEmpty ? item.onlineStatus : (isOnline ? '在线' : '离线'),
                                  style: TextStyle(
                                    color: isOnline ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 当前电量
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                batteryVal < 20 ? Icons.battery_alert_rounded : Icons.battery_charging_full_rounded,
                                size: 16,
                                color: batteryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$batteryVal%',
                                style: TextStyle(
                                  color: batteryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 急停状态
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isEStopTriggered ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.disableStatus.isNotEmpty ? item.disableStatus : (isEStopTriggered ? '拍下' : '释放'),
                              style: TextStyle(
                                color: isEStopTriggered ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // 导航功能
                        DataCell(
                          Text(
                            item.navigationFunction.isNotEmpty ? item.navigationFunction : '正常',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        // 离线点距离
                        DataCell(
                          Text(
                            item.offlinePointDistance.isNotEmpty ? item.offlinePointDistance : '0.0 m',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        // 急停次数
                        DataCell(
                          Center(
                            child: Text(
                              '${item.disableCount}',
                              style: TextStyle(
                                color: item.disableCount > 0 ? const Color(0xFFEF4444) : Colors.white70,
                                fontWeight: item.disableCount > 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        // 规划失败
                        DataCell(
                          Center(
                            child: Text(
                              '${item.planningCount}',
                              style: TextStyle(
                                color: item.planningCount > 0 ? const Color(0xFFF97316) : Colors.white70,
                                fontWeight: item.planningCount > 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        // 定位丢失
                        DataCell(
                          Center(
                            child: Text(
                              '${item.locationCount}',
                              style: TextStyle(
                                color: item.locationCount > 0 ? const Color(0xFFEAB308) : Colors.white70,
                                fontWeight: item.locationCount > 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _TodeskCellWidget extends StatelessWidget {
  final String deviceSn;
  final String defaultToDeskNumber;

  const _TodeskCellWidget({
    Key? key,
    required this.deviceSn,
    required this.defaultToDeskNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (deviceSn.trim().isEmpty) {
      return Text(
        defaultToDeskNumber.isNotEmpty ? defaultToDeskNumber : '--',
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: TodeskHelper.fetchTodeskConfig(deviceSn),
      builder: (context, snapshot) {
        final config = snapshot.data;
        if (config != null && config.isNotEmpty) {
          final clientId = config['clientid']?.toString() ??
              (defaultToDeskNumber.isNotEmpty ? defaultToDeskNumber : 'ToDesk');
          return Tooltip(
            message: '点击查看 ToDesk 配置并直连',
            child: InkWell(
              onTap: () {
                TodeskHelper.showTodeskDetailDialog(
                  context,
                  deviceSn: deviceSn,
                  config: config,
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.desktop_windows_rounded,
                      size: 13,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      clientId,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            defaultToDeskNumber.isNotEmpty ? defaultToDeskNumber : '...',
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          );
        }

        return Text(
          defaultToDeskNumber.isNotEmpty ? defaultToDeskNumber : '--',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        );
      },
    );
  }
}

