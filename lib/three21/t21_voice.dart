import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Ses girişi: dokun-konuş (sessizlikte kendiliğinden biter) veya basılı tut-konuş.
/// Telefonun / tarayıcının kendi konuşma tanımasını (Türkçe) kullanır; sonuçta
/// en iyi tahmin ve alternatifler döner.
class T21Voice {
  T21Voice._();
  static final T21Voice instance = T21Voice._();

  /// Konuşmaya başlamadan önce tanınan bekleme. Mikrofonun açılması ve
  /// oyuncunun düşünmesi zaman alır; kısa tutulursa (eskiden 1,8 sn) tanıma
  /// kişi daha konuşmadan kapanıyordu.
  static const _firstPause = Duration(seconds: 4);

  /// İlk kelime duyulduktan sonra bu kadar sessizlik olunca biter.
  static const _afterSpeechPause = Duration(milliseconds: 1500);

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  Future<bool>? _initializing;
  String? _locale;

  SpeechRecognitionResult? _last;
  ValueChanged<List<String>>? _onFinal;
  bool _finished = true;
  bool _heardSpeech = false;
  Timer? _safety;

  /// Mikrofon/izin hazır mı? İlk çağrıda izin ister. Ekran açılırken bir kez
  /// çağrılır ki ilk dokunuşta izin penceresi beklenmesin.
  Future<bool> ensureReady() {
    if (_ready) return Future.value(true);
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  Future<bool> _init() async {
    try {
      _ready = await _stt.initialize(
        onError: (e) {
          debugPrint('ses hatası: ${e.errorMsg} (kalıcı: ${e.permanent})');
          // Geçici hatalarda (ör. "no-speech") elde ne varsa onu bildir.
          _finish();
        },
        onStatus: (s) {
          // Yalnızca "bitti" durumunda bitir. "notListening" sonuçtan ÖNCE
          // gelebiliyor (Android, iOS); o anda bitirmek son tahmini kaybettiriyordu.
          if (s == SpeechToText.doneStatus) _finish();
        },
      );
      if (_ready) _locale = await _pickLocale();
    } catch (e) {
      debugPrint('ses başlatılamadı: $e');
      _ready = false;
    }
    return _ready;
  }

  Future<String> _pickLocale() async {
    // Web Konuşma API'si dil kodunu "tr-TR" biçiminde ister; "tr_TR" yazınca
    // tarayıcı dili tanımıyor ya da İngilizce dinliyordu.
    if (kIsWeb) return 'tr-TR';
    try {
      final locales = await _stt.locales();
      final tr = locales
          .where((l) => l.localeId.toLowerCase().startsWith('tr'))
          .firstOrNull;
      if (tr != null) return tr.localeId;
    } catch (_) {}
    return defaultTargetPlatform == TargetPlatform.iOS ? 'tr-TR' : 'tr_TR';
  }

  bool get isListening => !_finished;

  /// İzin verilmiş mi? Soru sormadan bakar (izin penceresi açmaz).
  Future<bool> get hasPermission async {
    if (_ready) return true;
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return false;
    }
  }

  List<String> _alternatives() {
    final r = _last;
    if (r == null) return const [];
    final out = <String>{};
    for (final a in r.alternates) {
      final raw = a.recognizedWords.trim();
      if (raw.isEmpty) continue;
      final clean = cleanTranscript(raw);
      if (clean.isNotEmpty) out.add(clean);
      out.add(raw);
    }
    return out.take(6).toList();
  }

  /// Telefon tarayıcısındaki tanıma bazen aynı sözü tekrar ekliyor
  /// ("Messi Messi", "Arda Turan Arda Turan"). Tekrarları ayıklar.
  @visibleForTesting
  static String cleanTranscript(String s) {
    var words = s
        .replaceAll(RegExp(r'[.,!?;:"]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    // Art arda aynı kelime ("Messi Messi") → tek.
    final dedup = <String>[];
    for (final w in words) {
      if (dedup.isEmpty || dedup.last.toLowerCase() != w.toLowerCase()) {
        dedup.add(w);
      }
    }
    words = dedup;
    // Baştaki kelime grubu aynen tekrar ediyorsa ("Arda Turan Arda Turan") → bir kez.
    for (var n = words.length ~/ 2; n >= 1; n--) {
      if (words.length % n != 0) continue;
      final head = words.sublist(0, n).join(' ').toLowerCase();
      var repeats = true;
      for (var i = n; i < words.length; i += n) {
        if (words.sublist(i, i + n).join(' ').toLowerCase() != head) {
          repeats = false;
          break;
        }
      }
      if (repeats) {
        words = words.sublist(0, n);
        break;
      }
    }
    return words.join(' ');
  }

  /// Sonucu yalnızca bir kez bildirir.
  void _finish() {
    if (_finished) return;
    _finished = true;
    _safety?.cancel();
    _safety = null;
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
    // Önceki oturum kapanmadıysa kapat; aksi halde "meşgul" hatası geliyor.
    if (_stt.isListening) {
      try {
        await _stt.cancel();
      } catch (_) {}
    }
    _last = null;
    _heardSpeech = false;
    _onFinal = onFinal;
    _finished = false;
    // Hiçbir durum bildirimi gelmezse bile en geç 12 sn'de bitir.
    _safety?.cancel();
    _safety = Timer(const Duration(seconds: 12), stop);
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          if (_finished) return;
          _last = r;
          onPartial(r.recognizedWords);
          if (!_heardSpeech && r.recognizedWords.trim().isNotEmpty) {
            _heardSpeech = true;
            // Konuşma başladı: artık kısa sessizlik yeterli.
            try {
              _stt.changePauseFor(_afterSpeechPause);
            } catch (_) {}
          }
          if (r.finalResult) _finish();
        },
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          partialResults: true,
          listenFor: const Duration(seconds: 10),
          pauseFor: _firstPause,
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
    // Son sonucun gelmesini bekle ("done" gelince zaten biter); gelmezse
    // eldeki son tahminle bitir.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _finish();
  }

  Future<void> cancel() async {
    _onFinal = null;
    _finished = true;
    _safety?.cancel();
    _safety = null;
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}
