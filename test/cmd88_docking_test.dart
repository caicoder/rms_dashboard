import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rms_dashboard/controllers/robot_controller.dart';
import 'package:rms_dashboard/models/docking_notification_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DockingNotificationItem serialization and deserialization', () {
    final item = DockingNotificationItem(
      id: 'test_1',
      sn: 'HX001',
      organization: '华西医院',
      reason: '充电对桩超时，红外信号弱',
      taskId: 'task_888',
      type: '2',
      subtype: 1,
      time: DateTime(2026, 9, 3, 12, 0, 0),
    );

    final json = item.toJson();
    final parsed = DockingNotificationItem.fromJson(json);

    expect(parsed.id, 'test_1');
    expect(parsed.sn, 'HX001');
    expect(parsed.organization, '华西医院');
    expect(parsed.reason, '充电对桩超时，红外信号弱');
    expect(parsed.taskId, 'task_888');
    expect(parsed.type, '2');
    expect(parsed.subtype, 1);
  });

  test('RobotController handleCmd88Notification collects data correctly', () {
    final controller = Get.put(RobotController());
    controller.addRobotBySn('HX001', '测试机构A', showSnackbar: false);

    // 格式1: reason 和 taskId 直接在 body 根层级
    final msg1 = {
      'cmdId': 88,
      'timeTag': 1711234567,
      'version': 2,
      'body': {
        'type': '2',
        'subtype': 1,
        'taskId': 'task_001',
        'reason': '对桩超时：未搜索到桩信号',
      },
    };

    controller.handleCmd88Notification('HX001', msg1);

    expect(controller.dockingNotifications.length, 1);
    expect(controller.dockingNotifications.first.organization, '测试机构A');
    expect(controller.dockingNotifications.first.sn, 'HX001');
    expect(controller.dockingNotifications.first.reason, '对桩超时：未搜索到桩信号');
    expect(controller.dockingNotifications.first.taskId, 'task_001');

    // 格式2: reason 和 taskId 在 body['params']
    final msg2 = {
      'cmdId': 88,
      'timeTag': 1711234568,
      'version': 2,
      'body': {
        'type': '2',
        'subtype': 1,
        'params': {
          'taskId': 'task_002',
          'reason': '对桩超时：电极未对齐',
        },
      },
    };

    controller.handleCmd88Notification('HX001', msg2);

    expect(controller.dockingNotifications.length, 2);
    expect(controller.dockingNotifications.first.reason, '对桩超时：电极未对齐');
    expect(controller.dockingNotifications.first.taskId, 'task_002');
  });
}
