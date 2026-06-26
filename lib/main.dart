import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'controllers/auth_controller.dart';
import 'views/dashboard/dashboard_page.dart';
import 'views/login/login_page.dart';
import 'config/notification_helper.dart';

import 'package:desktop_webview_window/desktop_webview_window.dart';

void main(List<String> args) async {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationHelper().initialize();
  WakelockPlus.enable();
  Get.put(AuthController()); // Initialize AuthController
  runApp(const RMSApp());
}

class RMSApp extends StatelessWidget {
  const RMSApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HuaXi Robot Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF0F172A),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
          error: Color(0xFFEF4444),
        ),
      ),
      home: Obx(() {
        final authController = Get.find<AuthController>();
        if (authController.isLoading.value) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
          );
        }
        
        if (authController.isLoggedIn.value) {
          return DashboardPage();
        } else {
          return const LoginPage();
        }
      }),
    );
  }
}
