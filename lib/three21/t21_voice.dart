import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Ses girişi: dokun-konuş (sessizlikte kendiliğinden biter) veya basılı tut-konuş.
/// Telefonun kendi konuşma tanımasını (Türkçe) kullanır; sonuçta en iyi tahmin
/// ve alternatifler döner.
class T21Voice {
  T21Voice._();
  static final T21Voice instance = T21Voice._();

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  String? _locale;

  SpeechRecognitionResult? _last;
  ValueChanged<List<String>>? _onFinal;
  bool _finished = true;

  /// Mikrofon/izin hazır mı? İlk çağrıda izin ister.
  Future<bool> ensureReady() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onError: (e) {
          debugPrint('ses hatası: $e');
          _finish();
        },
        onStatus: (s) {
          // Tanıma kendiliğinden durduysa (sessizlik/süre) sonucu bildir.
          if (s == SpeechToText.doneStatus ||
              s == SpeechToText.notListeningStatus) {
            _finish();
          }
        },
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

  bool get isListening => !_finished;

  List<String> _alternatives() {
    final r = _last;
    if (r == null) return const [];
    return {
      for (final a in r.alternates)
        if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords.trim(),
    }.take(5).toList();
  }

  /// Sonucu yalnızca bir kez bildirir.
  void _finish() {
    if (_finished) return;
    _finished = true;
    final cb = _onFinal;
    _onFinal = null;
    cb?.call(_alternatives());
  }

  /// Dinlemeye başlar. [onPartial] konuşurken ara sonucu, [onFinal] dinleme
  /// bittiğinde (sessizlik, süre, [stop] ya da hata) tahminleri verir.
  /// Mikrofon kullanılamıyorsa false döner.
  Future<bool> start({
    required ValueChanged<String> onPartial,
    required ValueChanged<List<String>> onFinal,
  }) async {
    if (!await ensureReady()) return false;
    _last = null;
    _onFinal = onFinal;
    _finished = false;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          _last = r;
          onPartial(r.recognizedWords);
          if (r.finalResult) _finish();
        },
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          partialResults: true,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(milliseconds: 1800),
          cancelOnError: true,
        ),
      );
    } catch (e) {
      debugPrint('dinleme başlatılamadı: $e');
      _finish();
      return false;
    }
    return true;
  }

  /// Dinlemeyi erken bitirir (ikinci dokunuş ya da basılı tutup bırakma).
  /// Sonuç [start]'taki onFinal ile gelir.
  Future<void> stop() async {
    if (_finished) return;
    try {
      await _stt.stop();
    } catch (_) {}
    // Son sonucun gelmesi için kısa süre tanı, sonra yine de bitir.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _finish();
  }

  Future<void> cancel() async {
    _onFinal = null;
    _finished = true;
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}
