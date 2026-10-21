# FootIQ — Futbol bilgi yarışması (Flutter)

Kullanıcıyla Türkçe konuş. Kullanıcı yazılımcı değil; adımları sade anlat.

## Durum (21.10.2026 — Nihai Sürüm)
- **Aşama 1 & Aşama 2 tamamlandı:**
  - Detaylı teknik günce ve güvenlik raporu için `GEMINI.md` dosyasına bakın.
  - 500 soruluk genişletilmiş soru bankası (`lib/data/questions.dart`), seviyeler arası soru tekrarı engelleme ve seviye içi kombinasyon çeşitliliği (`pickLevelQuestions`).
  - Supabase (`lib/core/cloud.dart` ve `supabase/schema.sql`) ile e-posta kayıt/giriş, bulut profil senkronizasyonu, Sezon Sıralaması (`leaderboard_dialog.dart`), Davet Et Kazan (`invite_dialog.dart`) ve eşzamanlı Online PVP (`pvp_rooms` + deterministik soru/şık `seed` senkronizasyonu + akıllı bot fallback) aktif.
  - Tüm onay ve ödül pencereleri `1080x1920` `Stage` tasarım diline (`showStageConfirm`, `_RewardedVideoPanel`) geçirildi; çalışmayan Faz 2 yer tutucuları temizlendi.

## Tasarım kaynağı
- Figma: https://www.figma.com/design/5zVuPhXbJwTIG9ENIYOmzQ/FootIQ (ekranlar 1080x1920).
- Kullanıcının Figma hesabı **Starter plan**; MCP çağrı limiti çabuk doluyor. Görseller zaten `assets/figma/` içine indirildi; Figma'yı yalnızca gerektiğinde çağır.
- Figma'da **olmayan**, mevcut tarza göre tasarlanmış ekranlar: soru ekranı, seviye/PVP sonuç, PVP rakip arama, ayarlar.
- `chapter2-4.png` görsellerinde seviye düğmeleri ve üst çubuk hazır çizili (Figma'da düz harita alınamadı). Harita ekranı bu görselleri tuvale birebir hizalar ve üstüne dokunma, kilit ve yıldız ekler. Bölüm 1 ise `bg_map.png` üzerine SVG katmanlı düğmelerle çizilir.

## Kod yapısı
- `lib/core/ui.dart`: `Stage` (1080x1920 sanal tuval, FittedBox ile ölçeklenir), `at(x,y,w,h)` Figma koordinatı kısayolu, fontlar (Londrina Solid'de ğ/ş/ı/İ yok → Exo2'ye fallback).
- `lib/core/game_state.dart`: Tüm oyuncu durumu (coin, kupa, enerji 6/20dk, yıldızlar, günlük ödül serisi), SharedPreferences ile saklanır.
- `lib/data/questions.dart`: Soru bankası. Her sorunun ilk seçeneği doğru cevaptır, oyunda karıştırılır.
- `lib/screens/`: Ekranlar. `preview.dart` yalnızca `--dart-define=PREVIEW=true` ile derlenince `?screen=main` gibi parametrelerle ekran açar (tasarım kontrolü için).
- Oyun kuralları: 5 soru, 15 sn, 5/4/3 doğru = 3/2/1 yıldız, <3 başarısız. PVP botla oynanır, kazanınca +15 kupa +5000 coin.

## Çalıştırma
- Flutter SDK: `C:\Users\PC\dev\flutter` (PATH'te). JDK 21: `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot`. Android SDK: `%LOCALAPPDATA%\Android\Sdk`.
- Web: `flutter run -d chrome`
- Android emülatörü: `emulator -avd FootIQ_Pixel -gpu host`, sonra `flutter run`.
  - `-gpu host` şart: NVIDIA sürücüsü (531.79) eski olduğu için emülatör aksi halde yazılımla çizip çok kasıyor. Kullanıcıya sürücü güncellemesi önerildi.
- Testler: `flutter test` (soru bankası doğrulaması + tam oyun akışı testleri). Değişiklikten sonra `flutter analyze` ve `flutter test` çalıştır.
- Windows'ta `sdkmanager` paket adlarını `/` ile ister (ör. `platforms/android-36`). `;` cmd tarafından bölünüyor.
- Windows masaüstü derlemesi kurulu değil (Developer Mode + VS C++ gerekli); gerek de yok.

## iPhone'da test (Mac yok)
- Hızlı: web sürümü (`flutter build web`) → aynı Wi-Fi'de yerel sunucu ya da Netlify/Firebase Hosting → iPhone Safari, "Ana Ekrana Ekle".
- Gerçek uygulama: Apple Developer hesabı (99 USD/yıl) + Codemagic bulut derleme (GitHub reposu gerekir) + TestFlight. Bundle ID: `com.footiq.footiq`.
- Kullanıcıya iki seçenek de anlatıldı; henüz bir tercih yapmadı.

## Bilinen küçük işler
- Ana ekrandaki hediye çubuğunda sarı dolgu, "3/7" yazısının okunurluğunu azaltıyor.
- "Davet Et Kazan", hesap girişleri ve sesler henüz çalışmıyor; bunlar "sonraki aşamada" uyarısı gösteriyor.
- Cam bulanıklık efektleri (BackdropFilter) en ağır kısım; gerekirse optimize edilebilir.
