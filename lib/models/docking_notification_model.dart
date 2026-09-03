class DockingNotificationItem {
  final String id;
  final String sn;
  final String organization;
  final String reason;
  final String taskId;
  final String type;
  final int subtype;
  final DateTime time;
  final Map<String, dynamic>? rawData;

  DockingNotificationItem({
    required this.id,
    required this.sn,
    required this.organization,
    required this.reason,
    this.taskId = '',
    this.type = '2',
    this.subtype = 1,
    required this.time,
    this.rawData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sn': sn,
    'organization': organization,
    'reason': reason,
    'taskId': taskId,
    'type': type,
    'subtype': subtype,
    'time': time.toIso8601String(),
    'rawData': rawData,
  };

  factory DockingNotificationItem.fromJson(Map<String, dynamic> json) =>
      DockingNotificationItem(
        id: json['id'] ?? '',
        sn: json['sn'] ?? '',
        organization: json['organization'] ?? '',
        reason: json['reason'] ?? '',
        taskId: json['taskId'] ?? '',
        type: json['type']?.toString() ?? '2',
        subtype: json['subtype'] is int
            ? json['subtype']
            : int.tryParse(json['subtype']?.toString() ?? '1') ?? 1,
        time: json['time'] != null
            ? DateTime.tryParse(json['time']) ?? DateTime.now()
            : DateTime.now(),
        rawData: json['rawData'] != null
            ? Map<String, dynamic>.from(json['rawData'])
            : null,
      );
}
