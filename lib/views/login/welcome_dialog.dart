import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 登录成功后的欢迎弹窗（展示用户名 + 手机号）
Future<void> showWelcomeDialog({
  required String name,
  required String mobile,
  VoidCallback? onEnter,
}) {
  return Get.dialog(
    WelcomeDialog(name: name, mobile: mobile, onEnter: onEnter),
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.35),
  );
}

class WelcomeDialog extends StatefulWidget {
  final String name;
  final String mobile;
  final VoidCallback? onEnter;

  const WelcomeDialog({
    Key? key,
    required this.name,
    required this.mobile,
    this.onEnter,
  }) : super(key: key);

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  static const Color _ink = Color(0xFF1F3A5F);
  static const Color _subInk = Color(0xFF7A93AE);
  static const Color _blue = Color(0xFF4EA8FF);
  static const Color _mint = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.of(context).size.width < 600;
    final name = widget.name.isEmpty ? '内部员工' : widget.name;
    final mobile = widget.mobile.isEmpty ? '未获取' : widget.mobile;

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_entrance.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: child,
          ),
        );
      },
      child: Center(
        child: DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            color: _ink,
            fontSize: 14,
          ),
          child: Container(
            width: small ? 330 : 400,
            margin: const EdgeInsets.all(24),
            padding: EdgeInsets.all(small ? 24 : 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3F0FB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: small ? 76 : 88,
                  height: small ? 76 : 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: small ? 38 : 44,
                  ),
                ),
                SizedBox(height: small ? 16 : 20),

                const Text(
                  '欢迎回来',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                    color: _subInk,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: small ? 24 : 28,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '骅羲因为你的努力更加强大',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: small ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: small ? 20 : 24),

                // 用户名 / 手机号
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FAFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3F0FB)),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.person_rounded, '用户名', name, _blue),
                      const SizedBox(height: 12),
                      _infoRow(
                          Icons.phone_iphone_rounded, '手机号', mobile, _mint),
                    ],
                  ),
                ),
                SizedBox(height: small ? 20 : 24),

                GestureDetector(
                  onTap: () {
                    Get.back();
                    widget.onEnter?.call();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '进入监控系统',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: _subInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
