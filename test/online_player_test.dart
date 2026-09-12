import 'package:flutter_test/flutter_test.dart';
import 'package:rms_dashboard/services/online_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OnlinePlayer singleton instance is not null', () {
    final player1 = OnlinePlayer.instance;
    final player2 = OnlinePlayer();
    expect(player1, isNotNull);
    expect(player1, equals(player2));
  });

  test('OnlinePlayer backward compatibility methods execute without error', () async {
    final player = OnlinePlayer.instance;
    expect(await player.isAudioCached("测试"), isTrue);
    await player.preloadAudioCache("测试");
    await player.preloadAudioCacheList(["测试1", "测试2"]);
    await player.preloadCommonAudioSentences();
    await player.clearAudioCache();
    await player.stop();
  });
}
