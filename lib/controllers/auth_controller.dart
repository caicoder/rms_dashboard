import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ding_auth_config.dart';
import '../views/dashboard/dashboard_page.dart';
import '../views/login/welcome_dialog.dart';
import '../utils/sp_util.dart';
import '../utils/http_util.dart';
import '../utils/huaxi_util.dart';
import '../models/user_entity.dart';

class AuthController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isLoggedIn = false.obs;
  final RxString userId = ''.obs;
  final RxString userName = ''.obs;
  final RxString userMobile = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString("user_token");
      final String? loginDate = prefs.getString("login_date");
      final String todayStr = DateTime.now().toString().substring(0, 10); // "YYYY-MM-DD"

      // 检查 Token 存在且登录日期为今天；若非今天，则清空登录状态，要求每日重新登录
      if (token != null && token.isNotEmpty && loginDate == todayStr) {
        userId.value = prefs.getString("user_id") ?? '';
        userName.value = prefs.getString("user_name") ?? '';
        userMobile.value = prefs.getString("user_mobile") ?? '';

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
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      // ==========================================
      // 【钉钉 OAuth2.0 登录】
      // ==========================================
      String returnedUserId = '';
      String mockUserName = '内部员工';
      String mockUserMobile = '';
      String errorDetail = '';

      // 1. 【推荐标准方案】通过自己的后端中转 code 向钉钉换取用户信息
      if (DingAuthConfig.backendDingLoginApi.trim().isNotEmpty) {
        try {
          final res = await Dio().post(
            DingAuthConfig.backendDingLoginApi,
            data: {"code": code},
            options: Options(headers: {"Content-Type": "application/json"}),
          );
          if (res.data != null) {
            final dataObj = res.data["data"] ?? res.data;
            returnedUserId = dataObj["userId"]?.toString() ?? returnedUserId;
            mockUserName =
                (dataObj["name"] ?? dataObj["nick"])?.toString() ?? mockUserName;
            mockUserMobile = (dataObj["mobile"] ??
                    dataObj["phone"] ??
                    dataObj["mobilePhone"])
                ?.toString() ??
                mockUserMobile;
          }
        } catch (dioError) {
          errorDetail = '后端登录中转接口请求失败: $dioError';
          debugPrint(errorDetail);
        }
      }
      // 2. 【客户端直连模式】配置了 Client Secret 时，直接向钉钉 OpenAPI 换取用户信息
      else if (DingAuthConfig.appSecret.isNotEmpty) {
        String accessToken = '';
        try {
          debugPrint("正在请求 userAccessToken，code: $code");
          final tokenResp = await Dio().post(
            "https://api.dingtalk.com/v1.0/oauth2/userAccessToken",
            data: {
              "clientId": DingAuthConfig.appKey,
              "clientSecret": DingAuthConfig.appSecret,
              "code": code,
              "grantType": "authorization_code",
            },
          );
          debugPrint("userAccessToken 返回: ${tokenResp.data}");
          accessToken = tokenResp.data["accessToken"] ?? "";
          if (accessToken.isEmpty) {
            errorDetail = '未获取到 accessToken: ${tokenResp.data}';
          }
        } catch (dingError) {
          if (dingError is DioException) {
            errorDetail =
                '钉钉授权失败(${dingError.response?.statusCode}): ${dingError.response?.data}';
          } else {
            errorDetail = '钉钉授权失败: $dingError';
          }
          debugPrint(errorDetail);
        }

        if (accessToken.isNotEmpty) {
          // 2.1 新版接口：获取用户个人信息（需要 Contact.User.Read 权限）
          try {
            final userResp = await Dio().get(
              "https://api.dingtalk.com/v1.0/contact/users/me",
              options: Options(headers: {
                "x-acs-dingtalk-access-token": accessToken,
              }),
            );
            debugPrint("contact/users/me 返回: ${userResp.data}");
            final userJson = userResp.data;
            if (userJson != null) {
              returnedUserId = (userJson["userId"] ??
                      userJson["unionId"] ??
                      userJson["openId"])
                  ?.toString() ??
                  returnedUserId;
              mockUserName =
                  (userJson["nick"] ?? userJson["name"])?.toString() ??
                      mockUserName;
              mockUserMobile = (userJson["mobile"] ??
                      userJson["phone"] ??
                      userJson["mobilePhone"])
                  ?.toString() ??
                  mockUserMobile;
            }
          } catch (userErr) {
            debugPrint("contact/users/me 失败（可能缺少 Contact.User.Read 权限），尝试旧版免登接口: $userErr");
          }

          // 2.2 旧版免登接口：通过企业 token + 授权码获取用户信息（无需 Contact.User.Read）
          if (returnedUserId.isEmpty) {
            final oldUser = await _fetchUserByOldApi(code);
            if (oldUser != null) {
              returnedUserId = oldUser["userid"] ?? '';
              mockUserName = oldUser["name"]?.isNotEmpty == true
                  ? oldUser["name"]!
                  : mockUserName;
              mockUserMobile = oldUser["mobile"]?.isNotEmpty == true
                  ? oldUser["mobile"]!
                  : mockUserMobile;
            }
          }

          // 2.3 已成功换取 token（用户已授权登录），即便读不到资料也允许进入
          if (returnedUserId.isEmpty) {
            final short =
                accessToken.length < 8 ? accessToken : accessToken.substring(0, 8);
            returnedUserId = 'dingtalk_$short';
            debugPrint('未能读取用户资料，使用 token 生成临时身份: $returnedUserId');
          }
        }
      } else {
        errorDetail = '未配置钉钉 AppSecret';
      }
      // ==========================================

      if (returnedUserId.isEmpty) {
        throw errorDetail.isEmpty ? '未能获取钉钉用户信息' : errorDetail;
      }

      final bool allowed = !DingAuthConfig.whitelistEnabled ||
          DingAuthConfig.proUserIds.contains(returnedUserId);

      if (!allowed) {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.defaultDialog(
          title: "访问被拒绝",
          titleStyle:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                "对不起，账号：$mockUserName (ID: $returnedUserId) 不在允许访问的白名单列表中，请联系管理员添加。"),
          ),
          textConfirm: "确定",
          confirmTextColor: Colors.white,
          buttonColor: Colors.red,
          onConfirm: () => Get.back(),
        );
        return;
      }

      // 登录成功
      const String token = "mock_token_for_testing";
      final String todayStr = DateTime.now().toString().substring(0, 10);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user_token", token);
      await prefs.setString("user_id", returnedUserId);
      await prefs.setString("user_name", mockUserName);
      await prefs.setString("user_mobile", mockUserMobile);
      await prefs.setString("login_date", todayStr);

      userId.value = returnedUserId;
      userName.value = mockUserName;
      userMobile.value = mockUserMobile;
      isLoggedIn.value = true;
      HuaxiUtil.isLogn = true;

      final userEntity = UserEntity(
        userId: returnedUserId,
        accessToken: token,
      );
      await SPUtil.putLoginInfo(userEntity);

      if (Get.isDialogOpen ?? false) Get.back();

      // 欢迎弹窗：展示用户名 + 手机号
      showWelcomeDialog(
        name: mockUserName,
        mobile: mockUserMobile,
        onEnter: () => Get.offAll(() => DashboardPage()),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar(
        "登录失败",
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// 旧版免登接口：企业 access_token + 授权码 获取用户信息（无需 Contact.User.Read 权限）
  Future<Map<String, String>?> _fetchUserByOldApi(String code) async {
    try {
      final tokenResp = await Dio().get(
        "https://oapi.dingtalk.com/gettoken",
        queryParameters: {
          "appkey": DingAuthConfig.appKey,
          "appsecret": DingAuthConfig.appSecret,
        },
      );
      final String corpToken = tokenResp.data?["access_token"] ?? "";
      if (corpToken.isEmpty) {
        debugPrint("旧版免登: 获取企业 access_token 失败: ${tokenResp.data}");
        return null;
      }

      final userResp = await Dio().post(
        "https://oapi.dingtalk.com/topapi/v2/user/getuserinfo",
        queryParameters: {"access_token": corpToken},
        data: {"code": code},
      );
      debugPrint("旧版免登 getuserinfo 返回: ${userResp.data}");
      final result = userResp.data?["result"];
      if (result is Map) {
        final userid = result["userid"]?.toString() ?? "";
        final name = result["name"]?.toString() ?? "";
        String mobile = "";

        // 补充手机号（需要通讯录读取权限；失败不影响登录）
        if (userid.isNotEmpty) {
          try {
            final detailResp = await Dio().post(
              "https://oapi.dingtalk.com/topapi/v2/user/get",
              queryParameters: {"access_token": corpToken},
              data: {"userid": userid},
            );
            final detail = detailResp.data?["result"];
            if (detail is Map) {
              mobile = (detail["mobile"] ?? detail["phone"])
                      ?.toString() ??
                  "";
            }
          } catch (e) {
            debugPrint("旧版免登: 获取手机号失败: $e");
          }
        }

        return {
          "userid": userid,
          "name": name,
          "mobile": mobile,
        };
      }
    } catch (e) {
      debugPrint("旧版免登接口失败: $e");
    }
    return null;
  }

  Future<void> logout() async {
    await SPUtil.clearLoginInfo();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user_id");
    await prefs.remove("user_name");
    await prefs.remove("user_mobile");
    await prefs.remove("login_date");
    await prefs.remove("user_token");
    userId.value = '';
    userName.value = '';
    userMobile.value = '';
    isLoggedIn.value = false;
    HuaxiUtil.isLogn = false;
  }
}
