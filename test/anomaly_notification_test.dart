import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rms_dashboard/controllers/robot_controller.dart';
import 'package:rms_dashboard/models/anomaly_notification_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AnomalyNotificationItem serialization and deserialization', () {
    final item = AnomalyNotificationItem(
      id: 'test_estop_1',
      robotId: 'SN_1001',
      organization: '华西一院',
      title: '华西一院 触发急停',
      message: '在 X: 10.50, Y: 20.30 触发急停',
      type: AnomalyType.estop,
      time: DateTime(2026, 9, 3, 15, 30, 0),
      positionX: 10.5,
      positionY: 20.3,
    );

    final json = item.toJson();
    final parsed = AnomalyNotificationItem.fromJson(json);

    expect(parsed.id, 'test_estop_1');
    expect(parsed.robotId, 'SN_1001');
    expect(parsed.organization, '华西一院');
    expect(parsed.title, '华西一院 触发急停');
    expect(parsed.type, AnomalyType.estop);
    expect(parsed.positionX, 10.5);
    expect(parsed.positionY, 20.3);
  });

  test('RobotController anomaly notifications add and clear operations', () {
    final controller = Get.put(RobotController());

    // 添加来自华西一院不同 SN 的通知
    controller.addAnomalyNotification(AnomalyNotificationItem(
      id: 'item_1',
      robotId: 'SN_A1',
      organization: '华西一院',
      title: '华西一院 触发急停',
      message: '坐标 X: 1.0, Y: 2.0',
      type: AnomalyType.estop,
      time: DateTime.now(),
    ));

    controller.addAnomalyNotification(AnomalyNotificationItem(
      id: 'item_2',
      robotId: 'SN_A2',
      organization: '华西一院',
      title: '华西一院 在巡检中疑似停止不动',
      message: '持续5分钟未移动',
      type: AnomalyType.stuck,
      time: DateTime.now(),
    ));

    // 添加来自省人民医院的通知
    controller.addAnomalyNotification(AnomalyNotificationItem(
      id: 'item_3',
      robotId: 'SN_B1',
      organization: '省人民医院',
      title: '省人民医院 触发急停',
      message: '坐标 X: 5.0, Y: 6.0',
      type: AnomalyType.estop,
      time: DateTime.now(),
    ));

    expect(controller.anomalyNotifications.length, 3);

    // 测试清空指定机构：华西一院
    controller.clearAnomalyNotificationsByOrg('华西一院');
    expect(controller.anomalyNotifications.length, 1);
    expect(controller.anomalyNotifications.first.organization, '省人民医院');

    // 测试单条删除
    controller.removeAnomalyNotification('item_3');
    expect(controller.anomalyNotifications.isEmpty, true);

    // 测试一键清除
    controller.addAnomalyNotification(AnomalyNotificationItem(
      id: 'item_4',
      robotId: 'SN_C1',
      organization: '华西二院',
      title: '急停',
      message: '...',
      type: AnomalyType.estop,
      time: DateTime.now(),
    ));
    expect(controller.anomalyNotifications.length, 1);
    controller.clearAllAnomalyNotifications();
    expect(controller.anomalyNotifications.isEmpty, true);
  });
}
