import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:universal_html/html.dart' as html;
import '../../config/ding_auth_config.dart';
import '../../controllers/auth_controller.dart';
import 'ding_webview_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final AuthController _authController = Get.put(AuthController());

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    _animationController.forward();
    
    // Setup listener for web redirect
    if (UniversalPlatform.isWeb) {
      _setupWebListener();
    }
  }

  void _setupWebListener() {
    html.window.addEventListener("popstate", (event) {
      final uri = Uri.parse(html.window.location.href);
      final code = uri.queryParameters["code"] ?? uri.queryParameters["authCode"];
      if (code != null && code.isNotEmpty) {
        _authController.loginWithMockedBackend(code);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDingTalkLogin() {
    final params = {
      "redirect_uri": Uri.encodeComponent(DingAuthConfig.redirectUri),
      "response_type": "code",
      "client_id": DingAuthConfig.appKey,
      "scope": "openid Contact.Read.User",
      "state": DateTime.now().millisecondsSinceEpoch.toString()
    };
    
    final query = params.entries.map((e) => "${e.key}=${e.value}").join("&");
    final authUrl = "https://login.dingtalk.com/oauth2/auth?$query";

    if (UniversalPlatform.isWeb) {
      // Web: Open in new window
      html.window.open(authUrl, "_blank");
    } else {
      // Native (Android/iOS/macOS): Open WebView
      Get.to(() => DingWebviewPage(authUrl: authUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Abstract Shapes
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Dark blue base
                  Color(0xFF1E293B), // Lighter slate
                  Color(0xFF020617), // Deepest night
                ],
              ),
            ),
          ),
          
          // Glowing Orb 1
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: isSmallScreen ? 250 : 400,
              height: isSmallScreen ? 250 : 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    blurRadius: isSmallScreen ? 60 : 100,
                    spreadRadius: isSmallScreen ? 30 : 50,
                  ),
                ],
              ),
            ),
          ),

          // Glowing Orb 2
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: isSmallScreen ? 300 : 500,
              height: isSmallScreen ? 300 : 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    blurRadius: isSmallScreen ? 80 : 120,
                    spreadRadius: isSmallScreen ? 40 : 60,
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSmallScreen ? 24 : 30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 450),
                        padding: EdgeInsets.all(isSmallScreen ? 24 : 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 24 : 30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo Placeholder / Icon
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.rocket_launch_rounded,
                                size: isSmallScreen ? 40 : 50,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 20 : 30),
                            
                            // Title
                            Text(
                              "骅羲智能监控系统",
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 24 : 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            
                            // Subtitle
                            Text(
                              "企业内部员工专属通道",
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isSmallScreen ? 32 : 48),

                            // DingTalk Login Button
                            InkWell(
                              onTap: _handleDingTalkLogin,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // DingTalk icon mock (can use image asset if available)
                                    Icon(
                                      Icons.chat_bubble_rounded, // fallback icon
                                      color: Colors.white,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "钉钉一键授权登录",
                                      style: GoogleFonts.inter(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 20 : 24),
                            
                            // Security Note
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.security,
                                  size: isSmallScreen ? 14 : 16,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "数据传输已全程加密",
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 11 : 12,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
