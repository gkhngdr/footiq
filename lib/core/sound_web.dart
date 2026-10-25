import 'dart:js_interop';

@JS('Audio')
extension type _HTMLAudio._(JSObject _) implements JSObject {
  external factory _HTMLAudio(JSString src);
  external set src(JSString v);
  external set volume(JSNumber v);
  external set onerror(JSFunction? fn);
  external JSPromise<JSAny?> play();
}

Future<void> playPlatformSound(String name) async {
  try {
    final audio = _HTMLAudio('assets/assets/sounds/$name.mp3'.toJS)..volume = 0.55.toJS;
    audio.onerror = ((JSAny? _) {
      audio.onerror = null;
      audio.src = 'assets/assets/sounds/$name.wav'.toJS;
      audio.play();
    }).toJS;
    await audio.play().toDart;
  } catch (_) {}
}
