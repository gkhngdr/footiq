import 'package:flutter/services.dart';

import 'game_state.dart';
import 'sound_stub.dart' if (dart.library.js_interop) 'sound_web.dart';

/// Oyun içi ses efektleri ve dokunsal geri bildirim yöneticisi.
/// `assets/sounds/` içerisindeki `.mp3` veya `.wav` dosyalarını hem Android/iOS
/// hem de Web üzerinde gecikmesiz çalar.
class Sound {
  Sound._();

  static void _play(String name) {
    if (!GameState.instance.soundOn) return;
    playPlatformSound(name);
  }

  /// Genel buton ve kart tıklaması.
  static void click() => _play('click');

  /// Doğru cevap seçildiğinde.
  static void correct() {
    if (!GameState.instance.soundOn) return;
    HapticFeedback.lightImpact();
    _play('correct');
  }

  /// Yanlış cevap seçildiğinde.
  static void wrong() {
    if (!GameState.instance.soundOn) return;
    HapticFeedback.heavyImpact();
    _play('wrong');
  }

  /// Süre dolduğunda.
  static void timeout() {
    if (!GameState.instance.soundOn) return;
    HapticFeedback.heavyImpact();
    _play('timeout');
  }

  /// Son 5 saniye geri sayım tıkırtısı.
  static void tick() => _play('tick');

  /// Seviye geçildiğinde veya PVP kazanıldığında.
  static void win() {
    if (!GameState.instance.soundOn) return;
    HapticFeedback.mediumImpact();
    _play('win');
  }

  /// Seviye veya PVP kaybedildiğinde.
  static void lose() => _play('lose');

  /// Coin kazanıldığında.
  static void coin() => _play('coin');

  /// Kupa kazanıldığında.
  static void trophy() => _play('trophy');

  /// PVP rakip bulunduğunda / maç başladığında.
  static void matchFound() {
    if (!GameState.instance.soundOn) return;
    HapticFeedback.selectionClick();
    _play('match_found');
  }

  /// Enerji yenilendiğinde (+1 enerji).
  static void energyRefill() => _play('energy_refill');

  /// Oynadıkça kazan hediyesi açıldığında.
  static void giftOpen() => _play('gift_open');

  /// Günlük ödül toplandığında.
  static void dailyReward() => _play('daily_reward');

  /// Yeni yıldız / seviye kilidi açıldığında.
  static void levelUp() => _play('level_up');
}
