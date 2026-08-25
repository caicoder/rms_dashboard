import 'package:flutter_test/flutter_test.dart';
import 'package:rms_dashboard/models/dashboard_stats_model.dart';

void main() {
  group('DashboardStatsModel Tests', () {
    test('Correctly parses statusOverview, abnormalSummary and statisticsList', () {
      final sampleJson = {
        "statusOverview": {
          "totalDeviceCount": 150,
          "onlineDeviceCount": 120,
          "offlineWithinHourCount": 18,
          "offlineOverHourCount": 12,
          "abnormalDisabledCount": 5,
          "lowBatteryCount": 8,
          "disableTriggerCount": 3,
          "totalAbnormalDeviceCount": 16
        },
        "abnormalSummary": {
          "totalCount": 45,
          "planningFailCount": 5,
          "locationLostCount": 3,
          "networkAbnormalCount": 8,
          "lowBatteryAlarmCount": 10,
          "aiEventUnresolvedCount": 4,
          "lightTapAlarmCount": 2,
          "fallAlarmCount": 6,
          "methaneAlarmCount": 1,
          "smokeAlarmCount": 0
        },
        "statisticsList": [
          {
            "index": 1,
            "deviceName": "小悉-001",
            "deviceSn": "SN20260820001",
            "toDeskNumber": "1001",
            "onlineStatus": "在线",
            "currentBattery": 85,
            "disableStatus": "正常",
            "navigationFunction": "正常",
            "offlinePointDistance": "0.0 m",
            "disableCount": 0,
            "planningCount": 12,
            "locationCount": 3
          }
        ]
      };

      final model = DashboardStatsModel.fromJson(sampleJson);

      expect(model.statusOverview, isNotNull);
      expect(model.statusOverview!.totalDeviceCount, 150);
      expect(model.statusOverview!.onlineDeviceCount, 120);
      expect(model.statusOverview!.offlineWithinHourCount, 18);
      expect(model.statusOverview!.offlineOverHourCount, 12);
      expect(model.statusOverview!.abnormalDisabledCount, 5);
      expect(model.statusOverview!.lowBatteryCount, 8);
      expect(model.statusOverview!.disableTriggerCount, 3);
      expect(model.statusOverview!.totalAbnormalDeviceCount, 16);

      expect(model.abnormalSummary, isNotNull);
      expect(model.abnormalSummary!.totalCount, 45);
      expect(model.abnormalSummary!.planningFailCount, 5);
      expect(model.abnormalSummary!.locationLostCount, 3);
      expect(model.abnormalSummary!.networkAbnormalCount, 8);
      expect(model.abnormalSummary!.lowBatteryAlarmCount, 10);
      expect(model.abnormalSummary!.aiEventUnresolvedCount, 4);
      expect(model.abnormalSummary!.lightTapAlarmCount, 2);
      expect(model.abnormalSummary!.fallAlarmCount, 6);
      expect(model.abnormalSummary!.methaneAlarmCount, 1);
      expect(model.abnormalSummary!.smokeAlarmCount, 0);

      expect(model.statisticsList.length, 1);
      final item = model.statisticsList.first;
      expect(item.index, 1);
      expect(item.deviceName, "小悉-001");
      expect(item.deviceSn, "SN20260820001");
      expect(item.toDeskNumber, "1001");
      expect(item.onlineStatus, "在线");
      expect(item.currentBattery, 85);
      expect(item.disableStatus, "正常");
      expect(item.navigationFunction, "正常");
      expect(item.offlinePointDistance, "0.0 m");
      expect(item.disableCount, 0);
      expect(item.planningCount, 12);
      expect(item.locationCount, 3);
    });
  });
}
