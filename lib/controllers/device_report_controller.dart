import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:intl/intl.dart';
import 'dashboard_tab_controller.dart';
import '../models/dashboard_stats_model.dart';
import '../utils/log_util.dart';
import '../utils/toast_util.dart';

enum TimeDimension {
  today,
  yesterday,
  last7Days,
  custom,
}

class DeviceReportController extends GetxController {
  final Rx<TimeDimension> selectedDimension = TimeDimension.today.obs;
  final Rx<DateTime> startDate = DateTime.now().obs;
  final Rx<DateTime> endDate = DateTime.now().obs;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<DateTime?> lastUpdateTime = Rx<DateTime?>(null);

  final Rx<DashboardStatsModel?> reportData = Rx<DashboardStatsModel?>(null);

  Timer? _autoRefreshTimer;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const String _apiEndpoint = 'https://prod-api.huaxiai.com.cn/monitor/dashboard';
  static const String _apiPassword = 'hx@082000X';

  @override
  void onInit() {
    super.onInit();
    _applyDimension(TimeDimension.today, fetchImmediately: false);
    fetchData();
    _setupTabListener();
    _checkAndStartTimer();
  }

  @override
  void onClose() {
    _stopAutoRefreshTimer();
    super.onClose();
  }

  void _setupTabListener() {
    try {
      if (Get.isRegistered<DashboardTabController>()) {
        final tabController = Get.find<DashboardTabController>();
        ever(tabController.selectedTabIndex, (int index) {
          if (index == 1) {
            // 切入异常统计页面
            _checkAndStartTimer();
          } else {
            // 切出异常统计页面（如设备监控Tab），立即停止定时器
            _stopAutoRefreshTimer();
          }
        });
      }
    } catch (_) {}
  }

  bool get _isTabActive {
    try {
      if (Get.isRegistered<DashboardTabController>()) {
        return Get.find<DashboardTabController>().selectedTabIndex.value == 1;
      }
    } catch (_) {}
    return true;
  }

  void _checkAndStartTimer() {
    _stopAutoRefreshTimer();
    if (_isTabActive && selectedDimension.value == TimeDimension.today) {
      _startAutoRefreshTimer();
    }
  }

  void _startAutoRefreshTimer() {
    _stopAutoRefreshTimer();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_isTabActive && selectedDimension.value == TimeDimension.today) {
        debugPrint('[DeviceReportController] 触发今日数据 1 分钟自动刷新...');
        fetchData(isAutoRefresh: true);
      } else {
        _stopAutoRefreshTimer();
      }
    });
  }

  void _stopAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  void setDimension(TimeDimension dimension) {
    if (selectedDimension.value == dimension && dimension != TimeDimension.custom) {
      return;
    }
    _applyDimension(dimension, fetchImmediately: true);
    _checkAndStartTimer();
  }

  void setCustomRange(DateTime start, DateTime end) {
    selectedDimension.value = TimeDimension.custom;
    startDate.value = DateTime(start.year, start.month, start.day, 0, 0, 0);
    endDate.value = DateTime(end.year, end.month, end.day, 23, 59, 59);
    _stopAutoRefreshTimer();
    fetchData();
  }

  void _applyDimension(TimeDimension dimension, {bool fetchImmediately = true}) {
    selectedDimension.value = dimension;
    final now = DateTime.now();

    switch (dimension) {
      case TimeDimension.today:
        startDate.value = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case TimeDimension.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate.value = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
        endDate.value = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case TimeDimension.last7Days:
        final sevenDaysAgo = now.subtract(const Duration(days: 6));
        startDate.value = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day, 0, 0, 0);
        endDate.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case TimeDimension.custom:
        // Keep existing custom range or default to today
        break;
    }

    if (fetchImmediately) {
      fetchData();
    }
  }

  String get formattedStartDate => _dateFormat.format(startDate.value);
  String get formattedEndDate => _dateFormat.format(endDate.value);
  String get dateRangeDisplay {
    if (selectedDimension.value == TimeDimension.today) {
      return '今日 (${_dayFormat.format(startDate.value)})';
    } else if (selectedDimension.value == TimeDimension.yesterday) {
      return '昨日 (${_dayFormat.format(startDate.value)})';
    } else {
      return '${_dayFormat.format(startDate.value)} ~ ${_dayFormat.format(endDate.value)}';
    }
  }

  Future<void> fetchData({bool isAutoRefresh = false, bool isManual = false}) async {
    if (isAutoRefresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    errorMessage.value = '';

    final queryParams = {
      'startDate': formattedStartDate,
      'endDate': formattedEndDate,
      'passWord': _apiPassword,
    };

    LogUtil.d('[DeviceReportController] 请求统计数据: $_apiEndpoint, params: $queryParams');

    try {
      final response = await _dio.get(
        _apiEndpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final dataMap = response.data is Map ? response.data : null;
        if (dataMap != null && (dataMap['code'] == 200 || dataMap['code'] == null)) {
          final rawData = dataMap['data'] ?? dataMap;
          if (rawData is Map<String, dynamic>) {
            reportData.value = DashboardStatsModel.fromJson(rawData);
            lastUpdateTime.value = DateTime.now();
            if (isManual) {
              ToastUtil.show('数据刷新成功');
            }
          } else {
            errorMessage.value = '返回数据格式不正确';
          }
        } else {
          errorMessage.value = dataMap?['msg']?.toString() ?? '获取统计数据失败';
          if (isManual) {
            ToastUtil.show(errorMessage.value);
          }
        }
      } else {
        errorMessage.value = '服务器响应异常: ${response.statusCode}';
      }
    } on DioException catch (dioErr) {
      LogUtil.e('[DeviceReportController] DioError: $dioErr');
      errorMessage.value = '网络请求失败，请检查网络连接 (${dioErr.message})';
      if (isManual) {
        ToastUtil.show(errorMessage.value);
      }
    } catch (e) {
      LogUtil.e('[DeviceReportController] Exception: $e');
      errorMessage.value = '请求出错: $e';
      if (isManual) {
        ToastUtil.show(errorMessage.value);
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  void manualForceRefresh() {
    fetchData(isManual: true);
  }
}
