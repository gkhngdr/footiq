import 'package:flutter/services.dart';

const _channel = MethodChannel('footiq/sound');

Future<void> playPlatformSound(String name) async {
  try {
    await _channel.invokeMethod<void>('play', {'name': name});
  } catch (_) {
    // Masaüstü / test ortamında kanal yoksa SystemSound yedeği
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
