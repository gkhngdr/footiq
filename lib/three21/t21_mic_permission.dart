import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ui.dart';
import '../screens/daily_reward_dialog.dart';
import 't21_voice.dart';

/// 3-2-1 mikrofon izni akışı.
///
/// İzin uygulama açılışında değil, oyuncu 3-2-1'e ilk girdiğinde istenir:
/// önce oyunun kendi penceresi neden gerektiğini anlatır, oyuncu "Mikrofonu Aç"
/// derse telefonun izin penceresi açılır. iPhone bu soruyu yalnızca bir kez
/// sorabildiği için bu tek şans boşa harcanmaz. Seçim hatırlanır.
const _prefKey = 't21_mic_choice';
const _choiceKeyboard = 'keyboard'; // oyuncu "Klavyeyle Oyna" dedi
const _choiceAsked = 'asked'; // telefonun izin penceresi gösterildi

const _system = MethodChannel('footiq/system');

/// Maça girmeden önce çağrılır. Ses modu kullanılacaksa true döner.
Future<bool> t21PrepareMic(BuildContext context) async {
  // Web'de tarayıcı izni mikrofona ilk basışta kendisi sorar; klavye varsayılan.
  if (kIsWeb) return false;

  final voice = T21Voice.instance;
  if (await voice.hasPermission) {
    return voice.ensureReady(); // izin zaten var: pencere açılmaz
  }

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}
  final choice = prefs?.getString(_prefKey);
  // Daha önce sorduk (reddetti) ya da klavyeyi seçti: tekrar rahatsız etme.
  // Mikrofon düğmesine basarsa yine denenir.
  if (choice == _choiceKeyboard || choice == _choiceAsked) return false;
  if (!context.mounted) return false;

  final wants = await showStageConfirm(
    context,
    title: '🎤 Sesle Oyna',
    message:
        'Futbolcu adını söyleyerek daha hızlı cevap ver.\n'
        'Bunun için mikrofon izni gerekiyor.',
    confirmLabel: 'Mikrofonu Aç',
    cancelLabel: 'Klavyeyle',
  );
  if (!wants) {
    await prefs?.setString(_prefKey, _choiceKeyboard);
    return false;
  }
  await prefs?.setString(_prefKey, _choiceAsked);
  return voice.ensureReady(); // telefonun izin penceresi burada açılır
}

/// Mikrofon düğmesine basıldı ama mikrofon kullanılamıyor.
Future<void> t21MicUnavailable(BuildContext context) async {
  if (kIsWeb) {
    toast(context, 'Tarayıcı mikrofona izin vermedi. Klavye ile yazabilirsin.');
    return;
  }
  final go = await showStageConfirm(
    context,
    title: 'Mikrofon Kapalı',
    message:
        'Mikrofon izni verilmemiş.\n'
        'Ayarlar\'dan FootIQ için mikrofonu açabilirsin.',
    confirmLabel: 'Ayarlar',
    cancelLabel: 'Klavyeyle',
  );
  if (go) await openAppSettings();
}

/// Telefonun Ayarlar'ında bu uygulamanın sayfasını açar.
Future<bool> openAppSettings() async {
  try {
    return await _system.invokeMethod<bool>('openAppSettings') ?? false;
  } catch (e) {
    debugPrint('ayarlar açılamadı: $e');
    return false;
  }
}
