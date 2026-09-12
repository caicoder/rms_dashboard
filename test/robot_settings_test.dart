import 'package:flutter_test/flutter_test.dart';
import 'package:rms_dashboard/models/robot_model.dart';
import 'package:rms_dashboard/controllers/robot_controller.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('RobotModel defaults and json serialization for notification & tts settings', () {
    final robot = RobotModel(id: 'TEST_SN_001', name: '测试设备');

    // Verify defaults
    expect(robot.enableTts, isTrue);
    expect(robot.enableEstopTts, isTrue);
    expect(robot.enableEstopNotification, isTrue);
    expect(robot.enableStuckTts, isTrue);
    expect(robot.enableStuckNotification, isTrue);
    expect(robot.stuckDistanceThreshold, equals(0.5));

    // Custom values
    robot.enableTts = false;
    robot.enableEstopTts = false;
    robot.enableEstopNotification = false;
    robot.enableStuckTts = false;
    robot.enableStuckNotification = false;
    robot.stuckDistanceThreshold = 1.2;

    final json = robot.toJson();
    final decoded = RobotModel.fromJson(json);

    expect(decoded.enableTts, isFalse);
    expect(decoded.enableEstopTts, isFalse);
    expect(decoded.enableEstopNotification, isFalse);
    expect(decoded.enableStuckTts, isFalse);
    expect(decoded.enableStuckNotification, isFalse);
    expect(decoded.stuckDistanceThreshold, equals(1.2));
  });

  test('RobotController updateRobotNotificationSettings updates and persists settings', () {
    Get.reset();
    final controller = Get.put(RobotController());
    controller.robots.add(RobotModel(id: 'SN_123', name: '机器人123'));

    controller.updateRobotNotificationSettings(
      'SN_123',
      enableTts: false,
      enableEstopTts: true,
      enableEstopNotification: false,
      enableStuckTts: false,
      enableStuckNotification: true,
      stuckDistanceThreshold: 0.8,
    );

    final updated = controller.robots.firstWhere((r) => r.id == 'SN_123');
    expect(updated.enableTts, isFalse);
    expect(updated.enableEstopTts, isTrue);
    expect(updated.enableEstopNotification, isFalse);
    expect(updated.enableStuckTts, isFalse);
    expect(updated.enableStuckNotification, isTrue);
    expect(updated.stuckDistanceThreshold, equals(0.8));
  });
}
