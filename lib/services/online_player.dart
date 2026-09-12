import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PlayRequest {
  final String text;
  final bool useCache;

  PlayRequest(this.text, [this.useCache = true]);
}

/// 本地离线 TTS 语音播报单例服务
/// 使用 flutter_tts 框架，完全本地合成，零网络请求费用，支持 Windows 和 macOS 等全平台。
class OnlinePlayer {
  static final OnlinePlayer _instance = OnlinePlayer._internal();

  factory OnlinePlayer() => _instance;
  static OnlinePlayer get instance => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final Queue<PlayRequest> _playQueue = Queue<PlayRequest>();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  bool _isSpeaking = false;
  bool _isProcessingRequest = false;
  int _sessionId = 0;
  Completer<void>? _speechCompleter;

  FlutterTts get tts => _flutterTts;

  OnlinePlayer._internal() {
    _initTts();
  }

  /// 初始化本地 TTS 引擎配置
  Future<void> _initTts() async {
    _initFuture ??= _doInitTts();
    return _initFuture!;
  }

  Future<void> _doInitTts() async {
    if (_isInitialized) return;
    try {
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _onSpeechFinished();
      });

      _flutterTts.setCancelHandler(() {
        _onSpeechFinished();
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("[TTS] 播报异常: $msg");
        _onSpeechFinished();
      });

      await _configureTts();
      _isInitialized = true;
      debugPrint("[TTS] 本地 TTS 引擎初始化完成");
    } catch (e) {
      debugPrint("[TTS] 本地 TTS 初始化失败: $e");
    }
  }

  /// 配置 TTS 语言、音量、音高与语速
  Future<void> _configureTts() async {
    // 1. 设置中文语言
    bool langSet = false;
    try {
      final result = await _flutterTts.setLanguage("zh-CN");
      if (result == 1) {
        langSet = true;
      }
    } catch (_) {}

    if (!langSet) {
      try {
        final languages = await _flutterTts.getLanguages;
        if (languages is List) {
          final zh = languages.firstWhere(
            (l) => l.toString().toLowerCase().contains('zh'),
            orElse: () => null,
          );
          if (zh != null) {
            await _flutterTts.setLanguage(zh.toString());
            langSet = true;
          }
        }
      } catch (_) {}
    }

    // 2. 音量 (0.0 - 1.0)
    try {
      await _flutterTts.setVolume(1.0);
    } catch (_) {}

    // 3. 音高 (0.5 - 2.0，默认 1.0)
    try {
      await _flutterTts.setPitch(1.0);
    } catch (_) {}

    // 4. 语速 (平滑适配 macOS、Windows 及其他平台)
    try {
      if (!kIsWeb && !Platform.isWindows) {
        final range = await _flutterTts.getSpeechRateValidRange;
        await _flutterTts.setSpeechRate(range.normal);
      } else {
        await _flutterTts.setSpeechRate(0.5);
      }
    } catch (_) {
      try {
        await _flutterTts.setSpeechRate(0.5);
      } catch (_) {}
    }

    // 5. iOS 音频会话设置
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } catch (_) {}
    }
  }

  void _onSpeechFinished() {
    _isSpeaking = false;
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
  }

  /// 判断当前是否正在发声播报
  bool isSpeaking() {
    return _isSpeaking;
  }

  /// 暂停当前语音播报
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      debugPrint("[TTS] pause error: $e");
    }
  }

  /// 恢复播放
  Future<void> resume() async {
    try {
      // 在 macOS/Windows 上，当处于 pause 状态时调用 speak("") 会恢复播放
      await _flutterTts.speak("");
    } catch (e) {
      debugPrint("[TTS] resume error: $e");
    }
  }

  /// 等待执行的排队播放（加入 FIFO 播放队列，依次播报）
  void playTTSWait(String text, {bool useCache = true}) {
    if (text.trim().isEmpty) return;
    _playQueue.add(PlayRequest(text, useCache));
    if (!_isProcessingRequest) {
      _processNextRequest();
    }
  }

  /// 立即播报 TTS 语音（会打断当前播报并清空等待队列）
  Future<void> playTTS(String text, {bool useCache = true}) async {
    if (text.trim().isEmpty) return;
    debugPrint("[TTS] 立即播放入参 --- 文本内容: $text");

    await interruptCurrentSpeech();

    _isProcessingRequest = true;
    await _executePlayRequest(text, _sessionId);
  }

  Future<void> _processNextRequest() async {
    if (_playQueue.isNotEmpty) {
      _isProcessingRequest = true;
      final request = _playQueue.removeFirst();
      await _executePlayRequest(request.text, _sessionId);
    } else {
      _isProcessingRequest = false;
    }
  }

  Future<void> _executePlayRequest(String text, int sessionId) async {
    if (text.trim().isEmpty) {
      if (sessionId == _sessionId) {
        _processNextRequest();
      }
      return;
    }

    try {
      await _initTts();
      if (sessionId != _sessionId) return;

      _speechCompleter = Completer<void>();
      _isSpeaking = true;

      debugPrint("[TTS] 开始本地合成播报: $text");
      await _flutterTts.speak(text);

      // 超时安全保护机制：按文本长度估算最大超时时间，防止平台底层异常未回传回调导致队列假死
      final timeoutMs = (2500 + text.length * 350).clamp(4000, 30000);
      try {
        await _speechCompleter!.future.timeout(Duration(milliseconds: timeoutMs));
      } on TimeoutException {
        debugPrint("[TTS] 播报等待超时(${timeoutMs}ms)，自动处理下一个");
      }
    } catch (e) {
      debugPrint("[TTS] 播报执行失败: $e");
    } finally {
      _isSpeaking = false;
      if (sessionId == _sessionId) {
        _processNextRequest();
      }
    }
  }

  /// 打断当前对话/TTS播放：
  /// 1. 递增会话版本号，让旧的异步任务退出
  /// 2. 清空播放队列
  /// 3. 停止当前发声
  Future<void> interruptCurrentSpeech() async {
    debugPrint("[TTS] 打断当前语音播报");
    _sessionId++;
    _playQueue.clear();

    if (_isSpeaking) {
      try {
        await _flutterTts.stop();
      } catch (e) {
        debugPrint("[TTS] stop error: $e");
      }
    }

    _onSpeechFinished();
    _isSpeaking = false;
    _isProcessingRequest = false;
  }

  /// 打断当前对话 (别名方法)
  Future<void> interruptConversation() async {
    await interruptCurrentSpeech();
  }

  /// 停止播放 (别名方法)
  Future<void> stop() async {
    await interruptCurrentSpeech();
  }

  /// 兼容旧代码接口：离线 TTS 本地可用，始终为 true
  Future<bool> isAudioCached(String text) async {
    return true;
  }

  /// 兼容旧代码接口：离线 TTS 无需网络提前下载
  Future<void> preloadAudioCache(String text) async {
    await _initTts();
  }

  /// 兼容旧代码接口：批量提前下载
  Future<void> preloadAudioCacheList(List<String> textList) async {
    await _initTts();
  }

  /// 兼容旧代码接口：加载常用句子并初始化
  Future<void> preloadCommonAudioSentences() async {
    await _initTts();
  }

  /// 兼容旧代码接口：清除缓存（离线无需本地文件缓存，执行打断即可）
  Future<void> clearAudioCache() async {
    await interruptCurrentSpeech();
  }

  // --- 外部自定义参数配置方法 ---

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  Future<dynamic> getLanguages() async {
    return await _flutterTts.getLanguages;
  }

  Future<dynamic> getVoices() async {
    return await _flutterTts.getVoices;
  }
}
