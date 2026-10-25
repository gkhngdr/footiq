import 'dart:js_interop';

@JS('Audio')
extension type _HTMLAudio._(JSObject _) implements JSObject {
  external factory _HTMLAudio(JSString src);
  external set src(JSString v);
  external set volume(JSNumber v);
  external set currentTime(JSNumber v);
  external JSPromise<JSAny?> play();
}

final Map<String, List<_HTMLAudio>> _pool = {};
final Map<String, int> _poolIndex = {};

void preloadPlatformSounds() {
  const sounds = [
    'click', 'tick', 'correct', 'wrong', 'timeout', 'match_found',
    'coin', 'win', 'lose', 'trophy', 'energy_refill', 'gift_open',
    'daily_reward', 'level_up'
  ];
  for (final name in sounds) {
    _pool[name] = [
      _HTMLAudio('assets/assets/sounds/$name.mp3'.toJS)..volume = 0.50.toJS,
      _HTMLAudio('assets/assets/sounds/$name.mp3'.toJS)..volume = 0.50.toJS,
    ];
    _poolIndex[name] = 0;
  }
}

Future<void> playPlatformSound(String name) async {
  try {
    var list = _pool[name];
    if (list == null) {
      list = [
        _HTMLAudio('assets/assets/sounds/$name.mp3'.toJS)..volume = 0.50.toJS,
        _HTMLAudio('assets/assets/sounds/$name.mp3'.toJS)..volume = 0.50.toJS,
      ];
      _pool[name] = list;
      _poolIndex[name] = 0;
    }
    final idx = _poolIndex[name] ?? 0;
    _poolIndex[name] = (idx + 1) % list.length;
    final audio = list[idx];
    audio.currentTime = 0.toJS;
    await audio.play().toDart;
  } catch (_) {}
}
