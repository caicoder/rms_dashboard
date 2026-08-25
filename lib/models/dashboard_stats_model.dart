class DashboardStatsModel {
  final StatusOverview? statusOverview;
  final AbnormalSummary? abnormalSummary;
  final List<DeviceStatisticsItem> statisticsList;

  DashboardStatsModel({
    this.statusOverview,
    this.abnormalSummary,
    this.statisticsList = const [],
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      statusOverview: json['statusOverview'] != null
          ? StatusOverview.fromJson(Map<String, dynamic>.from(json['statusOverview']))
          : null,
      abnormalSummary: json['abnormalSummary'] != null
          ? AbnormalSummary.fromJson(Map<String, dynamic>.from(json['abnormalSummary']))
          : null,
      statisticsList: json['statisticsList'] != null
          ? (json['statisticsList'] as List)
              .map((e) => DeviceStatisticsItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'statusOverview': statusOverview?.toJson(),
        'abnormalSummary': abnormalSummary?.toJson(),
        'statisticsList': statisticsList.map((e) => e.toJson()).toList(),
      };
}

class StatusOverview {
  final int totalDeviceCount;
  final int onlineDeviceCount;
  final int offlineWithinHourCount;
  final int offlineOverHourCount;
  final int abnormalDisabledCount;
  final int lowBatteryCount;
  final int disableTriggerCount;
  final int totalAbnormalDeviceCount;

  StatusOverview({
    this.totalDeviceCount = 0,
    this.onlineDeviceCount = 0,
    this.offlineWithinHourCount = 0,
    this.offlineOverHourCount = 0,
    this.abnormalDisabledCount = 0,
    this.lowBatteryCount = 0,
    this.disableTriggerCount = 0,
    this.totalAbnormalDeviceCount = 0,
  });

  factory StatusOverview.fromJson(Map<String, dynamic> json) {
    int parseVal(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    return StatusOverview(
      totalDeviceCount: parseVal(json['totalDeviceCount']),
      onlineDeviceCount: parseVal(json['onlineDeviceCount']),
      offlineWithinHourCount: parseVal(json['offlineWithinHourCount']),
      offlineOverHourCount: parseVal(json['offlineOverHourCount']),
      abnormalDisabledCount: parseVal(json['abnormalDisabledCount']),
      lowBatteryCount: parseVal(json['lowBatteryCount']),
      disableTriggerCount: parseVal(json['disableTriggerCount']),
      totalAbnormalDeviceCount: parseVal(json['totalAbnormalDeviceCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalDeviceCount': totalDeviceCount,
        'onlineDeviceCount': onlineDeviceCount,
        'offlineWithinHourCount': offlineWithinHourCount,
        'offlineOverHourCount': offlineOverHourCount,
        'abnormalDisabledCount': abnormalDisabledCount,
        'lowBatteryCount': lowBatteryCount,
        'disableTriggerCount': disableTriggerCount,
        'totalAbnormalDeviceCount': totalAbnormalDeviceCount,
      };
}

class AbnormalSummary {
  final int totalCount;
  final int emergencyStopCount;
  final int planningFailCount;
  final int locationLostCount;
  final int networkAbnormalCount;
  final int lowBatteryAlarmCount;
  final int aiEventUnresolvedCount;
  final int lightTapAlarmCount; // 火焰告警
  final int fallAlarmCount;
  final int methaneAlarmCount;
  final int smokeAlarmCount;

  AbnormalSummary({
    this.totalCount = 0,
    this.emergencyStopCount = 0,
    this.planningFailCount = 0,
    this.locationLostCount = 0,
    this.networkAbnormalCount = 0,
    this.lowBatteryAlarmCount = 0,
    this.aiEventUnresolvedCount = 0,
    this.lightTapAlarmCount = 0,
    this.fallAlarmCount = 0,
    this.methaneAlarmCount = 0,
    this.smokeAlarmCount = 0,
  });

  factory AbnormalSummary.fromJson(Map<String, dynamic> json) {
    int parseVal(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    int eStop = parseVal(json['emergencyStopCount'] ?? json['disableCount'] ?? json['eStopCount']);
    if (eStop == 0 && json.containsKey('disableTriggerCount')) {
      eStop = parseVal(json['disableTriggerCount']);
    }

    return AbnormalSummary(
      totalCount: parseVal(json['totalCount']),
      emergencyStopCount: eStop,
      planningFailCount: parseVal(json['planningFailCount']),
      locationLostCount: parseVal(json['locationLostCount']),
      networkAbnormalCount: parseVal(json['networkAbnormalCount']),
      lowBatteryAlarmCount: parseVal(json['lowBatteryAlarmCount']),
      aiEventUnresolvedCount: parseVal(json['aiEventUnresolvedCount']),
      lightTapAlarmCount: parseVal(json['lightTapAlarmCount'] ?? json['flameAlarmCount']),
      fallAlarmCount: parseVal(json['fallAlarmCount']),
      methaneAlarmCount: parseVal(json['methaneAlarmCount']),
      smokeAlarmCount: parseVal(json['smokeAlarmCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalCount': totalCount,
        'emergencyStopCount': emergencyStopCount,
        'planningFailCount': planningFailCount,
        'locationLostCount': locationLostCount,
        'networkAbnormalCount': networkAbnormalCount,
        'lowBatteryAlarmCount': lowBatteryAlarmCount,
        'aiEventUnresolvedCount': aiEventUnresolvedCount,
        'lightTapAlarmCount': lightTapAlarmCount,
        'fallAlarmCount': fallAlarmCount,
        'methaneAlarmCount': methaneAlarmCount,
        'smokeAlarmCount': smokeAlarmCount,
      };
}

class DeviceStatisticsItem {
  final int index;
  final String deviceName;
  final String deviceSn;
  final String toDeskNumber;
  final String onlineStatus;
  final dynamic currentBattery;
  final String disableStatus;
  final String navigationFunction;
  final String offlinePointDistance;
  final int disableCount;
  final int planningCount;
  final int locationCount;

  DeviceStatisticsItem({
    this.index = 0,
    this.deviceName = '',
    this.deviceSn = '',
    this.toDeskNumber = '',
    this.onlineStatus = '',
    this.currentBattery = 0,
    this.disableStatus = '',
    this.navigationFunction = '',
    this.offlinePointDistance = '',
    this.disableCount = 0,
    this.planningCount = 0,
    this.locationCount = 0,
  });

  factory DeviceStatisticsItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    String parseStr(dynamic v) {
      if (v == null) return '';
      return v.toString();
    }

    return DeviceStatisticsItem(
      index: parseInt(json['index']),
      deviceName: parseStr(json['deviceName']),
      deviceSn: parseStr(json['deviceSn']),
      toDeskNumber: parseStr(json['toDeskNumber']),
      onlineStatus: parseStr(json['onlineStatus']),
      currentBattery: json['currentBattery'] ?? 0,
      disableStatus: parseStr(json['disableStatus']),
      navigationFunction: parseStr(json['navigationFunction']),
      offlinePointDistance: parseStr(json['offlinePointDistance']),
      disableCount: parseInt(json['disableCount']),
      planningCount: parseInt(json['planningCount']),
      locationCount: parseInt(json['locationCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'deviceName': deviceName,
        'deviceSn': deviceSn,
        'toDeskNumber': toDeskNumber,
        'onlineStatus': onlineStatus,
        'currentBattery': currentBattery,
        'disableStatus': disableStatus,
        'navigationFunction': navigationFunction,
        'offlinePointDistance': offlinePointDistance,
        'disableCount': disableCount,
        'planningCount': planningCount,
        'locationCount': locationCount,
      };
}
