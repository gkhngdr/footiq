# FootIQ — Geliştirme Günlüğü ve Teknik Bellek (GEMINI.md)

Bu dosya, yapılan tüm mimari analizleri, kod değişikliklerini, Supabase yapılandırmalarını ve güvenlik denetimlerini hem geliştirici (kullanıcı) hem de diğer yapay zeka asistanları (`CLAUDE.md` ile birlikte) için anlaşılır ve güncel tutmak amacıyla oluşturulmuştur.

---

## 1. Mimari ve Görsel Yapı

- **Sanal Tuval (`lib/core/ui.dart`):** Tüm ekranlar ve pencereler Figma tasarım boyutu olan `1080x1920` sanal tuval (`Stage` ve `showStageDialog`) üzerinde `at(x, y, w, h)` koordinat yardımcısıyla konumlandırılır ve `FittedBox(fit: BoxFit.contain)` ile her ekran boyutuna otomatik ölçeklenir.
- **Performans İyileştirmeleri:**
  - `Stage` içindeki bulanık arka planlar (`ImageFiltered`) ve `TopHud` bileşeni `RepaintBoundary` ile GPU üzerinde önbelleklendi.
  - `TopHud` içindeki saniyelik sayaç yalnızca enerji `< 6` iken çalışacak şekilde optimize edildi (enerji doluyken gereksiz yeniden çizim yapılmaz).
  - `QuizScreen` içindeki 100ms'lik süre sayacı `ValueNotifier<double>` ile yalnızca `_TimerBar` bileşenine izole edildi; böylece saniyede 10 kez tüm soru ekranının yeniden çizilmesi önlendi.
- **Fontlar:** `LondrinaSolid` (ana oyun başlıkları, Türkçe `ğ, ş, ı, İ` karakterleri için `Exo2` yedekli), `Exo2` (soru metinleri, açıklamalar), `Poppins` (giriş ekranı).
- **Durum Yönetimi (`lib/core/game_state.dart`):** `GameState.instance` (`ChangeNotifier` singleton) tüm oyuncu verilerini (`playerId`, `playerName`, `trophies`, `coins`, `energy`, `_stars`, `_dailyStreak`, `_giftProgress`, `soundOn`) yönetir, `SharedPreferences` (`footiq_state_v1`) ile cihazda saklar ve hesaplı oyuncularda 3 sn gecikmeli (debounced) olarak Supabase'e yazar.

---

## 2. Tamamlanan Özellikler ve Deneyim Tasarımı (UX) İyileştirmeleri

1. **Soru Bankası ve Seviye Çeşitliliği (`lib/data/questions.dart`):**
   - Soru havuzu **500 benzersiz futbol sorusuna** çıkarıldı:
     - Bölüm 1 (Temel): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - Bölüm 2 (Ligler ve Kulüpler): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - Bölüm 3 (Tarih): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - Bölüm 4 (Uzman): 80 soru (seviye başına 8 soruluk ayrık alt havuz)
     - PVP — Ben Kimim?: 60 soru
     - PVP — Champions League: 60 soru
     - PVP — Hangi Takım?: 60 soru
   - `pickLevelQuestions(chapter, level, 5, rng)` ile aynı bölümdeki 1..10 seviyelerinin her biri kendine ait 8 soruluk ayrık soru dilimini kullanır; böylece hem oyuncu bölümleri ilerlerken aynı soruları tekrar görmez hem de aynı seviyeyi tekrar oynadığında o seviyenin 8'lik havuzundan farklı soru kombinasyonları gelir.

2. **Online Eşzamanlı (Senkron) PVP ve Akıllı Bot Fallback (`lib/screens/quiz_screen.dart`, `lib/core/cloud.dart`, `supabase/schema.sql`):**
   - `public.pvp_rooms` tablosu ve `join_or_create_pvp`, `poll_pvp_room`, `update_pvp_progress` RPC fonksiyonları eklendi.
   - Aynı kategoride PVP arayan iki oyuncu eşleştiğinde aynı `seed` değerini paylaşır. `pickSeededPvpQuestions` ve deterministik şık karıştırma (`Random(seed * 31 + index + 7)`) sayesinde **her iki oyuncunun ekranında birebir aynı 5 soru ve birebir aynı A/B/C/D şık sırası eşzamanlı gösterilir**.
   - Üst skor tablosunda rakibin gerçek kullanıcı adı, anlık skoru ve mevcut soruyu cevaplayıp cevaplamadığı (`cevapladı`) canlı güncellenir.
   - Eşleşme süresince çevrimiçi başka bir insan oyuncu bulunamazsa (veya çevrimdışı modda) kesintisiz olarak gerçekçi bot rakiple aynı akış başlatılır.

3. **Tasarım Diline Uygun Pencereler ve Faz 2 Sadeleştirmesi:**
   - Uygulama içindeki tüm standart Flutter `AlertDialog` pencereleri kaldırıldı. Onay pencereleri (`showStageConfirm` — oyundan çıkış, ilerleme sıfırlama, hesap çıkışı/silme) ve ödüllü video/bonus ekranı (`_RewardedVideoPanel`) tamamen `1080x1920` `Stage` + `daily_panel.svg` + `GlassBox` tasarım diline geçirildi.
   - `LoginScreen` üzerindeki çalışmayan ("yakında aktif olacak" uyarısı veren) Faz 2 sosyal giriş ikonları kaldırıldı; Giriş Yap / Kayıt Ol düğmesi ortalandı.
   - `ChapterSelectScreen` altındaki yarım `...` kartları kaldırıldı; yerine her bölüm kartı üzerinde kazanılan yıldız (`★ X / 30`) ve altta `Toplam Yıldız: X / 120` ilerleme göstergesi eklendi.
   - `ResultDialog` içinde bir bölümün 10. seviyesi geçildiğinde doğrudan **Sonraki Bölüm**'e geçiş düğmesi eklendi.
   - `SettingsDialog` içinde oyuncunun adını (`playerName`) doğrudan düzenleyebilmesi sağlandı.
   - **Sezon Sıralaması (`leaderboard_dialog.dart`) ve Rank:** Hem çevrimiçi Supabase oyuncularını hem de Sezon Ligi tablosunu birleştirerek misafir ve hesaplı tüm oyuncular için her zaman dolu bir sıralama tablosu ve canlı `Rank: #...` göstergesi sunar.

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
  - `limit_profile_growth` trigger'ı ile kupa ve coin artış hızı zamana bağlı sınırlandı (`updated_at` sunucu tarafından yazılır, geri tarihlendirme engellendi).
  - `pvp_rooms` tablosuna doğrudan tablo erişimi kapatıldı; yalnızca sınır doğrulaması (`score between 0 and 2000`, `step between 0 and 5`) yapan `security definer` RPC fonksiyonları üzerinden erişilebilir.
  - `AndroidManifest.xml` içerisinde `INTERNET` izni eklendi, `allowBackup="false"` ve `usesCleartextTraffic="false"` yapılandırıldı.
