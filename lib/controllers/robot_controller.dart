import 'dart:async';
import 'dart:convert';
import 'dart:async';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/robot_model.dart';
import 'mqtt_controller.dart';

class RobotController extends GetxController {
  var robots = <RobotModel>[].obs;
  final Map<String, RobotModel> _robotsMap = {};
  
  var currentPage = 0.obs;
  final int itemsPerPage = 16;
  Timer? _offlineCheckTimer;

  int get totalPages => (robots.isEmpty) ? 1 : (robots.length / itemsPerPage).ceil();

  List<RobotModel> get currentRobots {
    if (robots.isEmpty) return [];
    int start = currentPage.value * itemsPerPage;
    int end = start + itemsPerPage;
    if (end > robots.length) end = robots.length;
    return robots.sublist(start, end);
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
      }
      final List<String>? deletedIds = prefs.getStringList('deleted_robots');
      if (deletedIds != null) {
        _deletedRobots.addAll(deletedIds);
      }
    } catch (e) {
      print('Exception in _loadRobots: $e');
    } finally {
      _isLoaded = true;
    }
  }

  Future<void> saveRobots() async {
    if (!_isLoaded) return; // Prevent saving if not fully loaded yet
    final prefs = await SharedPreferences.getInstance();
    final List<String> robotsJsonList = robots.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('cached_robots', robotsJsonList);
    await prefs.setStringList('deleted_robots', _deletedRobots.toList());
  }

  void addRobotBySn(String sn, String organization, {bool showSnackbar = true}) {
    _deletedRobots.remove(sn);
    if (_robotsMap.containsKey(sn)) {
      var existing = _robotsMap[sn]!;
      if (organization.isNotEmpty && (existing.name == '设备 $sn' || existing.name == '自动发现')) {
         existing.name = organization;
         existing.organization = organization;
         saveRobots();
         robots.refresh();
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

    robot.type = int.tryParse(data['type']?.toString() ?? '0') ?? 0;
    robot.status = int.tryParse(data['status']?.toString() ?? '1') ?? 1;
    robot.eStop = data['eStop'] ?? false;
    robot.wifi88Status = int.tryParse(data['wifi88Status']?.toString() ?? '0') ?? 0;
    
    if (data['taskList'] is List) {
      robot.taskList = List<int>.from(data['taskList']);
    }
    
    robot.soc = int.tryParse(data['soc']?.toString() ?? '0') ?? 0;
    robot.socStaus = int.tryParse(data['socStaus']?.toString() ?? '1') ?? 1;

    if (data.containsKey('area')) {
      var areaStr = data['area'].toString();
      var parts = areaStr.split(',');
      if (parts.length >= 2) {
        robot.positionX = double.tryParse(parts[0]) ?? 0.0;
        robot.positionY = double.tryParse(parts[1]) ?? 0.0;
        
        DateTime now = DateTime.now();
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
      }
    }

    robot.lastUpdated = DateTime.now();
    
    // Throttle UI refresh to avoid lag on fast heartbeats
    if (DateTime.now().difference(_lastRefreshTime).inMilliseconds > 500) {
      robots.refresh();
      _lastRefreshTime = DateTime.now();
    }
  }

  void updatePatrolEvent(String id, Map<String, dynamic> params, int subtype) {
    var robot = _getOrAddRobot(id);
    if (robot != null) {
      String recordId = params['patrolRecordId']?.toString() ?? '';
      
      if (subtype == 1) { // 巡逻开始 (Patrol start)
        var newSession = PatrolSession(recordId: recordId, startTime: DateTime.now());
        newSession.events.add(PatrolEventLog(time: DateTime.now(), title: '巡逻开始', eventType: 1));
        robot.patrolHistory.add(newSession);
        // Keep only last 20
        if (robot.patrolHistory.length > 20) robot.patrolHistory.removeAt(0);
        robot.patrolInfo = '开始巡逻';
      } else if (subtype == 2 || subtype == 0) { // 巡逻节点到达
        String nodeName = params['value']?.toString() ?? '未知点位';
        int result = params['result'] ?? 1;
        String? imgUrl = params['imgUrl']?.toString();
        
        PatrolSession? currentSession;
        if (robot.patrolHistory.isNotEmpty) {
          if (recordId.isNotEmpty) {
            for (var s in robot.patrolHistory.reversed) {
              if (s.recordId == recordId) {
                currentSession = s;
                break;
              }
            }
          }
          currentSession ??= robot.patrolHistory.last;
        }
        
        if (currentSession == null) {
           currentSession = PatrolSession(recordId: recordId, startTime: DateTime.now());
           robot.patrolHistory.add(currentSession);
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
        
        PatrolSession? currentSession;
        if (robot.patrolHistory.isNotEmpty) {
          if (recordId.isNotEmpty) {
            for (var s in robot.patrolHistory.reversed) {
              if (s.recordId == recordId) {
                currentSession = s;
                break;
              }
            }
          }
          currentSession ??= robot.patrolHistory.last;
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

  void _sortRobots() {
    robots.sort((a, b) {
      // 1. 急停排在最前面 (eStop == true)
      if (a.eStop && !b.eStop) return -1;
      if (!a.eStop && b.eStop) return 1;

      // 4. 离线状态排最后 (isOffline == true)
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
