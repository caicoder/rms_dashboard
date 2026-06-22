import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:get/get.dart';
import '../../config/ding_auth_config.dart';
import '../../controllers/auth_controller.dart';

class DingWebviewPage extends StatefulWidget {
  final String authUrl;

  const DingWebviewPage({Key? key, required this.authUrl}) : super(key: key);

  @override
  State<DingWebviewPage> createState() => _DingWebviewPageState();
}

class _DingWebviewPageState extends State<DingWebviewPage> {
  late final WebViewController _webController;
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) async {
          // Intercept the redirect callback
          if (request.url.startsWith(DingAuthConfig.redirectUri)) {
            final uri = Uri.parse(request.url);
            // DingTalk sometimes returns 'authCode' instead of 'code' depending on the API version used
            final code = uri.queryParameters["code"] ?? uri.queryParameters["authCode"];
            
            if (code != null && code.isNotEmpty) {
              // Close the webview and pass code to backend
              Get.back();
              await _authController.loginWithMockedBackend(code);
            } else {
              // If there's an error or no code
              Get.back();
              // Show the actual parameters returned for easier debugging
              String errorMsg = uri.queryParameters["error"] ?? "未知错误";
              Get.snackbar("登录失败", "未获取到授权Code. 参数: ${uri.queryParameters}", backgroundColor: Colors.red, colorText: Colors.white, duration: const Duration(seconds: 5));
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("钉钉员工验证登录"),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
      ),
      body: WebViewWidget(controller: _webController),
    );
  }
}
