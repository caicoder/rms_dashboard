import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rms_dashboard/controllers/robot_controller.dart';
import 'package:rms_dashboard/models/dashboard_stats_model.dart';
import 'package:rms_dashboard/models/robot_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('RobotModel displayName priority: organization (remark) > deviceName > fallback', () {
    // 1. 只有 deviceName，没有备注名
    final robot1 = RobotModel(
      id: 'SN001',
      name: '自动发现',
      deviceName: '急诊大厅1号机',
      organization: '',
    );
    expect(robot1.displayName, '急诊大厅1号机');
    expect(robot1.hasCustomRemark, false);

    // 2. 既有 deviceName，又有备注名 (organization)
    final robot2 = RobotModel(
      id: 'SN002',
      name: '急诊大厅2号机',
      deviceName: '急诊大厅2号机',
      organization: '自定义急诊分流机',
    );
    expect(robot2.displayName, '自定义急诊分流机');
    expect(robot2.hasCustomRemark, true);

    // 3. 序列化与反序列化测试
    final json = robot2.toJson();
    expect(json['deviceName'], '急诊大厅2号机');
    expect(json['organization'], '自定义急诊分流机');

    final parsed = RobotModel.fromJson(json);
    expect(parsed.deviceName, '急诊大厅2号机');
    expect(parsed.organization, '自定义急诊分流机');
    expect(parsed.displayName, '自定义急诊分流机');
  });

  test('RobotController syncRobotsFromApi and updateRobotOrganization', () {
    final controller = Get.put(RobotController());

    // 模拟接口拉取的 statisticsList
    final apiList = [
      DeviceStatisticsItem(
        deviceSn: 'ZJX1001',
        deviceName: '山东亚华电子股份有限公司',
      ),
      DeviceStatisticsItem(
        deviceSn: 'ZJX1002',
        deviceName: '浦江',
      ),
    ];

    // 同步到首页机器人列表
    controller.syncRobotsFromApi(apiList);

    expect(controller.robots.length, 2);
    final r1 = controller.robots.firstWhere((r) => r.id == 'ZJX1001');
    expect(r1.deviceName, '山东亚华电子股份有限公司');
    expect(r1.organization, ''); // 初始备注为空
    expect(r1.displayName, '山东亚华电子股份有限公司'); // 优先显示无备注时的接口名

    // 用户在详情页点击 SN 修改备注名为 "亚华1号展厅"
    controller.updateRobotOrganization('ZJX1001', '亚华1号展厅');
    expect(r1.organization, '亚华1号展厅');
    expect(r1.displayName, '亚华1号展厅'); // 优先显示备注名
    expect(r1.deviceName, '山东亚华电子股份有限公司'); // 原接口名仍保留

    // 再次从接口同步（如定时刷新），已设置的备注名必须不被覆盖
    controller.syncRobotsFromApi([
      DeviceStatisticsItem(
        deviceSn: 'ZJX1001',
        deviceName: '山东亚华电子（更新）',
      ),
    ]);
    expect(r1.deviceName, '山东亚华电子（更新）');
    expect(r1.organization, '亚华1号展厅');
    expect(r1.displayName, '亚华1号展厅');
  });
}
