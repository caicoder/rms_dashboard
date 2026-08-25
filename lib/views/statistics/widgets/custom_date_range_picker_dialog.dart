import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePickerDialog extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const CustomDateRangePickerDialog({
    Key? key,
    required this.initialStartDate,
    required this.initialEndDate,
  }) : super(key: key);

  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTime initialStartDate,
    required DateTime initialEndDate,
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (context) => CustomDateRangePickerDialog(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }

  @override
  State<CustomDateRangePickerDialog> createState() =>
      _CustomDateRangePickerDialogState();
}

class _CustomDateRangePickerDialogState
    extends State<CustomDateRangePickerDialog> {
  late DateTime _displayedMonth;
  DateTime? _selectedStart;
  DateTime? _selectedEnd;
  final DateFormat _monthFormat = DateFormat('yyyy年 MM月');
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _selectedStart = DateTime(
      widget.initialStartDate.year,
      widget.initialStartDate.month,
      widget.initialStartDate.day,
    );
    _selectedEnd = DateTime(
      widget.initialEndDate.year,
      widget.initialEndDate.month,
      widget.initialEndDate.day,
    );
    _displayedMonth = DateTime(_selectedEnd!.year, _selectedEnd!.month, 1);
  }

  void _onDayTapped(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isAfter(today)) return; // 不能选未来日期

    setState(() {
      if (_selectedStart == null || (_selectedStart != null && _selectedEnd != null)) {
        // 新一轮选择：设置起点
        _selectedStart = date;
        _selectedEnd = null;
      } else if (_selectedStart != null && _selectedEnd == null) {
        // 设置终点
        if (date.isBefore(_selectedStart!)) {
          _selectedEnd = _selectedStart;
          _selectedStart = date;
        } else {
          _selectedEnd = date;
        }
      }
    });
  }

  void _applyQuickPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start;
    DateTime end = today;

    switch (preset) {
      case '今日':
        start = today;
        break;
      case '昨日':
        start = today.subtract(const Duration(days: 1));
        end = start;
        break;
      case '近 3 天':
        start = today.subtract(const Duration(days: 2));
        break;
      case '近 7 天':
        start = today.subtract(const Duration(days: 6));
        break;
      case '近 15 天':
        start = today.subtract(const Duration(days: 14));
        break;
      case '近 30 天':
        start = today.subtract(const Duration(days: 29));
        break;
      case '本月':
        start = DateTime(today.year, today.month, 1);
        break;
      case '上月':
        final lastMonthEnd = DateTime(today.year, today.month, 0);
        start = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
        end = lastMonthEnd;
        break;
      default:
        return;
    }

    setState(() {
      _selectedStart = start;
      _selectedEnd = end;
      _displayedMonth = DateTime(end.year, end.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Dialog Header
                _buildHeader(context),

                const Divider(height: 1, color: Colors.white10),

                // 2. Quick Presets Bar
                _buildQuickPresetsBar(),

                const Divider(height: 1, color: Colors.white10),

                // 3. Calendar View Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      // Month Navigator (< 2026年 8月 >)
                      _buildMonthNavigator(),
                      const SizedBox(height: 10),
                      // Weekday Headers (一 二 三 四 五 六 日)
                      _buildWeekdayHeaders(),
                      const SizedBox(height: 8),
                      // Days Grid
                      _buildDaysGrid(),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white10),

                // 4. Selected Summary Bar & Actions
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择统计时间区间',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '精准分析所选时间段内的设备状态与告警汇总',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
            splashRadius: 20,
            hoverColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetsBar() {
    final presets = ['今日', '昨日', '近 3 天', '近 7 天', '近 15 天', '近 30 天', '本月', '上月'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.black.withOpacity(0.15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: presets.map((preset) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => _applyQuickPreset(preset),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Text(
                    preset,
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    final now = DateTime.now();
    final canGoNext = _displayedMonth.year < now.year ||
        (_displayedMonth.year == now.year && _displayedMonth.month < now.month);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _displayedMonth = DateTime(
                _displayedMonth.year,
                _displayedMonth.month - 1,
                1,
              );
            });
          },
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
          splashRadius: 18,
        ),
        Text(
          _monthFormat.format(_displayedMonth),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        IconButton(
          onPressed: canGoNext
              ? () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month + 1,
                      1,
                    );
                  });
                }
              : null,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: canGoNext ? Colors.white70 : Colors.white24,
          ),
          splashRadius: 18,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: weekdays.map((day) {
        final isWeekend = day == '六' || day == '日';
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                color: isWeekend ? const Color(0xFF60A5FA) : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    
    // weekday 1 = Monday, 7 = Sunday
    final int prefixEmptyDays = firstDayOfMonth.weekday - 1;
    final int totalCells = ((prefixEmptyDays + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.35,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - prefixEmptyDays + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(_displayedMonth.year, _displayedMonth.month, dayNumber);
        final isFuture = date.isAfter(today);
        final isToday = date.isAtSameMomentAs(today);

        final isStart = _selectedStart != null && date.isAtSameMomentAs(_selectedStart!);
        final isEnd = _selectedEnd != null && date.isAtSameMomentAs(_selectedEnd!);
        final isInRange = _selectedStart != null &&
            _selectedEnd != null &&
            date.isAfter(_selectedStart!) &&
            date.isBefore(_selectedEnd!);

        BoxDecoration? rangeDecoration;
        if (isInRange) {
          rangeDecoration = BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
          );
        } else if (isStart && _selectedEnd != null && !_selectedStart!.isAtSameMomentAs(_selectedEnd!)) {
          rangeDecoration = BoxDecoration(
            gradient: LinearGradient(
              stops: const [0.5, 0.5],
              colors: [Colors.transparent, const Color(0xFF3B82F6).withOpacity(0.2)],
            ),
          );
        } else if (isEnd && _selectedStart != null && !_selectedStart!.isAtSameMomentAs(_selectedEnd!)) {
          rangeDecoration = BoxDecoration(
            gradient: LinearGradient(
              stops: const [0.5, 0.5],
              colors: [const Color(0xFF3B82F6).withOpacity(0.2), Colors.transparent],
            ),
          );
        }

        return Container(
          decoration: rangeDecoration,
          child: Center(
            child: InkWell(
              onTap: isFuture ? null : () => _onDayTapped(date),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: (isStart || isEnd)
                      ? const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  shape: BoxShape.circle,
                  border: isToday && !isStart && !isEnd
                      ? Border.all(color: const Color(0xFF60A5FA), width: 1.5)
                      : null,
                  boxShadow: (isStart || isEnd)
                      ? [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: isFuture
                          ? Colors.white24
                          : (isStart || isEnd
                              ? Colors.white
                              : (isInRange
                                  ? const Color(0xFF93C5FD)
                                  : Colors.white70)),
                      fontWeight: (isStart || isEnd || isToday)
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final start = _selectedStart;
    final end = _selectedEnd ?? _selectedStart;

    int daysCount = 0;
    if (start != null && end != null) {
      daysCount = end.difference(start).inDays + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.black.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Selected date range readout
          Expanded(
            child: start != null
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                        ),
                        child: Text(
                          '${_dateFormat.format(start)}  至  ${_dateFormat.format(end!)}',
                          style: const TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '共 $daysCount 天',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  )
                : const Text(
                    '请在日历中点击选择起止日期',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
          ),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: (start != null && end != null)
                    ? () {
                        Navigator.of(context).pop(DateTimeRange(
                          start: start,
                          end: end,
                        ));
                      }
                    : null,
                child: const Text('确认选择', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
