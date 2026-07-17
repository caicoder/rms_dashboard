import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_entity.dart';
import 'http_util.dart';

class SPUtil {
  static Future<void> putLoginInfo(UserEntity userEntity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("login_info", jsonEncode(userEntity.toJson()));
    if (userEntity.accessToken != null) {
      await prefs.setString("user_token", userEntity.accessToken!);
    }

     HttpUtil.getInstance()?.setHeader(
        headerkey: 'Authorization',
        headerValue: 'Bearer ${userEntity.accessToken ?? ''}');
     HttpUtil.getInstance()?.setHeader(
        headerkey: 'clientid',
        headerValue: userEntity.clientId ?? 'a333ba1af5b78833289d00dd274a2a2d');
     HttpUtil.getInstance()?.setHeader(
        headerkey: 'tenant-id',
        headerValue: '000000');
  }

  static Future<UserEntity?> getLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString("login_info");
    if (jsonStr != null) {
      try {
        return UserEntity.fromJson(jsonDecode(jsonStr));
      } catch (_) {}
    }
    return null;
  }

  static Future<void> clearLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("login_info");
    await prefs.remove("user_token");
  }
}
