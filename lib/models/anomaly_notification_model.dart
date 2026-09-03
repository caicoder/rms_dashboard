enum AnomalyType {
  estop, // 急停触发
  stuck, // 疑似停止不动
}

class AnomalyNotificationItem {
  final String id;
  final String robotId; // 设备 SN
  final String organization; // 机构名称
  final String title; // 标题
  final String message; // 消息内容
  final AnomalyType type; // 异常类型
  final DateTime time; // 发生时间
  final double? positionX; // 坐标 X
  final double? positionY; // 坐标 Y
  final String? taskName; // 关联任务类型名称

  AnomalyNotificationItem({
    required this.id,
    required this.robotId,
    required this.organization,
    required this.title,
    required this.message,
    required this.type,
    required this.time,
    this.positionX,
    this.positionY,
    this.taskName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'robotId': robotId,
        'organization': organization,
        'title': title,
        'message': message,
        'type': type.name,
        'time': time.toIso8601String(),
        'positionX': positionX,
        'positionY': positionY,
        'taskName': taskName,
      };

  factory AnomalyNotificationItem.fromJson(Map<String, dynamic> json) =>
      AnomalyNotificationItem(
        id: json['id'] ?? '',
        robotId: json['robotId'] ?? '',
        organization: json['organization'] ?? '',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        type: json['type'] == 'estop' ? AnomalyType.estop : AnomalyType.stuck,
        time: json['time'] != null
            ? (DateTime.tryParse(json['time']) ?? DateTime.now())
            : DateTime.now(),
        positionX: (json['positionX'] as num?)?.toDouble(),
        positionY: (json['positionY'] as num?)?.toDouble(),
        taskName: json['taskName'],
      );
}
