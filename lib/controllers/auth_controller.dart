import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ding_auth_config.dart';
import '../views/dashboard/dashboard_page.dart';
import '../utils/sp_util.dart';
import '../utils/http_util.dart';
import '../utils/huaxi_util.dart';

class AuthController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString("user_token");
      if (token != null && token.isNotEmpty) {
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
        // HuaxiUtil.isLogn = true;
      } else {
        isLoggedIn.value = false;
        HuaxiUtil.isLogn = false;
      }
    } catch (e) {
      isLoggedIn.value = false;
      HuaxiUtil.isLogn = false;
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
      // TODO: 真实对接后端时，这里应换成真实的 Dio 请求，
      // 并从后端接口返回的数据中获取真实的 userId 和 name。
      final res = await Dio().post(DingAuthConfig.backendDingLoginApi, data: {"code": code});
      final String returnedUserId = res.data["userId"];
      final String mockUserName = res.data["name"];
      // ==========================================

      // 【Mock】模拟后端返回的用户ID（使用白名单中的一个ID以便测试成功流程）
      // 您可以将其修改为一个不在白名单的ID来测试被拦截的效果。
      // String mockReturnedUserId = "185704456832568076";
      // String mockUserName = "内部员工";

      // 验证用户是否在白名单内
      if (DingAuthConfig.proUserIds.contains(returnedUserId)) {
        // 白名单验证通过
        String mockToken = "mock_token_for_testing";
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user_token", mockToken);
        
      // Update state directly

        
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
          },
        );
      } else {
        // 不在白名单中，禁止进入
        Get.defaultDialog(
          title: "访问被拒绝",
          titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          content: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("对不起，您的账号不在允许访问的白名单列表中，无法进入系统。"),
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
    isLoggedIn.value = false;
    HuaxiUtil.isLogn = false;
  }
}
