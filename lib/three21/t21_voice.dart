import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Basılı tut-konuş ses girişi. Telefonun kendi konuşma tanımasını (Türkçe)
/// kullanır; sonuçta en iyi tahmin ve alternatifler döner.
class T21Voice {
  T21Voice._();
  static final T21Voice instance = T21Voice._();

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  String? _locale;

  /// Mikrofon/izin hazır mı? İlk çağrıda izin ister.
  Future<bool> ensureReady() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onError: (e) => debugPrint('ses hatası: $e'),
      );
      if (_ready) {
        final locales = await _stt.locales();
        _locale =
            locales
                .where((l) => l.localeId.toLowerCase().startsWith('tr'))
                .firstOrNull
                ?.localeId ??
            'tr_TR';
      }
    } catch (e) {
      debugPrint('ses başlatılamadı: $e');
      _ready = false;
    }
    return _ready;
  }

  bool get isListening => _stt.isListening;

  /// Dinlemeye başlar; [onPartial] konuşurken ara sonucu verir.
  Future<void> start({required ValueChanged<String> onPartial}) async {
    if (!await ensureReady()) return;
    _last = null;
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        _last = r;
        onPartial(r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        localeId: _locale,
        partialResults: true,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
      ),
    );
  }

  SpeechRecognitionResult? _last;

  /// Dinlemeyi bitirir; tahminleri (en iyisi önce) döndürür.
  Future<List<String>> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    // Son sonucun gelmesi için çok kısa bekle.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final r = _last;
    if (r == null) return const [];
    return {
      for (final a in r.alternates)
        if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords.trim(),
    }.take(5).toList();
  }

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}
