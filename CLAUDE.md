# FootIQ — Futbol bilgi yarışması (Flutter)

Kullanıcıyla Türkçe konuş. Kullanıcı yazılımcı değil; adımları sade anlat.
Hedef: hataları gidermek, yeni özellikler eklemek ve uygulamayı mağazalarda yayınlamak.

> Bu dosya projenin tek bilgi kaynağıdır. Önceki `CLAUDE.md` ve `GEMINI.md` (04.11.2026'da) burada birleştirildi.
> Eski hâlleri git geçmişinde duruyor.

## Durum (04.11.2026)
- Çalışan özellikler: 500 soruluk banka, bölüm haritası (4 bölüm), Supabase ile e-posta kayıt/giriş, misafir modu,
  bulut profil kaydı, Sezon Sıralaması, Davet Et Kazan, online PVP (bot yedekli), günlük ödül, enerji, ses.
- Henüz yayınlanmadı. Sürüm: `pubspec.yaml` → `1.0.0+1`.

### Bilinen açık konular (yayından önce)
- **iOS'ta oyun sesi yok:** `lib/core/sound_stub.dart` `footiq/sound` kanalını çağırıyor ama yalnızca Android
  (`MainActivity.kt`) bu kanalı karşılıyor. iOS tarafında (`ios/Runner/AppDelegate.swift`) karşılığı yok; sistem "klik" sesine düşüyor.
- Derleme hatları üç ayrı yerde: `.github/workflows/build.yml`, `.github/workflows/ios-ipa.yml`, `codemagic.yaml`. Sadeleştirilebilir.
- Yayın için eksikler: uygulama simgesi/adı kontrolü, Android imzalama anahtarı, gizlilik politikası, mağaza görselleri.

## Tasarım kaynağı
- Figma: https://www.figma.com/design/5zVuPhXbJwTIG9ENIYOmzQ/FootIQ (ekranlar 1080x1920).
- Kullanıcının Figma hesabı **Starter plan**; MCP çağrı limiti çabuk doluyor. Görseller zaten `assets/figma/` içinde; Figma'yı yalnızca gerektiğinde çağır.
- Figma'da **olmayan**, mevcut tarza göre tasarlanmış ekranlar: soru ekranı, seviye/PVP sonuç, PVP rakip arama, ayarlar.
- `chapter2-4.webp` görsellerinde seviye düğmeleri ve üst çubuk hazır çizili. Harita ekranı bu görselleri tuvale birebir hizalar,
  üstüne dokunma, kilit ve yıldız ekler. Bölüm 1 ise `bg_map.webp` üzerine SVG katmanlı düğmelerle çizilir.

## Kod yapısı
- `lib/core/ui.dart`: `Stage` (1080x1920 sanal tuval, `FittedBox(fit: BoxFit.contain)` ile ölçeklenir), `at(x,y,w,h)` Figma koordinatı kısayolu,
  `showStageDialog` / `showStageConfirm` (tüm pencereler bu tasarım dilinde; standart `AlertDialog` kullanılmaz).
  - Klavye: `resizeToAvoidBottomInset: false` + `MediaQuery.removeViewInsets`; `keyboardShift: true` olan ekranlar (`LoginScreen`, `showStageDialog`)
    küçülmeden yukarı kayar. `Transform.translate` sabit tutulur (koşullu yeniden yerleştirme odak kaybına yol açıyordu, yapma).
  - Arka plan dokunma algılayıcısı `opaque` ve en altta; tam ekran `translucent` `GestureDetector` ekleme (alanların tıklamasını çalıyordu).
- **Fontlar:** Başlık/metin/form stilleri `Montserrat` (yedek: `Outfit`, `Rubik`). Uygulama varsayılanı `main.dart` içinde `Exo2`.
  `londrina()` / `poppins()` yalnızca eski isimli yardımcılar; ikisi de Montserrat çizer.
  Ölçüler: başlıklar 56-60px, butonlar 36-40px, soru metinleri 36-42px. (Fredoka'daki ş/ç sorunu nedeniyle Montserrat'a geçildi.)
- `lib/core/sound.dart`: 14 ses efekti (`assets/sounds/`, ElevenLabs ile üretildi, sessizliği kırpılmış ve -3.5 dB tavanlı).
  Web: `sound_web.dart` açılışta ses havuzu kurar (gecikmesiz). Android: `MainActivity.kt` `SoundPool` (`MethodChannel('footiq/sound')`).
  `.mp3` öncelikli, `.wav` yedek. Ses, dokunmanın başında (`onTapDown`) çalar. `GameState.instance.soundOn` ile kapatılır.
- `lib/core/game_state.dart`: `GameState.instance` (`ChangeNotifier` + `WidgetsBindingObserver`). Coin, kupa, enerji (6 adet, 20 dk'da bir dolar),
  yıldızlar, günlük ödül serisi, hediye ilerlemesi. `SharedPreferences` (`footiq_state_v1`) ile saklanır; hesaplı oyuncuda 3 sn gecikmeli Supabase'e yazılır,
  uygulama arka plana alınınca bekleyen kayıt hemen gönderilir. Misafir girişi önceki hesabın verisini taşımaz (`loginAsGuest`).
- `lib/core/cloud.dart`: Supabase istemcisi (adres ve anahtar dosyada). Şema ve güvenlik kuralları: `supabase/schema.sql`.
- `lib/data/questions.dart`: 500 soru, `difficulty: 1..10`, `difficultyLabel` (Kolay/Orta/Zor/Uzman/Efsane). Her sorunun **ilk seçeneği doğru cevaptır**,
  oyunda karıştırılır. Dağılım: Bölüm 1-4 her biri 80 soru (seviye başına 8; zorluk 1-4, 3-6, 5-8, 7-10), PVP kategorileri
  (Ben Kimim?, Champions League, Hangi Takım?) her biri 60 soru. `pickLevelQuestions` seviyeler arası tekrarı önler ve turu kolaydan zora sıralar.
- **Görseller:** Büyük görseller `.webp` (24 MB → 2 MB). Yeni büyük görsel eklerken `cwebp -q 86 -alpha_q 100` ile çevir;
  1 MB'lık SVG gibi ağır vektörleri PNG'ye çevir (flutter_svg'de yavaş ve filtreleri desteklemiyor).
- **Web performansı:** Web'de (telefon tarayıcısı) her karede yeniden hesaplanan bulanıklıklar kapalı: `GlassBox` blur atlanır,
  `GlowFrame` gölgeyle çizilir, pencere perdesi düz koyu renk. Stage arka plan bulanıklığı tüm platformlarda düşük çözünürlüklü görselle yapılır.
  Web'de `TextField.onTapOutside` kullanma (telefonda alana dokunmayı "dışarı" sayıp klavyeyi kapatıyordu).
- **Şifremi unuttum** (`forgot_password_dialog.dart`): iki yol da çalışır.
  1) Kod: e-postadaki kod → `verifyOTP(recovery)` → `updateUser`. Şablonda `{{ .Token }}` gerekir; şablon ancak özel SMTP ile düzenlenebiliyor.
  2) Bağlantı (web): `resetPasswordForEmail(redirectTo: oyunun adresi)` → bağlantı `?code=` ile oyunu açar → `Cloud.awaitRecoverySession`
     → ana ekranda `showSetNewPassword`. PKCE yüzünden bağlantı, isteğin yapıldığı tarayıcıda açılmalı. Telefon uygulaması için derin bağlantı yok.
  Supabase varsayılan e-posta servisi yalnızca proje ekibindeki adreslere ve saatte çok az e-posta gönderir; yayından önce özel SMTP şart.
  Supabase URL ayarları: Site URL `https://gkhngdr.github.io/footiq/` olmalı (eskiden `localhost:3000` idi), Redirect URLs'te oyun adresi.
- **Arkadaşınla Oyna** (`friend_room_screen.dart`, `supabase/friend_rooms.sql`): 4 haneli kodlu özel PVP odası (FQ-1234),
  paylaşım `share_plus` + web bağlantısı `?oda=1234`. Dostluk maçı enerji harcamaz, kupa vermez (iki hesapla kupa kasılmasın), +500 coin.
  Rastgele eşleşme özel odalara girmez. "Davet Et Kazan" (davet kodu ödülü) bu ekranın altına taşındı.
- **3-2-1 modu (yapım aşamasında):** veri `tool/three21/` (Wikidata → `out/` → Supabase `t21_*`), sunucu fonksiyonları `supabase/three21.sql`.
  Cevap kontrolü sunucuda (`t21_judge`, ses benzerliği ≥0,85); bir maçta kulüp tekrarı yok (`t21_pick_pairs`); doğru cevap listesi istemciye gitmez.
  İsim kuralları `names.py` ile SQL'de birebir aynı olmalı.
- `lib/screens/`: Ekranlar. `preview.dart` yalnızca `--dart-define=PREVIEW=true` ile derlenince `?screen=main` gibi parametrelerle ekran açar.
- `lib/widgets/common.dart`: `TopHud` (enerji çubuğu genişliği enerjiye göre değişir), `Tap`, `CloseBtn` vb.

## Oyun kuralları
- Seviye: 5 soru, soru başına 15 sn. 5/4/3 doğru = 3/2/1 yıldız, 3'ten az doğru = başarısız.
- PVP: gerçek oyuncu ya da bot. İki oyuncu aynı `seed` ile aynı soruları ve aynı şık sırasını görür (`pickSeededPvpQuestions`,
  `Random(seed * 31 + index + 7)`). Kazanınca +15 kupa +5000 coin; kupa 0'ın altına düşmez.
- Supabase tarafı: `pvp_rooms` + `join_or_create_pvp`, `poll_pvp_room`, `update_pvp_progress` RPC'leri.

## Güvenlik (supabase/schema.sql)
- Kayıt olan e-posta kullanıcıları otomatik onaylanır (`on_auth_user_autoconfirm`).
- `profiles`: RLS açık, `anon` erişimi kapalı, kullanıcı yalnızca kendi satırını yazar. `invite_code` / `invited_by` dışarıdan okunamaz (`my_invite_code()`).
- Negatif ya da aşırı coin/kupa `CHECK` ile engelli; `limit_profile_growth` artış hızını sınırlar (`updated_at` sunucuda yazılır).
- `pvp_rooms` yalnızca sınır kontrollü RPC'lerle; `questions` tablosu salt okunur.
- Android: `INTERNET` izni, `allowBackup="false"`, `usesCleartextTraffic="false"`. `.gitignore` gizli anahtar dosyalarını dışlar.

## Çalıştırma (Mac)
- Proje yolu: `/Users/gg/Projeler/footiq`. Yolda Türkçe karakter OLMAMALI (`flutter analyze` aksi halde `FormatException` ile çöküyor).
- Flutter SDK: Homebrew cask (`/opt/homebrew/bin/flutter`). Güncelleme: `brew upgrade --cask flutter`.
- Web: `flutter run -d chrome`
- iOS: Xcode kurulu, lisans kabul edildi. Simülatör için iOS platformu henüz indirilmedi (`xcodebuild -downloadPlatform iOS`). CocoaPods gerekirse `brew install cocoapods`. Bundle ID: `com.footiq.footiq`.
- Android: Android Studio + JDK kurulu değil; APK GitHub Actions ile üretiliyor.
- Telefon boyutunda ekran görüntüsü: `flutter build web --dart-define=PREVIEW=true` + yerel sunucu + Playwright (sistem Chrome'u).
- Değişiklikten sonra mutlaka `flutter analyze` ve `flutter test` çalıştır (soru bankası doğrulaması + tam oyun akışı testleri).

## Claude çalışma düzeni
- Varsayılan: tek ana oturum. Yardımcı agent yalnızca paralel/bağımsız iş veya taze göz gerekince; her zaman göreve yeten en ucuz model (`haiku` mekanik işler, `sonnet` içerik/doğrulama).
- Hook'lar (`.claude/settings.json`): `.dart` düzenlenince `dart format`; tur biterken Dart dosyası değiştiyse `flutter analyze` (hata varsa iş bitmez).
- MCP: `dart mcp-server` (çalışan uygulamanın hataları, widget ağacı, hot reload).

## GitHub ve derleme
- Depo: `gkhngdr/footiq`. `main`'e her push:
  - `build.yml` → Android APK (Actions artifact)
  - `ios-ipa.yml` → web sürümü (gh-pages, `/footiq/`) ve imzasız iOS derlemesi
- `codemagic.yaml` → Sideloadly/AltStore için imzasız `.ipa` (Codemagic'te elle).
- Commit/push yalnızca kullanıcı isteyince.
