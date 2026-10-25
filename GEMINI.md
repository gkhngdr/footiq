# FootIQ — Geliştirme Günlüğü ve Teknik Bellek (GEMINI.md)

Bu dosya, yapılan tüm mimari analizleri, kod değişikliklerini, Supabase yapılandırmalarını ve güvenlik denetimlerini hem geliştirici (kullanıcı) hem de diğer yapay zeka asistanları (`CLAUDE.md` ile birlikte) için anlaşılır ve güncel tutmak amacıyla oluşturulmuştur.

---

## 1. Mimari ve Görsel Yapı

- **Sanal Tuval (`lib/core/ui.dart`):** Tüm ekranlar ve pencereler Figma tasarım boyutu olan `1080x1920` sanal tuval (`Stage` ve `showStageDialog`) üzerinde `at(x, y, w, h)` koordinat yardımcısıyla konumlandırılır ve `FittedBox(fit: BoxFit.contain)` ile her ekran boyutuna otomatik ölçeklenir. `resizeToAvoidBottomInset: false` ve `MediaQuery.removeViewInsets` sayesinde sanal klavye açıldığında ekran küçülmez; `keyboardShift: true` olan ekranlarda (`LoginScreen`, `showStageDialog`) tuval akıcı şekilde yukarı kayar.
- **Performans İyileştirmeleri:**
  - `Stage` içindeki bulanık arka planlar (`ImageFiltered`), `TopHud` bileşeni ve `PvpModeScreen` kartları `RepaintBoundary` ile GPU üzerinde önbelleklendi.
  - `MainScreen` açılışında tüm PVP kart ve karakter görselleri (`pvp_card1..3.png`, `pvp_char1..3.png`) `precacheImage` ile belleğe alınarak `PvpModeScreen` geçişindeki 1 saniyelik gecikme sıfırlandı.
  - `TopHud` içindeki saniyelik sayaç yalnızca enerji `< 6` iken çalışacak şekilde optimize edildi (enerji doluyken gereksiz yeniden çizim yapılmaz).
  - `QuizScreen` içindeki 100ms'lik süre sayacı `ValueNotifier<double>` ile yalnızca `_TimerBar` bileşenine izole edildi; böylece saniyede 10 kez tüm soru ekranının yeniden çizilmesi önlendi.
- **Fontlar ve Tipografi (%100 Türkçe Karakter Destekli Montserrat & Outfit):**
  - Önceki `Fredoka` fontundaki `ş` ve `ç` harflerinin altındaki kopuk virgül benzeri çengel anomalisi ve orantısız yazı boyutları giderildi.
  - Spor ve mobil bilgi yarışması estetiğine tam uyan, Türkçe karakterleri kusursuz ve bitişik tipografik kancaya sahip **`Montserrat`** (ana başlıklar `ExtraBold 800`, soru metinleri `Bold 700`, butonlar ve sayaçlar `SemiBold 600`) ve **`Outfit`** fontlarına geçildi.
  - Eski Londrina dar fontuna göre kalibre edilmiş aşırı büyük (80, 110) yazı boyutları komponent sınırlarına göre dengelendi (başlıklar 56-60px, butonlar 36-40px, soru metinleri 36-42px).
- **Ses Sistemi (`lib/core/sound.dart`, `assets/sounds/`):**
  - `Sound` sınıfı (`click`, `correct`, `wrong`, `timeout`, `win`, `lose`, `tick`, `coin`, `trophy`, `matchFound`, `energyRefill`, `giftOpen`, `dailyReward`, `levelUp`) `GameState.instance.soundOn` durumuna bağlı çalışır.
  - Web'de HTML5 `Audio` (`lib/core/sound_web.dart`), Android'de `MainActivity.kt` içindeki düşük gecikmeli `SoundPool` (`MethodChannel('footiq/sound')`) üzerinden gerçek `.mp3` / `.wav` ses dosyalarını çalar (öncelik `.mp3`, yoksa `.wav`).
  - **Akustik Mastering & Doygunluk Dengesi:** Tüm sesler `-3.0 dB` tavan sınırlayıcı (True Peak) ile yeniden master edildi; hakem düdükleri ve uyarı seslerindeki kulak tırmalayıcı patlama ve dijital kırpılma (clipping) 12kHz yumuşak filtre ve ses seviyesi düşürme ile giderildi; kısık kalan altın para (`coin`) ve enerji dolum (`energy_refill`) sesleri duyulabilir seviyeye yükseltildi. Web (`0.55`) ve Android (`0.70f`) oynatıcı ses çıkışları dengelendi.
- **Durum Yönetimi (`lib/core/game_state.dart`):** `GameState.instance` (`ChangeNotifier` + `WidgetsBindingObserver` singleton) tüm oyuncu verilerini (`playerId`, `playerName`, `trophies`, `coins`, `energy`, `_stars`, `_dailyStreak`, `_giftProgress`, `soundOn`) yönetir, `SharedPreferences` (`footiq_state_v1`) ile cihazda saklar, hesaplı oyuncularda 3 sn gecikmeli (debounced) olarak Supabase'e yazar ve uygulama arka plana alındığında (`paused`/`inactive`/`detached`) bekleyen bulut kaydını anında gönderir.

---

## 2. Tamamlanan Özellikler ve Deneyim Tasarımı (UX) İyileştirmeleri

1. **Soru Bankası, Kademeli Zorluk (`1..10`) ve Seviye Çeşitliliği (`lib/data/questions.dart`):**
   - Soru havuzu **500 benzersiz futbol sorusuna** çıkarıldı ve Bölüm 1'deki aşırı basit sorular gerçek futbol kültürü sorularıyla yenilendi:
     - Bölüm 1 (Temel, Zorluk `1..4`): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - Bölüm 2 (Ligler ve Kulüpler, Zorluk `3..6`): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - Bölüm 3 (Tarih, Zorluk `5..8`): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - Bölüm 4 (Uzman, Zorluk `7..10`): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - PVP — Ben Kimim? (`4..8`): 60 soru
     - PVP — Champions League (`4..8`): 60 soru
     - PVP — Hangi Takım? (`4..8`): 60 soru
   - Her `Question` nesnesine açık `difficulty` (`1..10`) ve `difficultyLabel` (`Kolay`, `Orta`, `Zor`, `Uzman`, `Efsane`) alanı eklendi.
   - `pickLevelQuestions(chapter, level, 5, rng)` hem bölümler/seviyeler ilerledikçe artan zorluk dilimlerini seçer hem de her 5 soruluk tur içinde soruları **kolaydan zora doğru kademeli** sıralar. Soru ekranında (`QuizScreen`) her sorunun zorluk derecesi (`Zorluk: Orta (4/10)`) canlı gösterilir.

2. **Online Eşzamanlı (Senkron) PVP ve Akıllı Bot Fallback (`lib/screens/quiz_screen.dart`, `lib/core/cloud.dart`, `supabase/schema.sql`):**
   - `public.pvp_rooms` tablosu ve `join_or_create_pvp`, `poll_pvp_room`, `update_pvp_progress` RPC fonksiyonları eklendi.
   - Aynı kategoride PVP arayan iki oyuncu eşleştiğinde aynı `seed` değerini paylaşır. `pickSeededPvpQuestions` ve deterministik şık karıştırma (`Random(seed * 31 + index + 7)`) sayesinde **her iki oyuncunun ekranında birebir aynı 5 soru ve birebir aynı A/B/C/D şık sırası eşzamanlı gösterilir**.
   - Üst skor tablosunda rakibin gerçek kullanıcı adı, anlık skoru ve mevcut soruyu cevaplayıp cevaplamadığı (`cevapladı ✓`) canlı güncellenir.
   - Eşleşme süresince çevrimiçi başka bir insan oyuncu bulunamazsa (veya çevrimdışı modda) kesintisiz olarak gerçekçi bot rakiple aynı akış başlatılır.

3. **Tasarım Diline Uygun Pencereler ve UX Cilası:**
   - **Misafir ve Hesap Oturumu İzolasyonu (`GameState.loginAsGuest`, `LoadingScreen`):** Hesaptan çıkış yapıldığında veya misafir olarak devam edildiğinde önceki hesabın verilerinin (isim, kupa, coin, yıldızlar) misafire sızması engellendi; `Cloud.signOut()` ile arka plan Supabase oturumu sonlandırıldı ve `LoadingScreen` içindeki asenkron yarış durumu (`race condition`) çözülerek hesaplı kullanıcıların istem dışı giriş ekranına düşmesi ve misafir modunun hesap verisiyle açılması giderildi.
   - Uygulama içindeki tüm standart Flutter `AlertDialog` pencereleri kaldırıldı. Onay pencereleri (`showStageConfirm` — oyundan çıkış, hesap çıkışı/silme) ve ödüllü video/bonus ekranı (`_RewardedVideoPanel`) tamamen `1080x1920` `Stage` + `daily_panel.svg` + `GlassBox` tasarım diline geçirildi.
   - **Ayarlar Menüsü Sadeleştirmesi (`SettingsDialog`):** Gereksiz ve kafa karıştırıcı olan "İlerlemeyi Sıfırla" butonu kaldırıldı; hesap değiştirme butonu doğrudan ve sade bir biçimde "Çıkış Yap" olarak adlandırıldı; buton aralıkları ve dikey yerleşim ferahlatıldı.
   - `LoginScreen` üzerindeki çalışmayan ("yakında aktif olacak" uyarısı veren) Faz 2 sosyal giriş ikonları kaldırıldı; Giriş Yap / Kayıt Ol düğmesi ortalandı, klavye `TextInputAction` / `onSubmitted` akışı ve `goStage` geçiş animasyonu eklendi.
   - `MainScreen` dikey yerleşimi dengelendi (`_SeasonBar` `y=825`, oyun kartları `y=1110`, alt özet çubuğu `y=1615`) ve "Oynadıkça kazan" hediye çubuğunda (`3/7`) sarı dolgu üstündeki metin okunurluğu yarı saydam koyu kapsül ve güçlendirilmiş kontur gölgesiyle artırıldı.
   - `QuizScreen` içinde hem eşleşme (`_matching`) hem soru ekranı `PopScope` ve `CloseBtn` ile korundu; sorular arası geçişe `AnimatedSwitcher` eklendi; oyuncunun kupası `0` iken PVP kaybettiğinde sonuç ekranında `-5` yerine gerçek değişim olan `+0` gösterilmesi sağlandı (`actualTrophies = _state.trophies - beforeTrophies`).
   - `InviteDialog` ("Davet Et Kazan") penceresinde arkadaş davet kodu giriş alanı yüksek kontrastlı koyu kutu, altın çerçeve ve "Yapıştır" düğmesiyle belirginleştirildi; hem çevrimiçi Supabase (`redeem_invite`) hem de çevrimdışı/misafir (`redeemGuestInvite`) modda `+500 Coin` ödülü çalışır hale getirildi.
   - **Sezon Sıralaması (`leaderboard_dialog.dart`) ve Rank:** Üstte Sezon Ödül rozetleri (`🥇 1. +10.000`, `🥈 2. +5.000`, `🥉 3. +2.500`), ilk 3 için madalya rozetleri (`🥇 #1`, `🥈 #2`, `🥉 #3`), sezon geri sayımı ve altta sabit `"Senin sıran: #..."` kartı ile zenginleştirildi.
   - **Dinamik Enerji Barı (`TopHud` — `lib/widgets/common.dart`):** Önceden sabit `Positioned` sıkı kısıtlaması (tight constraint) nedeniyle enerji düştüğünde azalamayan ve sürekli %100 dolu kalan enerji çubuğu, `(306.0 * energy / maxEnergy)` dinamik genişliği ve `ClipRRect` + `OverflowBox` ile düzeltildi; enerji azaldıkça bar akıcı şekilde sola doğru çekilir, 0 enerjide tamamen boşalır.

---

## 3. White-Hat Güvenlik Denetimi Özeti

- **Kimlik Doğrulama & Kayıt (`supabase/schema.sql`):**
  - `on_auth_user_autoconfirm` trigger'ı ile e-posta/şifre kaydı olan kullanıcılar anında onaylanır ve oturum açar.
  - `profiles` tablosunda RLS açık; `anon` rolünün erişimi tamamen kapatıldı (`401 Unauthorized`).
- **Sütun ve Satır Güvenliği:**
  - Kullanıcı yalnızca kendi satırını (`auth.uid() = id`) ekleyebilir ve güncelleyebilir.
  - `invite_code` ve `invited_by` sütunları `SELECT` ve `UPDATE` yetkilerinden çıkarıldı; başkalarının davet kodları taranamaz (`my_invite_code()` yalnızca çağıranın kendi kodunu döndürür).
- **Veri Doğrulama ve Hız Sınırı:**
  - `profiles` üzerinde negatif coin/kupa ve aşırı değerler `CHECK` kısıtlarıyla engellendi.
  - `limit_profile_growth` trigger'ı (`BEFORE INSERT OR UPDATE`) ile ilk kayıtta yüksek başlangıç değerleri (`trophies > 500`, `coins > 50000`) ve güncellemelerde kupa/coin artış hızı zamana bağlı sınırlandı (`updated_at` sunucu tarafından yazılır, geri tarihlendirme engellendi).
  - `pvp_rooms` tablosuna doğrudan tablo erişimi kapatıldı; yalnızca sınır doğrulaması (`score between 0 and 2000`, `step between 0 and 5`) yapan `security definer` RPC fonksiyonları üzerinden erişilebilir.
  - `questions` (uzaktan soru bankası) tablosu RLS ile salt okunur (`SELECT`) olarak sınırlandı; istemciden soru ekleme/değiştirme/silme yetkileri tamamen kapatıldı.
  - `AndroidManifest.xml` içerisinde `INTERNET` izni eklendi, `allowBackup="false"` ve `usesCleartextTraffic="false"` yapılandırıldı.
  - `.gitignore` içerisine `.env`, `*.key`, `*.jks`, `*.keystore`, `key.properties` kuralları eklenerek gizli anahtar sızıntıları engellendi.
