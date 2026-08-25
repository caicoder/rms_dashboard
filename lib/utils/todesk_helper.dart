import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_platform/universal_platform.dart';
import 'toast_util.dart';

class TodeskHelper {
  static final Map<String, Map<String, dynamic>?> _configCache = {};
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static const Map<String, String> todeskFieldLabels = {
    'clientid': '设备代码 (Client ID)',
    'loginphone': '登录手机号',
    'loginemail': '登录邮箱',
    'version': 'ToDesk版本',
    'resolution': '屏幕分辨率',
    'areacode': '国家/地区代码',
    'lastpushtimeex': '最后推送时间',
    'updatepasstime': '密码更新时间',
    'presetdialogupdatedate': '预设弹窗更新日期',
    'downloadtimes': '下载时间/次数',
    'logintype': '登录类型',
    'isopentemppass': '开启临时密码',
    'autolockscreen': '自动锁屏',
    'privatescreenlockscreen': '隐私屏锁屏',
    'isadmissioncontrol': '准入控制',
    'isupdate': '是否有新版本更新',
    'weakpasswordtip': '弱密码提示',
    'passupdate': '密码更新标记',
    'updatetemppassdefault': '默认更新临时密码',
    'user': '用户名',
    'pluginexpiresdays': '插件过期天数',
    'presetdialogshowcount': '预设弹窗显示次数',
    'isfirstconnect': '首次连接标记',
    'updatefrequencypromptbubble': '更新频率气泡提示',
    'language': '语言编码',
    'tempauthpassex': '临时授权密码',
    'token': 'Token',
    'newtoken': 'New Token',
    'privatedata': '私有数据',
  };

  /// 从腾讯云 COS 异步获取 ToDesk config.ini 配置
  static Future<Map<String, dynamic>?> fetchTodeskConfig(String deviceSn) async {
    if (deviceSn.trim().isEmpty) return null;
    final cleanSn = deviceSn.trim();

    if (_configCache.containsKey(cleanSn)) {
      return _configCache[cleanSn];
    }

    final url = 'https://huaxi-1330823579.cos.ap-shanghai.myqcloud.com/robot/todesk/$cleanSn/config.ini';
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final content = response.data.toString();
        if (content.isNotEmpty && (content.contains('clientid') || content.contains('[configinfo]'))) {
          final config = _parseIniContent(content);
          if (config.isNotEmpty) {
            _configCache[cleanSn] = config;
            return config;
          }
        }
      }
    } catch (_) {
      // 404 或网络无该设备配置
    }

    _configCache[cleanSn] = null;
    return null;
  }

  static Map<String, dynamic> _parseIniContent(String content) {
    final Map<String, dynamic> result = {};
    final lines = content.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('[') || line.startsWith('#') || line.startsWith(';')) {
        continue;
      }
      final eqIndex = line.indexOf('=');
      if (eqIndex != -1) {
        final key = line.substring(0, eqIndex).trim().toLowerCase();
        final value = line.substring(eqIndex + 1).trim();
        if (key.isNotEmpty) {
          result[key] = value;
        }
      }
    }
    return result;
  }

  /// 调起本地安装的 ToDesk 并传入 ClientID 与默认密码进行直连
  static Future<void> launchTodesk(String clientId) async {
    if (clientId.isEmpty) {
      ToastUtil.show('ClientID 为空，无法调起 ToDesk');
      return;
    }

    final uriString = 'todesk://connect&$clientId&huaxi123';
    debugPrint('Launching ToDesk scheme: $uriString');

    try {
      if (UniversalPlatform.isMacOS) {
        await Process.run('open', [uriString]);
        ToastUtil.show('正在调起 ToDesk 连接: $clientId');
      } else if (UniversalPlatform.isWindows) {
        bool launched = false;

        // 优先尝试 1: 检索 Windows 默认物理安装路径直接启动 ToDesk.exe 并传参 (最稳定，无弹窗)
        final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
        final appData = Platform.environment['APPDATA'] ?? '';
        final possiblePaths = [
          r'C:\Program Files (x86)\ToDesk\ToDesk.exe',
          r'C:\Program Files\ToDesk\ToDesk.exe',
          if (localAppData.isNotEmpty) '$localAppData\\ToDesk\\ToDesk.exe',
          if (appData.isNotEmpty) '$appData\\ToDesk\\ToDesk.exe',
        ];
        for (var exePath in possiblePaths) {
          if (File(exePath).existsSync()) {
            try {
              await Process.start(exePath, ['-connect', clientId, '-password', 'huaxi123']);
              launched = true;
              debugPrint('Successfully launched ToDesk via exe path: $exePath');
              break;
            } catch (e) {
              debugPrint('Direct EXE launch failed: $e');
            }
          }
        }

        // 尝试 2: PowerShell Start-Process 原生调起协议 (处理 URL 协议最规范，不会被误认为文件路径)
        if (!launched) {
          try {
            final res = await Process.run('powershell', ['-Command', 'Start-Process "$uriString"']);
            if (res.exitCode == 0) launched = true;
          } catch (e) {
            debugPrint('PowerShell launch failed: $e');
          }
        }

        // 尝试 3: explorer.exe 调起协议
        if (!launched) {
          try {
            final res = await Process.run('explorer', [uriString]);
            if (res.exitCode == 0) launched = true;
          } catch (e) {
            debugPrint('Explorer launch failed: $e');
          }
        }

        // 尝试 4: cmd /c start (使用 ^ 转义 & 符，不添加整体双引号，防止 Windows cmd 误将其识别为本地文件路径)
        if (!launched) {
          try {
            final escapedUri = uriString.replaceAll('&', '^&');
            final res = await Process.run('cmd', ['/c', 'start', '', escapedUri]);
            if (res.exitCode == 0) launched = true;
          } catch (e) {
            debugPrint('CMD launch failed: $e');
          }
        }

        ToastUtil.show('正在调起 ToDesk 连接: $clientId');
      } else {
        ToastUtil.show('仅支持 macOS / Windows 端调起 ToDesk');
      }
    } catch (e) {
      debugPrint('Error launching ToDesk: $e');
      ToastUtil.show('调起 ToDesk 失败: $e');
    }
  }

  /// 弹出高颜值 ToDesk 配置详情与远程直连弹窗
  static void showTodeskDetailDialog(
    BuildContext context, {
    required String deviceSn,
    required Map<String, dynamic> config,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final entries = config.entries.toList();
        final clientId = config['clientid']?.toString() ?? '';

        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF0284C7).withOpacity(0.4)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.desktop_windows_rounded, color: Color(0xFF38BDF8), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ToDesk 配置详情 (SN: $deviceSn)',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: entries.map((entry) {
                  final key = entry.key;
                  final val = entry.value?.toString() ?? '';
                  final chineseLabel = todeskFieldLabels[key.toLowerCase()] ?? key;
                  final isImportant = key.toLowerCase() == 'clientid' ||
                      key.toLowerCase() == 'loginphone' ||
                      key.toLowerCase() == 'version';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isImportant
                          ? const Color(0xFF0284C7).withOpacity(0.12)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: isImportant
                          ? Border.all(color: const Color(0xFF0284C7).withOpacity(0.4))
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 180,
                          child: Text(
                            chineseLabel,
                            style: TextStyle(
                              color: isImportant ? const Color(0xFF38BDF8) : Colors.white70,
                              fontWeight: isImportant ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            val,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            // 直连 ToDesk 按钮
            if (clientId.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  launchTodesk(clientId);
                },
                icon: const Icon(Icons.play_circle_filled_rounded, size: 16, color: Colors.white),
                label: const Text('启动 ToDesk 连接', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            // 复制 ClientID 按钮
            if (clientId.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: clientId));
                  ToastUtil.show('ClientID 已复制到剪贴板');
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF38BDF8)),
                label: const Text('复制 ClientID', style: TextStyle(color: Color(0xFF38BDF8))),
              ),
            // 关闭按钮
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
