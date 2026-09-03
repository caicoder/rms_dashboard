import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/device_report_controller.dart';
import 'widgets/status_overview_widget.dart';
import 'widgets/abnormal_summary_widget.dart';
import 'widgets/main_statistics_table_widget.dart';
import 'widgets/custom_date_range_picker_dialog.dart';

class DeviceExceptionReportPage extends StatelessWidget {
  DeviceExceptionReportPage({Key? key}) : super(key: key);

  final DeviceReportController controller = Get.put(DeviceReportController());

  void _showCustomDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await CustomDateRangePickerDialog.show(
      context,
      initialStartDate: controller.startDate.value,
      initialEndDate: controller.endDate.value,
    );

    if (picked != null) {
      controller.setCustomRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
              // Top Functional Area / Header Bar
              _buildTopFunctionBar(context, isSmallScreen),

              // Main Scrollable Content
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value && controller.reportData.value == null) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF3B82F6)),
                          SizedBox(height: 16),
                          Text(
                            '正在加载统计数据...',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = controller.reportData.value;
                  final hasError = controller.errorMessage.value.isNotEmpty;

                  return RefreshIndicator(
                    onRefresh: () async {
                      await controller.fetchData(isManual: true);
                    },
                    color: const Color(0xFF3B82F6),
                    backgroundColor: const Color(0xFF1E293B),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16.0 : 24.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error Alert Banner
                          if (hasError) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '提示: ${controller.errorMessage.value}',
                                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => controller.manualForceRefresh(),
                                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                    label: const Text('重试', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444).withOpacity(0.3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 一、设备状态概览（所选周期内）
                          StatusOverviewWidget(overview: data?.statusOverview),
                          const SizedBox(height: 20),

                          // 二、异常类型累计汇总（所选周期内全设备总次数）
                          AbnormalSummaryWidget(summary: data?.abnormalSummary),
                          const SizedBox(height: 20),

                          // 三、主统计表格
                          MainStatisticsTableWidget(items: data?.statisticsList ?? []),
                          const SizedBox(height: 40),
                        ],
                      ),
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

  Widget _buildTopFunctionBar(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16.0 : 24.0,
        vertical: isSmallScreen ? 12.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title and Refresh Status & Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title Badge
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assessment_rounded,
                        color: Color(0xFF3B82F6),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '设备异常情况上报统计',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Obx(() => Text(
                                '统计周期: ${controller.dateRangeDisplay}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Refresh Status & Force Refresh Button
              Obx(() {
                final isAuto = controller.selectedDimension.value == TimeDimension.today;
                final isUpdating = controller.isLoading.value || controller.isRefreshing.value;
                final lastTime = controller.lastUpdateTime.value;
                final lastTimeStr = lastTime != null ? DateFormat('HH:mm:ss').format(lastTime) : '--:--:--';

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Auto-refresh badge (only show when active on today)
                    if (!isSmallScreen && isAuto) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF10B981),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '今日数据自动刷新 (1分钟/次)',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Manual Force Refresh Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isUpdating ? null : () => controller.manualForceRefresh(),
                      icon: isUpdating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Row(
                        children: [
                          Text(
                            isUpdating ? '刷新中' : '强制刷新',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (!isSmallScreen) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($lastTimeStr)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Time Dimension Switch Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Obx(() {
              final current = controller.selectedDimension.value;

              return Row(
                children: [
                  _buildDimensionChip(
                    title: '今日',
                    isSelected: current == TimeDimension.today,
                    onTap: () => controller.setDimension(TimeDimension.today),
                  ),
                  const SizedBox(width: 8),
                  _buildDimensionChip(
                    title: '昨日',
                    isSelected: current == TimeDimension.yesterday,
                    onTap: () => controller.setDimension(TimeDimension.yesterday),
                  ),
                  const SizedBox(width: 8),
                  _buildDimensionChip(
                    title: '近 7 天',
                    isSelected: current == TimeDimension.last7Days,
                    onTap: () => controller.setDimension(TimeDimension.last7Days),
                  ),
                  const SizedBox(width: 8),
                  _buildDimensionChip(
                    title: current == TimeDimension.custom
                        ? '自定义: ${DateFormat('MM-dd').format(controller.startDate.value)}~${DateFormat('MM-dd').format(controller.endDate.value)}'
                        : '自定义日期',
                    isSelected: current == TimeDimension.custom,
                    icon: Icons.calendar_month_rounded,
                    onTap: () {
                      _showCustomDateRangePicker(context);
                    },
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionChip({
    required String title,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.12),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
