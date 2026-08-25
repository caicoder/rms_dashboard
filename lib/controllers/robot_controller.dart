import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/notification_helper.dart';
import '../services/online_player.dart';
import '../models/robot_model.dart';
import '../views/details/robot_detail_page.dart';
import 'mqtt_controller.dart';

class RobotController extends GetxController {
  var robots = <RobotModel>[].obs;
  final Map<String, RobotModel> _robotsMap = {};
  var activeAlarms = <ActiveAlarmItem>[].obs;
  var notifications = <NotificationMessageItem>[].obs;
  var todeskConfigs = <String, Map<String, dynamic>>{}.obs;
  
  final Map<String, DateTime> _lastStuckNotifyTime = {};
  final Map<String, DateTime> _lastEstopNotifyTime = {};
  
  var searchQuery = ''.obs; // 搜索关键字
  var selectedTypeFilter = (-1).obs; // -1 表示全部，>=0 表示按 type 筛选
  var isAlarmsCollapsed = false.obs; // 告警面板是否收起
  var selectedRightTab = 0.obs; // 右侧面板Tab: 0-告警, 1-通知
  
  final AudioPlayer _audioPlayer = AudioPlayer(); // 音频播放器
  
  var currentPage = 0.obs;
  final int itemsPerPage = 16;
  Timer? _offlineCheckTimer;

  int get totalPages => (filteredRobots.isEmpty) ? 1 : (filteredRobots.length / itemsPerPage).ceil();

  List<RobotModel> get filteredRobots {
    List<RobotModel> list = robots;
    if (selectedTypeFilter.value == -4) {
      list = list.where((r) => !r.isOffline).toList();
    } else if (selectedTypeFilter.value == -2) {
      list = list.where((r) => r.eStop).toList();
    } else if (selectedTypeFilter.value == -3) {
      list = list.where((r) => r.isOffline).toList();
    } else if (selectedTypeFilter.value != -1) {
      list = list.where((r) => r.type == selectedTypeFilter.value).toList();
    }
    
    if (searchQuery.value.trim().isEmpty) {
      return list;
    }
    final query = searchQuery.value.trim().toLowerCase();
    return list.where((r) {
      return r.id.toLowerCase().contains(query) ||
             r.organization.toLowerCase().contains(query);
    }).toList();
  }

  List<RobotModel> get currentRobots {
    final list = filteredRobots;
    if (list.isEmpty) return [];
    int start = currentPage.value * itemsPerPage;
    int end = start + itemsPerPage;
    if (end > list.length) end = list.length;
    return list.sublist(start, end);
  }

  void toggleFavorite(String id) {
    var robot = _robotsMap[id];
    if (robot != null) {
      robot.isFavorite = !robot.isFavorite;
      _sortRobots();
      robots.refresh();
      saveRobots();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadRobots();
    // 每 5 分钟定时刷新一次 UI，检查离线状态并排序
    _offlineCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _sortRobots();
      robots.refresh();
    });
  }

  @override
  void onClose() {
    _offlineCheckTimer?.cancel();
    super.onClose();
  }

  bool _isLoaded = false;

  Future<void> _loadRobots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? robotsJsonList = prefs.getStringList('cached_robots');
      if (robotsJsonList != null) {
        List<RobotModel> loadedRobots = [];
        for (var jsonStr in robotsJsonList) {
          try {
            var decoded = jsonDecode(jsonStr);
            loadedRobots.add(RobotModel.fromJson(decoded));
          } catch (e) {
            print('Error parsing a robot from cache: $e');
          }
        }
        robots.value = loadedRobots;
        for (var r in robots) {
          _robotsMap[r.id] = r;
        }
        _sortRobots();
      }
      final List<String>? deletedIds = prefs.getStringList('deleted_robots');
      if (deletedIds != null) {
        _deletedRobots.addAll(deletedIds);
      }
      final List<String>? alarmsJsonList = prefs.getStringList('active_alarms');
      if (alarmsJsonList != null) {
        activeAlarms.value = alarmsJsonList.map((e) => ActiveAlarmItem.fromJson(jsonDecode(e))).toList();
      }
      final List<String>? notifJsonList = prefs.getStringList('notifications_list');
      if (notifJsonList != null) {
        notifications.value = notifJsonList.map((e) => NotificationMessageItem.fromJson(jsonDecode(e))).toList();
      }
      for (var key in prefs.getKeys()) {
        if (key.startsWith('todesk_config_')) {
          String sn = key.replaceFirst('todesk_config_', '');
          String? jsonStr = prefs.getString(key);
          if (jsonStr != null && jsonStr.isNotEmpty) {
            try {
              todeskConfigs[sn] = Map<String, dynamic>.from(jsonDecode(jsonStr));
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      print('Exception in _loadRobots: $e');
    } finally {
      _isLoaded = true;
      _cleanOldMqttData();
    }
  }

  /// 只保留当天的 MQTT 数据，删除当天之前的所有 MQTT 历史数据
  void _cleanOldMqttData() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // 1. 清理 activeAlarms 中非当天的告警
    activeAlarms.removeWhere((alarm) => alarm.time.isBefore(startOfToday));
    notifications.removeWhere((item) => item.time.isBefore(startOfToday));

    // 2. 清理各设备中的轨迹、巡逻、告警、健康监测历史数据
    for (var robot in robots) {
      robot.trajectory.removeWhere((point) => point.time.isBefore(startOfToday));
      robot.alarmHistory.removeWhere((alarm) => alarm.time.isBefore(startOfToday));
      robot.healthHistory.removeWhere((health) => health.time.isBefore(startOfToday));
      robot.patrolHistory.removeWhere((key, session) => session.startTime.isBefore(startOfToday));

      // 检查设备上是否有跌倒告警标记
      bool hasFall = activeAlarms.any((a) => a.robotId == robot.id && a.alarmTitle == '跌倒告警');
      if (!hasFall) {
        robot.hasFallAlarm = false;
      }
    }

    saveRobots();
  }

  Future<void> saveRobots() async {
    if (!_isLoaded) return; // Prevent saving if not fully loaded yet
    final prefs = await SharedPreferences.getInstance();
    final List<String> robotsJsonList = robots.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('cached_robots', robotsJsonList);
    await prefs.setStringList('deleted_robots', _deletedRobots.toList());
    final List<String> alarmsJsonList = activeAlarms.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('active_alarms', alarmsJsonList);
    final List<String> notifJsonList = notifications.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('notifications_list', notifJsonList);
  }

  void addRobotBySn(String sn, String organization, {bool showSnackbar = true}) {
    _deletedRobots.remove(sn);
    if (_robotsMap.containsKey(sn)) {
      var existing = _robotsMap[sn]!;
      if (organization.isNotEmpty) {
         existing.organization = organization;
         if (existing.name.startsWith('设备 ') || existing.name == '自动发现' || existing.name.isEmpty) {
           existing.name = organization;
         }
         saveRobots();
         robots.refresh();
         if (showSnackbar) {
           Get.snackbar('提示', '设备 $sn 机构已更新为 $organization', snackPosition: SnackPosition.BOTTOM);
         }
      } else if (showSnackbar) {
        Get.snackbar('提示', '设备 $sn 已经存在', snackPosition: SnackPosition.BOTTOM);
      }
      return;
    }

    var newRobot = RobotModel(
      id: sn,
      name: organization.isNotEmpty ? organization : '设备 $sn',
      organization: organization,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 2)), // 默认刚添加时在线2分钟前
    );
    robots.add(newRobot);
    _robotsMap[sn] = newRobot;
    _sortRobots();
    
    saveRobots();
    if (showSnackbar) {
      Get.snackbar('成功', '设备 $sn 已添加', snackPosition: SnackPosition.BOTTOM);
    }

    
    try {
      Get.find<MqttController>().subscribeToRobot(sn);
    } catch (e) {
      print(e);
    }
  }

  void removeRobot(String id) {
    _deletedRobots.add(id);
    robots.removeWhere((r) => r.id == id);
    _robotsMap.remove(id);
    saveRobots();
    
    try {
      Get.find<MqttController>().unsubscribeFromRobot(id);
      Get.snackbar('已删除', '设备 $id 已被移除并取消订阅', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      print(e);
    }
  }

  Future<void> clearAllRobots() async {
    robots.clear();
    _robotsMap.clear();
    _deletedRobots.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_robots');
    await prefs.remove('deleted_robots');
    Get.snackbar('清理完成', '所有本地设备缓存已清除', snackPosition: SnackPosition.BOTTOM);
  }

  DateTime _lastRefreshTime = DateTime.now();
  final Set<String> _deletedRobots = {};

  RobotModel? _getOrAddRobot(String id) {
    if (!_isLoaded) return null;
    if (_deletedRobots.contains(id)) return null;

    // 禁用自动发现：只有手动添加或批量导入的设备才会显示
    // 如果想要恢复自动发现，可以在这里 new RobotModel 并 add 到 robots 中
    return _robotsMap[id];
  }

  void updateHeartbeat(String id, Map<String, dynamic> data) {
    var robot = _getOrAddRobot(id);
    if (robot == null) return;

    final DateTime now = DateTime.now();

    robot.type = int.tryParse(data['type']?.toString() ?? '0') ?? 0;
    robot.status = int.tryParse(data['status']?.toString() ?? '1') ?? 1;

    final bool prevEstop = robot.eStop;
    final bool currentEstop = data['isEstop'] == true || data['eStop'] == true;
    robot.eStop = currentEstop;

    robot.wifi88Status = int.tryParse(data['wifi88Status']?.toString() ?? '0') ?? 0;
    if (data.containsKey('upSsid')) {
      robot.upSsid = data['upSsid']?.toString() ?? '';
    }
    if (data.containsKey('downSsid')) {
      robot.downSsid = data['downSsid']?.toString() ?? '';
    }
    
    if (data['taskList'] is List) {
      robot.taskList = List<int>.from(data['taskList']);
      if (robot.taskList.isNotEmpty && robot.taskList[0] == 0) {
        robot.hasFallAlarm = false;
      }
    }
    
    robot.soc = int.tryParse(data['soc']?.toString() ?? '0') ?? 0;
    robot.socStaus = int.tryParse(data['socStaus']?.toString() ?? '1') ?? 1;

    if (data.containsKey('area')) {
      var areaStr = data['area'].toString();
      var parts = areaStr.split(',');
      if (parts.length >= 2) {
        robot.positionX = double.tryParse(parts[0]) ?? 0.0;
        robot.positionY = double.tryParse(parts[1]) ?? 0.0;
        
        var newPoint = TrajectoryPoint(
          x: robot.positionX,
          y: robot.positionY,
          time: now,
          type: robot.type,
          status: robot.status,
          eStop: robot.eStop,
          wifi88Status: robot.wifi88Status,
          taskList: robot.taskList,
          soc: robot.soc,
          socStaus: robot.socStaus,
          patrolInfo: robot.patrolInfo,
        );

        var traj = robot.trajectory;
        traj.add(newPoint);
        
        if (robot.type == 0) {
          if (traj.length >= 3) {
            var p0 = traj[traj.length - 3];
            var p1 = traj[traj.length - 2];
            var p2 = traj[traj.length - 1];
            if (p0.x == p1.x && p0.y == p1.y && p1.x == p2.x && p1.y == p2.y) {
              traj.removeAt(traj.length - 2);
            }
          }
        }
        
        if (traj.length > 2000) {
          traj.removeAt(0);
        }

        // ==========================================
        // 1. 急停触发检测：与上个心跳比对，如果新触发急停，发起本地通知与 TTS 语音播报
        // ==========================================
        if (!prevEstop && currentEstop) {
          final lastEstopAlert = _lastEstopNotifyTime[robot.id];
          if (lastEstopAlert == null || now.difference(lastEstopAlert).inSeconds >= 10) {
            _lastEstopNotifyTime[robot.id] = now;
            final orgName = robot.organization.isNotEmpty ? robot.organization : '设备 ${robot.id}';
            final xStr = robot.positionX.toStringAsFixed(2);
            final yStr = robot.positionY.toStringAsFixed(2);
            final title = '$orgName 触发急停';
            final body = '在 X: $xStr, Y: $yStr 触发急停';
            final ttsText = '$orgName在坐标$xStr, $yStr触发急停';

            NotificationHelper().showNotification(title, body);
            OnlinePlayer.instance.playTTSWait(ttsText);

            notifications.add(NotificationMessageItem(
              robotId: robot.id,
              organization: robot.organization,
              title: title,
              message: body,
              time: now,
            ));
            saveRobots();
          }
        }

        // ==========================================
        // 2. 疑似停止不动检测：
        //    - type != 0 (非空闲状态)
        //    - taskList 全为 0 (如 [0,0,0,0,0])
        //    - 与 2 分钟前 (或倒数第二个心跳) 距离小于 0.5 米
        // ==========================================
        if (robot.type != 0 && (robot.taskList.isEmpty || robot.taskList.every((e) => e == 0))) {
          TrajectoryPoint? comparePoint;
          for (int i = traj.length - 2; i >= 0; i--) {
            final diffSec = now.difference(traj[i].time).inSeconds;
            if (diffSec >= 110) { // 约 2 分钟 (心跳默认1分钟一次，110秒涵盖倒数第2个心跳)
              comparePoint = traj[i];
              break;
            }
          }

          if (comparePoint == null && traj.length >= 2) {
            final diffSec = now.difference(traj[traj.length - 2].time).inSeconds;
            if (diffSec >= 50) {
              comparePoint = traj[traj.length - 2];
            }
          }

          if (comparePoint != null) {
            final dx = robot.positionX - comparePoint.x;
            final dy = robot.positionY - comparePoint.y;
            final distance = sqrt(dx * dx + dy * dy);

            if (distance < 0.5) {
              final lastStuckAlert = _lastStuckNotifyTime[robot.id];
              // 节流：同台设备每 3 分钟内最多提醒一次
              if (lastStuckAlert == null || now.difference(lastStuckAlert).inMinutes >= 3) {
                _lastStuckNotifyTime[robot.id] = now;
                final orgName = robot.organization.isNotEmpty ? robot.organization : '设备 ${robot.id}';
                final xStr = robot.positionX.toStringAsFixed(2);
                final yStr = robot.positionY.toStringAsFixed(2);
                final title = '$orgName 疑似停止不动 请及时处理 谢谢';
                final body = '在 $xStr  $yStr  的坐标';
                final ttsText = '$orgName疑似停止不动，在坐标$xStr, $yStr，请及时处理，谢谢';

                NotificationHelper().showNotification(title, body);
                OnlinePlayer.instance.playTTSWait(ttsText);

                notifications.add(NotificationMessageItem(
                  robotId: robot.id,
                  organization: robot.organization,
                  title: '$orgName 疑似停止不动',
                  message: '在坐标 X: $xStr, Y: $yStr 移动距离小于0.5米',
                  time: now,
                ));
                saveRobots();
              }
            }
          }
        }
      }
    }

    robot.lastUpdated = now;
    
    // Throttle UI refresh to avoid lag on fast heartbeats
    if (now.difference(_lastRefreshTime).inMilliseconds > 500) {
      robots.refresh();
      _lastRefreshTime = now;
    }
  }

  void updatePatrolEvent(String id, Map<String, dynamic> params, int subtype) {
    var robot = _getOrAddRobot(id);
    if (robot != null) {
      String recordId = params['patrolRecordId']?.toString() ?? '';
      if (recordId.isEmpty) {
        recordId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      if (subtype == 1) { // 巡逻开始 (Patrol start)
        var newSession = PatrolSession(recordId: recordId, startTime: DateTime.now());
        newSession.events.add(PatrolEventLog(time: DateTime.now(), title: '巡逻开始', eventType: 1));
        robot.patrolHistory[recordId] = newSession;
        // Keep only last 20
        if (robot.patrolHistory.length > 20) {
          var sortedKeys = robot.patrolHistory.keys.toList()
            ..sort((a, b) => robot.patrolHistory[a]!.startTime.compareTo(robot.patrolHistory[b]!.startTime));
          robot.patrolHistory.remove(sortedKeys.first);
        }
        robot.patrolInfo = '开始巡逻';
      } else if (subtype == 2 || subtype == 0) { // 巡逻节点到达
        String nodeName = params['value']?.toString() ?? '未知点位';
        int result = params['result'] ?? 1;
        String? imgUrl = params['imgUrl']?.toString();
        
        PatrolSession? currentSession = robot.patrolHistory[recordId];
        
        if (currentSession == null) {
           currentSession = PatrolSession(recordId: recordId, startTime: DateTime.now());
           robot.patrolHistory[recordId] = currentSession;
        }
        String title = result == 3 ? '跳过点位: $nodeName' : '到达点位: $nodeName';
        currentSession.events.add(PatrolEventLog(
          time: DateTime.now(),
          title: title,
          imgUrl: imgUrl,
          eventType: result == 3 ? 3 : 2,
        ));
        robot.patrolInfo = nodeName;
      }

      robot.lastUpdated = DateTime.now();
      robots.refresh();
      saveRobots(); 
    }
  }

  void updatePatrolStatus(String id, Map<String, dynamic> params, int subtype) {
    var robot = _getOrAddRobot(id);
    if (robot != null) {
      if (subtype == 3) {
        String recordId = params['patrolRecordId']?.toString() ?? '';
        int status = params['status'] ?? 0;
        int result = params['result'] ?? 0;
        String reason = params['reason']?.toString() ?? '';
        
        PatrolSession? currentSession = robot.patrolHistory[recordId];
        if (currentSession == null && robot.patrolHistory.isNotEmpty) {
          // Fallback to the latest session if recordId didn't match or is empty
          var sorted = robot.patrolHistory.values.toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));
          currentSession = sorted.first;
        }
        
        if (currentSession != null) {
          currentSession.status = status;
          currentSession.result = result;
          currentSession.reason = reason;
          
          String title = '状态变更';
          int eventType = 0;
          if (status == 2) { title = '巡逻暂停'; eventType = 4; }
          else if (status == 3) { title = '巡逻正常结束'; eventType = 5; }
          else if (status == 4) { title = '巡逻中断结束'; eventType = 6; }
          else if (status == 5) { title = '巡逻异常结束'; eventType = 6; }
          
          currentSession.events.add(PatrolEventLog(
            time: DateTime.now(),
            title: title,
            description: reason.isNotEmpty ? reason : null,
            eventType: eventType,
          ));

          if (status >= 3) {
            currentSession.endTime = DateTime.now();
          }
        }
      }
      
      robot.lastUpdated = DateTime.now();
      robots.refresh();
      saveRobots();
    }
  }

  void _playAlarmSound() async {
    try {
      // Loop mixkit siren alert audio
      await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-84.wav'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      Timer(const Duration(seconds: 10), () async {
        await _audioPlayer.stop();
      });
    } catch (e) {
      print('Error playing alarm sound: $e');
    }
  }

  void _showLocalNotification(String title, String message) {
    NotificationHelper().showNotification(title, message);
  }

  void updateAlarmEvent(String id, Map<String, dynamic> body, int subtype) {
    var robot = _getOrAddRobot(id);
    if (robot != null) {
      String title = "未知告警";
      if (subtype == 12) {
        title = '跌倒告警';
        robot.hasFallAlarm = true;
      } else if (subtype == 13) {
        title = '烟雾告警';
      } else if (subtype == 14) {
        title = '甲烷告警';
      } else if (subtype == 37) {
        title = '火焰告警';
      }

      robot.alarmHistory.add(AlarmEvent(
        time: DateTime.now(),
        title: title,
        description: '区域: ${body['area'] ?? '未知'}',
        imgUrl: body['imgUrl']?.toString(),
        subtype: subtype,
      ));
      if (robot.alarmHistory.length > 50) robot.alarmHistory.removeAt(0);

      // Add to active alarms
      activeAlarms.add(ActiveAlarmItem(
        robotId: id,
        organization: robot.organization.isNotEmpty ? robot.organization : '设备 $id',
        alarmTitle: title,
        time: DateTime.now(),
        imgUrl: body['imgUrl']?.toString(),
      ));

      // Trigger local sound and push notification
      _playAlarmSound();
      _showLocalNotification('🚨 $title', '设备 $id 发生 $title！');

      Get.snackbar('🚨 $title', '设备 $id 发生 $title！', 
        snackPosition: SnackPosition.TOP, 
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 10)
      );

      robot.lastUpdated = DateTime.now();
      robots.refresh();
      saveRobots();
    }
  }

  void updateHealthEvent(String id, Map<String, dynamic> body) {
    var robot = _getOrAddRobot(id);
    if (robot != null) {
      
      int subtype = int.tryParse(body['subtype']?.toString() ?? '0') ?? 0;
      String userId = body['userId']?.toString() ?? '0';
      Map<String, dynamic> params = body['params'] ?? {};
      bool isQuickMeasure = params['isQuickMeasure'] == true || params['isQuickMeasure'] == 'true';
      
      robot.healthHistory.add(HealthMeasurement(
        time: DateTime.now(),
        subtype: subtype,
        userId: userId,
        isQuickMeasure: isQuickMeasure,
        params: params,
      ));
      if (robot.healthHistory.length > 50) robot.healthHistory.removeAt(0);

      robot.lastUpdated = DateTime.now();
      robots.refresh();
      saveRobots();
    }
  }

  /// 保存 ToDesk 配置信息到本地 database (SharedPreferences)，Key 为 sn
  Future<void> saveTodeskConfig(String sn, Map<String, dynamic> params) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(params);
      await prefs.setString('todesk_config_$sn', jsonStr);
      todeskConfigs[sn] = Map<String, dynamic>.from(params);
      todeskConfigs.refresh();
      print('Successfully saved ToDesk config for SN: $sn');

      // 查找机构名称
      String orgName = '';
      var robot = _robotsMap[sn];
      if (robot != null && robot.organization.isNotEmpty) {
        orgName = robot.organization;
      } else if (robot != null && robot.name.isNotEmpty) {
        orgName = robot.name;
      } else {
        orgName = '设备 $sn';
      }

      // 通知 某某机构 Todesk 配置上传
      final notificationItem = NotificationMessageItem(
        robotId: sn,
        organization: orgName,
        title: 'ToDesk 配置上传',
        message: '$orgName Todesk 配置上传',
        time: DateTime.now(),
        extraData: params,
      );

      notifications.add(notificationItem);
      if (notifications.length > 100) {
        notifications.removeAt(0);
      }
      notifications.refresh();
      saveRobots();

      _showLocalNotification('Todesk 配置上传', '$orgName Todesk 配置上传');

      // 立刻显示弹窗提醒
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.lightBlueAccent.withOpacity(0.3)),
          ),
          title: Row(
            children: [
              const Icon(Icons.desktop_windows_rounded, color: Color(0xFF0284C7), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$orgName ToDesk 配置上传',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设备 SN: $sn', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('设备代码 (ClientID): ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Expanded(
                            child: SelectableText(
                              params['clientid']?.toString() ?? '未获取',
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (params['loginphone'] != null && params['loginphone'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('登录手机号: ${params['loginphone']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                      if (params['loginemail'] != null && params['loginemail'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('登录邮箱: ${params['loginemail']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                      if (params['version'] != null && params['version'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('ToDesk 版本: ${params['version']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
              label: const Text('前往设备详情', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Get.back();
                Get.to(() => RobotDetailPage(robotId: sn, autoShowTodeskDialog: true));
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
              onPressed: () => Get.back(),
              child: const Text('关闭', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error saving ToDesk config: $e');
    }
  }

  /// 获取指定 SN 的 ToDesk 配置
  Future<Map<String, dynamic>?> getTodeskConfig(String sn) async {
    if (todeskConfigs.containsKey(sn)) {
      return todeskConfigs[sn];
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('todesk_config_$sn');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
        todeskConfigs[sn] = map;
        return map;
      }
    } catch (e) {
      print('Error getting ToDesk config for $sn: $e');
    }
    return null;
  }

  /// 处理地图/点位等更新通知，添加到通知列表
  void addMapUpdateNotification(String sn, Map<String, dynamic> params) {
    try {
      String rawMsg = params['msg']?.toString() ?? '地图更新成功';
      
      // 查找机构名称
      String orgName = '';
      var robot = _robotsMap[sn];
      if (robot != null && robot.organization.isNotEmpty) {
        orgName = robot.organization;
      } else if (robot != null && robot.name.isNotEmpty) {
        orgName = robot.name;
      } else {
        orgName = '设备 $sn';
      }

      String title = '$orgName 地图更新成功';
      String message = '$orgName $rawMsg';

      final notificationItem = NotificationMessageItem(
        robotId: sn,
        organization: orgName,
        title: title,
        message: message,
        time: DateTime.now(),
        extraData: params,
      );

      notifications.add(notificationItem);
      if (notifications.length > 100) {
        notifications.removeAt(0);
      }
      notifications.refresh();
      saveRobots();

      _showLocalNotification('🗺️ 地图更新成功', '$orgName $rawMsg');

      Get.snackbar(
        '🗺️ 地图更新成功',
        '$orgName $rawMsg',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF065F46),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      print('Error adding map update notification: $e');
    }
  }

  void nextPage() {
    if (currentPage.value < totalPages - 1) {
      currentPage.value++;
    }
  }

  void prevPage() {
    if (currentPage.value > 0) {
      currentPage.value--;
    }
  }

  void removeActiveAlarm(ActiveAlarmItem alarm) {
    activeAlarms.remove(alarm);
    final r = _robotsMap[alarm.robotId];
    if (r != null) {
      // Check if there are any other '跌倒告警' active alarms left for this robot
      bool hasAnyFall = activeAlarms.any((a) => a.robotId == r.id && a.alarmTitle == '跌倒告警');
      if (!hasAnyFall) {
        r.hasFallAlarm = false;
      }
    }
    saveRobots();
    robots.refresh();
  }

  void clearAllActiveAlarms() {
    activeAlarms.clear();
    for (var r in robots) {
      r.hasFallAlarm = false;
    }
    saveRobots();
    robots.refresh();
  }

  void _sortRobots() {
    robots.sort((a, b) {
      // 0. 收藏的设备排在最最前面
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;

      // 离线状态排最后 (isOffline == true)
      bool aOffline = a.isOffline;
      bool bOffline = b.isOffline;
      
      if (!aOffline && bOffline) return -1;
      if (aOffline && !bOffline) return 1;

      // 都在线的情况，判断空闲/非空闲状态
      // 2. 当前不是空闲状态排第二 (type != 0)
      // 3. 空闲状态排第三 (type == 0)
      bool aIdle = a.type == 0;
      bool bIdle = b.type == 0;
      
      if (!aIdle && bIdle) return -1; // a 非空闲，b 空闲 -> a 排前面
      if (aIdle && !bIdle) return 1;  // a 空闲，b 非空闲 -> b 排前面

      return 0; // 其他情况保持原有顺序
    });
  }
}
