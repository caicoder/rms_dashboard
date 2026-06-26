import 'package:get/get.dart';

class PatrolEventLog {
  final DateTime time;
  final String title;
  final String? description;
  final String? imgUrl;
  final int eventType; // 0:未知, 1:开始, 2:点位到达, 3:点位跳点, 4:暂停, 5:结束, 6:异常中断

  PatrolEventLog({
    required this.time,
    required this.title,
    this.description,
    this.imgUrl,
    required this.eventType,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'title': title,
    'description': description,
    'imgUrl': imgUrl,
    'eventType': eventType,
  };

  factory PatrolEventLog.fromJson(dynamic json) {
    if (json is String) {
      return PatrolEventLog(time: DateTime.now(), title: json, eventType: 2);
    }
    if (json is Map<String, dynamic>) {
      return PatrolEventLog(
        time: json['time'] != null ? DateTime.parse(json['time']) : DateTime.now(),
        title: json['title'] ?? (json['nodeName'] ?? '未知事件'),
        description: json['description'],
        imgUrl: json['imgUrl'],
        eventType: json['eventType'] ?? (json['result'] == 3 ? 3 : 2),
      );
    }
    return PatrolEventLog(time: DateTime.now(), title: '未知事件', eventType: 0);
  }
}

class PatrolSession {
  final String recordId;
  final DateTime startTime;
  DateTime? endTime;
  List<PatrolEventLog> events;
  int? status;
  int? result;
  String? reason;

  PatrolSession({
    required this.recordId,
    required this.startTime,
    this.endTime,
    List<PatrolEventLog>? events,
    this.status,
    this.result,
    this.reason,
  }) : events = events ?? [];

  Map<String, dynamic> toJson() => {
    'recordId': recordId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'events': events.map((e) => e.toJson()).toList(),
    'status': status,
    'result': result,
    'reason': reason,
  };

  factory PatrolSession.fromJson(Map<String, dynamic> json) => PatrolSession(
    recordId: json['recordId'] ?? '',
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    events: (json['events'] ?? json['nodes'] as List<dynamic>?)?.map((e) => PatrolEventLog.fromJson(e)).toList() ?? [],
    status: json['status'],
    result: json['result'],
    reason: json['reason'],
  );
}

class AlarmEvent {
  final DateTime time;
  final String title;
  final String description;
  final String? imgUrl;
  final int? subtype;

  AlarmEvent({
    required this.time,
    required this.title,
    required this.description,
    this.imgUrl,
    this.subtype,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'title': title,
    'description': description,
    'imgUrl': imgUrl,
    'subtype': subtype,
  };

  factory AlarmEvent.fromJson(Map<String, dynamic> json) => AlarmEvent(
    time: DateTime.parse(json['time']),
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    imgUrl: json['imgUrl'],
    subtype: json['subtype'],
  );
}

class TrajectoryPoint {
  final double x;
  final double y;
  final DateTime time;
  final int type;
  final int status;
  final bool eStop;
  final int wifi88Status;
  final List<int> taskList;
  final int soc;
  final int socStaus;
  final String patrolInfo;

  TrajectoryPoint({
    required this.x,
    required this.y,
    required this.time,
    this.type = 0,
    this.status = 1,
    this.eStop = false,
    this.wifi88Status = 0,
    this.taskList = const [0,0,0,0,0],
    this.soc = 0,
    this.socStaus = 0,
    this.patrolInfo = '',
  });

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'time': time.toIso8601String(),
    'type': type,
    'status': status,
    'eStop': eStop,
    'wifi88Status': wifi88Status,
    'taskList': taskList,
    'soc': soc,
    'socStaus': socStaus,
    'patrolInfo': patrolInfo,
  };

  factory TrajectoryPoint.fromJson(Map<String, dynamic> json) => TrajectoryPoint(
    x: json['x']?.toDouble() ?? 0.0,
    y: json['y']?.toDouble() ?? 0.0,
    time: json['time'] != null ? DateTime.parse(json['time']) : DateTime.now(),
    type: json['type'] ?? 0,
    status: json['status'] ?? 1,
    eStop: json['eStop'] ?? false,
    wifi88Status: json['wifi88Status'] ?? 0,
    taskList: List<int>.from(json['taskList'] ?? [0,0,0,0,0]),
    soc: json['soc'] ?? 0,
    socStaus: json['socStaus'] ?? 0,
    patrolInfo: json['patrolInfo'] ?? '',
  );
}

class HealthMeasurement {
  final DateTime time;
  final int subtype; // 0=血氧, 1=体温, 2=血压, 3=脉率
  final String userId;
  final bool isQuickMeasure;
  final Map<String, dynamic> params;

  HealthMeasurement({
    required this.time,
    required this.subtype,
    required this.userId,
    required this.isQuickMeasure,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'subtype': subtype,
    'userId': userId,
    'isQuickMeasure': isQuickMeasure,
    'params': params,
  };

  factory HealthMeasurement.fromJson(Map<String, dynamic> json) => HealthMeasurement(
    time: DateTime.parse(json['time']),
    subtype: json['subtype'] ?? 0,
    userId: json['userId']?.toString() ?? '0',
    isQuickMeasure: json['isQuickMeasure'] ?? false,
    params: json['params'] ?? {},
  );
}

class RobotModel {
  final String id;
  String name;
  String organization; // 新增机构名称
  double positionX;
  double positionY;
  DateTime lastUpdated;
  
  int type;
  int status;
  bool eStop;
  int wifi88Status;
  List<int> taskList;
  int soc;
  int socStaus;
  // 地图坐标记录（用于绘制最近轨迹）
  List<TrajectoryPoint> trajectory;
  String patrolInfo;
  bool hasFallAlarm;
  bool isFavorite; // 收藏属性

  // Caching specific histories
  Map<String, PatrolSession> patrolHistory;
  List<AlarmEvent> alarmHistory;
  List<HealthMeasurement> healthHistory;

  bool get isOffline {
    return DateTime.now().difference(lastUpdated).inMinutes >= 5;
  }

  String get naturalStatus {
    if (isOffline) return "设备离线 (Offline)";
    if (eStop) return "急停触发 (E-Stop)";
    if (hasFallAlarm) return "跌倒告警 (Fall Alert)";
    
    String taskName = "未知任务";
    switch (type) {
      case 0: taskName = "空闲待机 (Idle)"; break;
      case 1: taskName = "回去充电 (Charging)"; break;
      case 3: taskName = "巡逻任务 (Patrol)"; break;
      case 7: taskName = "代送任务 (Delivery)"; break;
      case 109: taskName = "前往迎宾点 (Greeting)"; break;
      case 110: taskName = "前往传话 (Notice)"; break;
      case 111: taskName = "前往拿取 (Taking)"; break;
      case 112: taskName = "前往告警任务 (Alarm)"; break;
      case 113: taskName = "大喇叭任务 (Loudspeak)"; break;
      case 114: taskName = "进行导览任务 (Guide)"; break;
      case 115: taskName = "前往目标点 (Target)"; break;
      case 116: taskName = "带路 (Leadway)"; break;
    }
    
    if (type != 0) {
      if (status == 2) taskName += " - 已暂停";
      if (status == 4) taskName += " - 异常失败";
    }
    return taskName;
  }

  RobotModel({
    required this.id,
    required this.name,
    this.organization = '',
    this.positionX = 0.0,
    this.positionY = 0.0,
    DateTime? lastUpdated,
    this.type = 0,
    this.status = 1,
    this.eStop = false,
    this.wifi88Status = 0,
    List<int>? taskList,
    this.soc = 0,
    this.socStaus = 0,
    List<TrajectoryPoint>? trajectory,
    this.patrolInfo = '',
    this.hasFallAlarm = false,
    this.isFavorite = false,
    Map<String, PatrolSession>? patrolHistory,
    List<AlarmEvent>? alarmHistory,
    List<HealthMeasurement>? healthHistory,
  }) : 
    this.lastUpdated = lastUpdated ?? DateTime.now(),
    this.taskList = taskList ?? [0,0,0,0,0],
    this.trajectory = trajectory ?? [],
    this.patrolHistory = patrolHistory ?? {},
    this.alarmHistory = alarmHistory ?? [],
    this.healthHistory = healthHistory ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'organization': organization,
    'positionX': positionX,
    'positionY': positionY,
    'lastUpdated': lastUpdated.toIso8601String(),
    'type': type,
    'status': status,
    'eStop': eStop,
    'wifi88Status': wifi88Status,
    'taskList': taskList,
    'soc': soc,
    'socStaus': socStaus,
    'trajectory': trajectory.map((e) => e.toJson()).toList(),
    'patrolInfo': patrolInfo,
    'hasFallAlarm': hasFallAlarm,
    'isFavorite': isFavorite,
    'patrolHistory': patrolHistory.map((k, v) => MapEntry(k, v.toJson())),
    'alarmHistory': alarmHistory.map((e) => e.toJson()).toList(),
    'healthHistory': healthHistory.map((e) => e.toJson()).toList(),
  };

  factory RobotModel.fromJson(Map<String, dynamic> json) => RobotModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    organization: json['organization'] ?? '',
    positionX: json['positionX']?.toDouble() ?? 0.0,
    positionY: json['positionY']?.toDouble() ?? 0.0,
    lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
    type: json['type'] ?? 0,
    status: json['status'] ?? 1,
    eStop: json['eStop'] ?? false,
    wifi88Status: json['wifi88Status'] ?? 0,
    taskList: List<int>.from(json['taskList'] ?? [0,0,0,0,0]),
    soc: json['soc'] ?? 0,
    socStaus: json['socStaus'] ?? 0,
    trajectory: (json['trajectory'] as List<dynamic>?)
        ?.map((e) => TrajectoryPoint.fromJson(e))
        .toList() ?? [],
    patrolInfo: json['patrolInfo'] ?? '',
    hasFallAlarm: json['hasFallAlarm'] ?? false,
    isFavorite: json['isFavorite'] ?? false,
    patrolHistory: json['patrolHistory'] is Map
        ? (json['patrolHistory'] as Map<String, dynamic>).map((k, e) => MapEntry(k, PatrolSession.fromJson(e)))
        : (json['patrolHistory'] is List
            ? Map.fromEntries((json['patrolHistory'] as List).map((e) {
                final s = PatrolSession.fromJson(e);
                return MapEntry(s.recordId.isNotEmpty ? s.recordId : 'session_${s.startTime.millisecondsSinceEpoch}', s);
              }))
            : <String, PatrolSession>{}),
    alarmHistory: (json['alarmHistory'] as List<dynamic>?)?.map((e) => AlarmEvent.fromJson(e)).toList() ?? [],
    healthHistory: (json['healthHistory'] as List<dynamic>?)?.map((e) => HealthMeasurement.fromJson(e)).toList() ?? [],
  );
}

class ActiveAlarmItem {
  final String robotId;
  final String organization;
  final String alarmTitle;
  final DateTime time;
  final String? imgUrl; // 告警图片URL

  ActiveAlarmItem({
    required this.robotId,
    required this.organization,
    required this.alarmTitle,
    required this.time,
    this.imgUrl,
  });

  Map<String, dynamic> toJson() => {
    'robotId': robotId,
    'organization': organization,
    'alarmTitle': alarmTitle,
    'time': time.toIso8601String(),
    'imgUrl': imgUrl,
  };

  factory ActiveAlarmItem.fromJson(Map<String, dynamic> json) => ActiveAlarmItem(
    robotId: json['robotId'] ?? '',
    organization: json['organization'] ?? '',
    alarmTitle: json['alarmTitle'] ?? '',
    time: json['time'] != null ? DateTime.parse(json['time']) : DateTime.now(),
    imgUrl: json['imgUrl'],
  );
}
