import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../controllers/robot_controller.dart';
import '../../controllers/mqtt_controller.dart';
import '../../models/robot_model.dart';
import '../widgets/tv_focus_helper.dart';
import 'widgets/robot_card.dart';
import '../details/robot_detail_page.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/http_util.dart';
import '../../utils/api_util.dart';
import '../../utils/sp_util.dart';
import '../../utils/toast_util.dart';
import '../../models/user_entity.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({Key? key}) : super(key: key);

  final RobotController robotController = Get.put(RobotController(), permanent: true);
  final MqttController mqttController = Get.put(MqttController(), permanent: true);
  final TextEditingController _searchController = TextEditingController();

  void _showLoginDialog(BuildContext context) {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController mimaContol = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('用户登录', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '用户名/手机号',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mimaContol,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '密码',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final phone = usernameController.text.trim();
              if (phone.isEmpty || mimaContol.text.isEmpty) {
                ToastUtil.show("用户名或密码不能为空");
                return;
              }

              ToastUtil.showLoading(message: "正在登录...");

              HttpUtil.getInstance()?.post(
                ApiUtil.pwdLogin,
                {
                  "tenantId": "000000",
                  "rememberMe": false,
                  'username': phone,
                  'password': mimaContol.text,
                  "grantType": "password",
                  "clientId":"2ce32a9f2712aca5cca8defdd81b83ab",
                },
                (data) async {
                  ToastUtil.dismiss();
                  UserEntity userEntity = UserEntity.fromJson(data);
                  await SPUtil.putLoginInfo(userEntity);

                  final authController = Get.find<AuthController>();
                  authController.isLoggedIn.value = true;

                  Navigator.of(context).pop();
                  ToastUtil.show("登录成功");
                },
                (error) {
                  ToastUtil.dismiss();
                  ToastUtil.show("登录失败: $error");
                },
              );
            },
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }

  void _showAddRobotDialog(BuildContext context) {
    final TextEditingController snController = TextEditingController();
    final TextEditingController orgController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('添加机器人 (Add Robot)', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: snController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '输入设备 SN 码 (e.g., SN001234)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: orgController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '输入机构名称 (Organization)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showBatchAddDialog(context);
            },
            child: const Text('批量导入 (Batch Import)', style: TextStyle(color: Colors.amberAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消 (Cancel)', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (snController.text.trim().isNotEmpty) {
                robotController.addRobotBySn(snController.text.trim(), orgController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('添加 (Add)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBatchAddDialog(BuildContext context) {
    final TextEditingController jsonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('批量添加设备 (Batch Add)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 300,
          child: TextField(
            controller: jsonController,
            autofocus: true,
            maxLines: 15,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: '请输入 JSON 数组，例如：\n[\n  {"name": "深圳市XX机构", "SN": "ZJX110..."}\n]',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消 (Cancel)', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              try {
                var list = jsonDecode(jsonController.text.trim());
                if (list is List) {
                  int successCount = 0;
                  int skipCount = 0;
                  for (var item in list) {
                    if (item is Map && item['SN'] != null) {
                      String sn = item['SN'].toString().trim();
                      String name = item['name']?.toString().trim() ?? '';
                      if (sn.isNotEmpty) {
                        int previousCount = robotController.robots.length;
                        robotController.addRobotBySn(sn, name, showSnackbar: false);
                        if (robotController.robots.length > previousCount || robotController.robots.firstWhere((r) => r.id == sn).name == name) {
                          successCount++;
                        } else {
                          skipCount++;
                        }
                      }
                    }
                  }
                  Navigator.pop(context);
                  Get.snackbar('批量添加完成', '成功导入 $successCount 个设备，跳过已存在 $skipCount 个', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
                } else {
                  Get.snackbar('格式错误', 'JSON 必须是一个数组 []', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
                }
              } catch (e) {
                Get.snackbar('解析失败', '请输入合法的 JSON 格式', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
              }
            },
            child: const Text('导入 (Import)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // FloatingActionButton.extended(
          //   heroTag: 'clear_all',
          //   onPressed: () {
          //     showDialog(
          //       context: context,
          //       builder: (context) => AlertDialog(
          //         backgroundColor: const Color(0xFF1E293B),
          //         title: const Text('清空缓存', style: TextStyle(color: Colors.redAccent)),
          //         content: const Text('确定要清空所有设备缓存吗？这会彻底清除本地存储的所有 SN 和机构名称记录！', style: TextStyle(color: Colors.white70)),
          //         actions: [
          //           TextButton(
          //             onPressed: () => Navigator.pop(context),
          //             child: const Text('取消', style: TextStyle(color: Colors.white70)),
          //           ),
          //           ElevatedButton(
          //             style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          //             onPressed: () {
          //               robotController.clearAllRobots();
          //               Navigator.pop(context);
          //             },
          //             child: const Text('确认清空', style: TextStyle(color: Colors.white)),
          //           ),
          //         ],
          //       ),
          //     );
          //   },
          //   icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
          //   label: const Text('清空缓存', style: TextStyle(color: Colors.white)),
          //   backgroundColor: Colors.redAccent.withOpacity(0.8),
          // ),
          // const SizedBox(height: 16),
          TvFocusHelper(
            onTap: () => _showAddRobotDialog(context),
            onLongPress: () => _showBatchAddDialog(context),
            borderRadius: BorderRadius.circular(30),
            focusColor: const Color(0xFF3B82F6),
            child: FloatingActionButton.extended(
              heroTag: 'add_device',
              onPressed: () => _showAddRobotDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              label: const Text('添加设备', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSearchBar(context),
              Expanded(
                child: Stack(
                  children: [
                    Obx(() {
                      final robots = robotController.filteredRobots;
                      if (robots.isEmpty) {
                        return _buildEmptyState(isSearch: robotController.searchQuery.value.isNotEmpty);
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 450, // 自动拉伸，最大宽度450
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 24,
                            childAspectRatio: 1.1, // 调整卡片的长宽比以自适应内容
                          ),
                          itemCount: robots.length,
                          itemBuilder: (context, index) {
                            return Hero(
                              tag: 'robot_${robots[index].id}',
                              child: RobotCard(
                                key: ValueKey(robots[index].id),
                                robot: robots[index],
                              ),
                            );
                          },
                        ),
                      );
                    }),
                    
                    // Floating Alarms Panel on the Right
                    Obx(() {
                      final alarms = robotController.activeAlarms;
                      if (alarms.isEmpty) return const SizedBox.shrink();
                      
                      final isCollapsed = robotController.isAlarmsCollapsed.value;
                      return Positioned(
                        top: 16,
                        bottom: isCollapsed ? null : 16,
                        right: 24,
                        width: isCollapsed ? 200 : 320,
                        child: _buildFloatingAlarmList(context, alarms),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0, vertical: isSmallScreen ? 12.0 : 20.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.5),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.dashboard_rounded, color: const Color(0xFF3B82F6), size: isSmallScreen ? 24 : 28),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showLoginDialog(context),
                        child: Text(
                          '骅羲监控系统',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final isConnected = mqttController.connectionState.value == MqttConnectionState.connected;
                final isRetrying = mqttController.isRetrying.value;
                final retryCount = mqttController.retryCount.value;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 16, vertical: isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        color: (isConnected ? Colors.green : Colors.red).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (isConnected ? Colors.green : Colors.red).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? Colors.greenAccent : Colors.redAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: (isConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSmallScreen 
                                ? (isConnected ? '正常' : (isRetrying ? '重连($retryCount)' : '断开')) 
                                : (isConnected ? 'MQTT 连接正常' : (isRetrying ? 'MQTT 重连中($retryCount/5)' : 'MQTT 已断开')),
                            style: TextStyle(
                              color: isConnected ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          )
                        ],
                      ),
                    ),
                    if (!isConnected) ...[
                      const SizedBox(width: 8),
                      TvFocusHelper(
                        onTap: isRetrying ? () {} : () => mqttController.manualReconnect(),
                        borderRadius: BorderRadius.circular(20),
                        focusColor: Colors.blueAccent,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isRetrying ? Colors.grey.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRetrying ? Icons.hourglass_empty : Icons.refresh_rounded, 
                            color: isRetrying ? Colors.grey : Colors.blueAccent, 
                            size: 18
                          ),
                        ),
                      )
                    ]
                  ],
                );
              })
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.satellite_alt_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text(
            isSearch ? '没有找到匹配的设备' : '尚未添加设备',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              isSearch
                  ? '请尝试输入不同的 SN 或机构名称进行搜索。'
                  : '点击右下角的"添加设备"按钮输入 SN 码，开始监听机器人状态。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Obx(() {
      final query = robotController.searchQuery.value;
      if (query.isEmpty && _searchController.text.isNotEmpty) {
        _searchController.text = '';
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                robotController.searchQuery.value = val;
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索 SN 或机构名称...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          robotController.searchQuery.value = '';
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      );
    });
  }

  void _showLargeImageDialog(BuildContext context, String imgUrl) {
    const String prefix = 'https://huaxi-1330823579.cos.ap-shanghai.myqcloud.com/robot';
    final fullUrl = imgUrl.startsWith('http') ? imgUrl : prefix + imgUrl.trim();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('图片加载失败', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Obx(() {
      if (robotController.totalPages <= 1) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.swipe_rounded, color: Colors.white54, size: 20),
            const SizedBox(width: 16),
            Text(
              '当前页数: ${robotController.currentPage.value + 1} / ${robotController.totalPages} (可侧滑翻页)',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFloatingAlarmList(BuildContext context, List<ActiveAlarmItem> alarms) {
    final isCollapsed = robotController.isAlarmsCollapsed.value;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.ring_volume_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      isCollapsed ? '告警' : '实时告警监控',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${alarms.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Collapse/Expand Button
                    TvFocusHelper(
                      onTap: () {
                        robotController.isAlarmsCollapsed.value = !robotController.isAlarmsCollapsed.value;
                      },
                      borderRadius: BorderRadius.circular(8),
                      focusColor: Colors.redAccent,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isCollapsed 
                              ? Icons.keyboard_arrow_left_rounded 
                              : Icons.keyboard_arrow_right_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Alarms List
              if (!isCollapsed)
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: alarms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      // Reverse to show newest at the top
                      final alarm = alarms[alarms.length - 1 - index];
                      final timeStr = DateFormat('HH:mm:ss').format(alarm.time);
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TvFocusHelper(
                                onTap: () {
                                  Get.to(() => RobotDetailPage(robotId: alarm.robotId));
                                },
                                borderRadius: BorderRadius.circular(12),
                                focusColor: Colors.redAccent,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alarm.organization,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SN: ${alarm.robotId}',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          alarm.alarmTitle,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      if (alarm.imgUrl != null && alarm.imgUrl!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            _showLargeImageDialog(context, alarm.imgUrl!);
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              alarm.imgUrl!.startsWith('http') ? alarm.imgUrl! : 'https://huaxi-1330823579.cos.ap-shanghai.myqcloud.com/robot' + alarm.imgUrl!.trim(),
                                              width: 120,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, color: Colors.white30, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Close button to remove
                            TvFocusHelper(
                              onTap: () {
                                robotController.removeActiveAlarm(alarm);
                              },
                              borderRadius: BorderRadius.circular(8),
                              focusColor: Colors.redAccent,
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.close, color: Colors.white54, size: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
