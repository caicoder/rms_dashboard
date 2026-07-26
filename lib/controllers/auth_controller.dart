import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ding_auth_config.dart';
import '../views/dashboard/dashboard_page.dart';
import '../utils/sp_util.dart';
import '../utils/http_util.dart';
import '../utils/huaxi_util.dart';
import '../models/user_entity.dart';

class AuthController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isLoggedIn = false.obs;
  final RxString userId = ''.obs;
  final RxString userName = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString("user_token");
      final String? loginDate = ''; //prefs.getString("login_date");
      final String todayStr = DateTime.now().toString().substring(0, 10); // "YYYY-MM-DD"

      // 检查 Token 存在且登录日期为今天；若非今天，则清空登录状态，要求每日重新登录
      if (token != null && token.isNotEmpty && loginDate == todayStr) {
        userId.value = prefs.getString("user_id") ?? '';
        userName.value = prefs.getString("user_name") ?? '';

        // 恢复登录请求所需的 Header
        final loginInfo = await SPUtil.getLoginInfo();
        if (loginInfo != null) {
          HttpUtil.getInstance()?.setHeader(
              headerkey: 'Authorization',
              headerValue: 'Bearer ${loginInfo.accessToken ?? ''}');
          HttpUtil.getInstance()?.setHeader(
              headerkey: 'clientid',
              headerValue: loginInfo.clientId ?? 'a333ba1af5b78833289d00dd274a2a2d');
          HttpUtil.getInstance()?.setHeader(
              headerkey: 'tenant-id',
              headerValue: '000000');
        }
        isLoggedIn.value = true;
        HuaxiUtil.isLogn = true;
      } else {
        // 未登录或登录已跨天（不是今天），清理登录状态
        await logout();
      }
    } catch (e) {
      await logout();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithMockedBackend(String code) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      
      await Future.delayed(const Duration(seconds: 2));
      
      // Close loading dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // ==========================================
      // 【钉钉 OAuth2.0 登录机制】
      // 默认使用 Mock 测试数据（白名单中的 ID）
      String returnedUserId = "185704456832568076";
      String mockUserName = "内部员工";

      // 1. 【推荐标准方案】通过自己的后端中转 code 向钉钉换取用户信息
      if (!DingAuthConfig.backendDingLoginApi.contains("your-backend.com")) {
        try {
          final res = await Dio().post(
            DingAuthConfig.backendDingLoginApi,
            data: {"code": code},
            options: Options(headers: {"Content-Type": "application/json"}),
          );
          if (res.data != null) {
            final dataObj = res.data["data"] ?? res.data;
            returnedUserId = dataObj["userId"]?.toString() ?? returnedUserId;
            mockUserName = (dataObj["name"] ?? dataObj["nick"])?.toString() ?? mockUserName;
          }
        } catch (dioError) {
          debugPrint("后端登录中转接口请求失败: $dioError");
        }
      } 
      // 2. 【测试直连模式】配置了 appSecret 时，客户端直接向钉钉 OpenAPI 换取用户信息
      else if (DingAuthConfig.appSecret.isNotEmpty) {
        try {
          debugPrint("正在请求 userAccessToken，code: $code");
          // 第一步：用 code 换取 userAccessToken
          final tokenResp = await Dio().post(
            "https://api.dingtalk.com/v1.0/oauth2/userAccessToken",
            data: {
              "clientId": DingAuthConfig.appKey,
              "clientSecret": DingAuthConfig.appSecret,
              "code": code,
              "grantType": "authorization_code",
            },
          );
          debugPrint("userAccessToken 成功返回: ${tokenResp.data}");
          final String accessToken = tokenResp.data["accessToken"] ?? "";

          if (accessToken.isNotEmpty) {
            debugPrint("正在请求 contact/users/me 获取个人信息");
            // 第二步：用 userAccessToken 获取用户个人信息 (userId, nick/name)
            final userResp = await Dio().get(
              "https://api.dingtalk.com/v1.0/contact/users/me",
              options: Options(headers: {
                "x-acs-dingtalk-access-token": accessToken,
              }),
            );
            debugPrint("contact/users/me 成功返回: ${userResp.data}");
            final userJson = userResp.data;
            if (userJson != null) {
              returnedUserId = (userJson["userId"] ?? userJson["unionId"] ?? userJson["openId"])?.toString() ?? returnedUserId;
              mockUserName = (userJson["nick"] ?? userJson["name"])?.toString() ?? mockUserName;
            }
          }
        } catch (dingError) {
          if (dingError is DioException) {
            debugPrint("直连钉钉 OpenAPI 失败. Status: ${dingError.response?.statusCode}, Response Data: ${dingError.response?.data}, Error: $dingError");
          } else {
            debugPrint("直连钉钉 OpenAPI 失败: $dingError");
          }
        }
      }
      // ==========================================

      // 验证用户是否在白名单内
      if (DingAuthConfig.proUserIds.contains(returnedUserId)) {
        // 白名单验证通过
        String mockToken = "mock_token_for_testing";
        final String todayStr = DateTime.now().toString().substring(0, 10);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user_token", mockToken);
        await prefs.setString("user_id", returnedUserId);
        await prefs.setString("user_name", mockUserName);
        await prefs.setString("login_date", todayStr); // 记录登录日期

        // 更新控制器的响应式状态
        userId.value = returnedUserId;
        userName.value = mockUserName;
        isLoggedIn.value = true;
        HuaxiUtil.isLogn = true;

        // 保存登录实体并设置请求头
        final userEntity = UserEntity(
          userId: returnedUserId,
          accessToken: mockToken,
        );
        await SPUtil.putLoginInfo(userEntity);
        
        // 弹出欢迎进入的弹窗
        Get.defaultDialog(
          title: "欢迎进入",
          titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                Text("欢迎回来，$mockUserName！", style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          textConfirm: "进入系统",
          confirmTextColor: Colors.white,
          buttonColor: const Color(0xFF3B82F6),
          onConfirm: () {
            Get.back(); // 关闭弹窗
            Get.offAll(() => DashboardPage()); // 跳转至主页
          },
        );
      } else {
        // 不在白名单中，禁止进入并显示当前获取到的姓名和ID
        Get.defaultDialog(
          title: "访问被拒绝",
          titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("对不起，账号：$mockUserName (ID: $returnedUserId) 不在允许访问的白名单列表中，请联系胡森熙添加。"),
          ),
          textConfirm: "确定",
          confirmTextColor: Colors.white,
          buttonColor: Colors.red,
          onConfirm: () => Get.back(),
        );
      }
      
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar(
        "登录失败",
        "发生错误: $e",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> logout() async {
    await SPUtil.clearLoginInfo();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user_id");
    await prefs.remove("user_name");
    await prefs.remove("login_date");
    await prefs.remove("user_token");
    userId.value = '';
    userName.value = '';
    isLoggedIn.value = false;
    HuaxiUtil.isLogn = false;
  }
}
