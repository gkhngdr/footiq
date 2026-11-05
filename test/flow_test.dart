import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footiq/core/cloud.dart';
import 'package:footiq/core/game_state.dart';
import 'package:footiq/data/questions.dart';
import 'package:footiq/main.dart';
import 'package:footiq/screens/chapter_map_screen.dart';
import 'package:footiq/screens/settings_dialog.dart';
import 'package:footiq/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerçek kullanıcı akışı: tüm modlar, pencereler ve oyun döngüsü.
void main() {
  Cloud.disabled = true;

  testWidgets('misafir olarak giriş yapıp ilk seviyeyi 3 yıldızla geçer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GameState.instance
      ..resetProgress()
      ..logout();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> wait([int ms = 500]) =>
        tester.pump(Duration(milliseconds: ms));

    await tester.pumpWidget(const FootIQApp());
    for (var i = 0; i < 10; i++) {
      await wait(300);
    }

    // Giriş
    expect(find.text('MİSAFİR OLARAK DEVAM ET'), findsOneWidget);
    await tester.tap(find.text('MİSAFİR OLARAK DEVAM ET'));
    await wait(800);
    await wait(800);

    // Günlük ödül penceresi açılır, "Topla" ile alınır
    expect(find.text('Topla'), findsOneWidget);
    final coinsBefore = GameState.instance.coins;
    await tester.tap(find.text('Topla'));
    await wait(1000);
    await wait(1000);
    expect(GameState.instance.coins, coinsBefore + 20);
    expect(GameState.instance.canClaimDaily, isFalse);

    // OYNA → Chapter 1 → Seviye 1
    await tester.tap(find.text('OYNA'));
    await wait(800);
    await wait(800);
    expect(find.text('Toplam Yıldız: 0 / 120'), findsOneWidget);
    await tester.tap(find.text('Bölüm 1'));
    await wait(800);
    await wait(800);
    final energyBefore = GameState.instance.energy;
    await tester.tap(find.text('1').first);
    await wait(800);
    await wait(800);
    expect(find.text('Bölüm 1  •  Seviye 1'), findsOneWidget);
    expect(GameState.instance.energy, energyBefore - 1);

    // 5 soruyu doğru cevapla
    for (var i = 0; i < 5; i++) {
      final question = chapter1.firstWhere(
        (q) => find.text(q.text).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(question.answer));
      await wait(1500);
      await wait(500);
    }

    expect(find.text('Tebrikler!'), findsOneWidget);
    expect(find.text('5 / 5 doğru'), findsOneWidget);
    expect(GameState.instance.stars(1, 1), 3);
    expect(GameState.instance.trophies, 15);
    expect(GameState.instance.isLevelUnlocked(1, 2), isTrue);

    // Haritaya dön
    await tester.tap(find.text('Haritaya Dön'));
    await wait(800);
    await wait(800);
    expect(find.text('Bölüm 1  •  Seviye 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PVP maçında tüm soruları doğru cevaplayınca kazanır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GameState.instance
      ..resetProgress()
      ..logout();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> wait([int ms = 500]) =>
        tester.pump(Duration(milliseconds: ms));

    await tester.pumpWidget(const FootIQApp());
    for (var i = 0; i < 10; i++) {
      await wait(300);
    }
    await tester.tap(find.text('MİSAFİR OLARAK DEVAM ET'));
    await wait(800);
    await wait(800);
    await tester.tap(find.text('Topla'));
    await wait(1000);
    await wait(1000);

    await tester.tap(find.text('PVP OYNA'));
    await wait(800);
    await wait(800);
    await tester.tap(find.text('Hangi Takım?'));
    await wait(100);
    await wait(400);
    expect(find.text('Rakip aranıyor...'), findsOneWidget);
    await wait(2000);
    await wait(500);

    final coinsBefore = GameState.instance.coins;
    for (var i = 0; i < 5; i++) {
      final question = hangiTakim.firstWhere(
        (q) => find.text(q.text).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(question.answer));
      await wait(1500);
      await wait(500);
    }

    // Anında doğru cevap botun en iyi skorundan (5 x 225) yüksektir.
    expect(find.text('Kazandın!'), findsOneWidget);
    expect(GameState.instance.coins, coinsBefore + 5000);
    expect(GameState.instance.trophies, 15);

    await tester.tap(find.text('Ana Menü'));
    await wait(800);
    await wait(800);
    expect(find.text('Ben Kimim?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Sıralama, Davet Et Kazan, İzle Kazan ve Ayarlar pencereleri sorunsuz çalışır',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GameState.instance
        ..resetProgress()
        ..logout();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      Future<void> wait([int ms = 500]) =>
          tester.pump(Duration(milliseconds: ms));

      await tester.pumpWidget(const FootIQApp());
      for (var i = 0; i < 10; i++) {
        await wait(300);
      }
      await tester.tap(find.text('MİSAFİR OLARAK DEVAM ET'));
      await wait(800);
      await wait(800);
      await tester.tap(find.text('Topla'));
      await wait(1000);
      await wait(1000);

      // Sıralama penceresi: ana ekranda sıra yalnızca sezon çubuğunda (üst çubukta tekrar yok)
      expect(find.textContaining('Sıra: #'), findsNothing);
      expect(find.text('SEZON LİGİ'), findsOneWidget);
      await tester.tap(find.text('SEZON LİGİ'));
      await wait(600);
      expect(find.text('Sezon Sıralaması'), findsOneWidget);
      // Misafir sıralamada yer almaz; sahte rakip de gösterilmez
      expect(find.text('Hesap aç, sıralamaya gir!'), findsOneWidget);
      expect(find.text('EfsaneKaptan10'), findsNothing);
      // Kapat
      await tester.tap(find.byType(CloseBtn));
      await wait(600);

      // Arkadaşınla Oyna ekranı: oda kur / koda katıl; Davet Et Kazan buraya taşındı
      await tester.tap(find.text('ARKADAŞINLA OYNA'));
      await wait(600);
      await wait(600);
      expect(find.text('ODAYI AÇ'), findsOneWidget);
      // Sunucu yok (test): oda açılamaz, uyarı çıkar
      await tester.tap(find.text('ODAYI AÇ'));
      await wait(1000);
      await wait(500);
      expect(
        find.text('Oda açılamadı. İnternetini kontrol et.'),
        findsOneWidget,
      );
      await wait(2200);
      // Koda katıl: eksik kod uyarısı
      await tester.tap(find.text('KODA KATIL'));
      await wait(300);
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('KATIL'));
      await wait(1000);
      await wait(500);
      expect(
        find.text('Oda kodu 4 haneli olmalı (ör. FQ-4032).'),
        findsOneWidget,
      );
      await wait(2200);
      await tester.tap(find.textContaining('Davet kodunla arkadaşını getir'));
      await wait(600);
      expect(find.text('Kodu Kullan'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'ABCD1234');
      final coinsBeforeInvite = GameState.instance.coins;
      await tester.tap(find.text('Kodu Kullan'));
      await wait(400);
      expect(GameState.instance.coins, coinsBeforeInvite + 500);
      await tester.tap(find.byType(CloseBtn).last);
      await wait(600);
      await wait(600);
      // Arkadaş ekranını kapat, ana ekrana dön
      expect(find.byType(CloseBtn), findsOneWidget);
      await tester.tap(find.byType(CloseBtn));
      await wait(600);
      await wait(600);

      // İzle Kazan (önce 1 enerji harca)
      GameState.instance.useEnergy();
      await wait(200);
      expect(GameState.instance.energy, 5);
      await tester.tap(find.text('İzle\nKazan'));
      await wait(400);
      expect(find.text('Bonus Ödül'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await wait(400);
      }
      expect(GameState.instance.energy, 6);

      // Ayarlar penceresi
      showSettings(tester.element(find.text('OYNA')));
      await wait(600);
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('Çıkış Yap'), findsOneWidget);
      expect(find.text('İlerlemeyi Sıfırla'), findsNothing);
      expect(find.text('Hesap Değiştir / Giriş'), findsNothing);
      expect(find.text('Ses: Açık'), findsOneWidget);
      await tester.tap(find.text('Ses: Açık'));
      await wait(300);
      expect(find.text('Ses: Kapalı'), findsOneWidget);
      expect(GameState.instance.soundOn, isFalse);
      await tester.tap(find.text('Ses: Kapalı'));
      await wait(300);
      expect(find.text('Ses: Açık'), findsOneWidget);
      expect(GameState.instance.soundOn, isTrue);
      await tester.tap(find.byType(CloseBtn));
      await wait(300);
      await wait(300);
      await wait(300);
      expect(find.text('Ayarlar'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tüm bölümler (Chapter 1..4) ve tüm PVP modları (Ben Kimim, Champions League, Hangi Takım) uçtan uca çalışır',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = GameState.instance
        ..resetProgress()
        ..logout();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      Future<void> wait([int ms = 500]) =>
          tester.pump(Duration(milliseconds: ms));

      await tester.pumpWidget(const FootIQApp());
      for (var i = 0; i < 10; i++) {
        await wait(300);
      }
      await tester.tap(find.text('MİSAFİR OLARAK DEVAM ET'));
      await wait(800);
      await wait(800);
      await tester.tap(find.text('Topla'));
      await wait(1000);
      await wait(1000);

      // Chapter 1..3'ü tamamla ki 4 bölümün tamamı açılsın
      for (var ch = 1; ch <= 3; ch++) {
        for (var lvl = 1; lvl <= 10; lvl++) {
          state.completeLevel(ch, lvl, 3, 10);
        }
      }
      await wait(200);

      // OYNA → Chapter 1..4 kontrolü ve Chapter 4 Seviye 1 oynanışı
      await tester.tap(find.text('OYNA'));
      await wait(500);
      await wait(500);
      expect(find.text('Toplam Yıldız: 90 / 120'), findsOneWidget);
      await tester.tap(find.text('Bölüm 4'));
      await wait(500);
      await wait(500);
      state.addEnergy(6);
      // Chapter 4 haritasında 1. seviye düğmesine (453, 1400 -> logical 276, 760) dokun
      await tester.tapAt(const Offset(276, 760));
      await wait(500);
      await wait(500);
      expect(find.text('Bölüm 4  •  Seviye 1'), findsOneWidget);

      for (var i = 0; i < 5; i++) {
        final q = chapter4.firstWhere(
          (q) => find.text(q.text).evaluate().isNotEmpty,
        );
        await tester.tap(find.text(q.answer));
        await wait(1500);
        await wait(500);
      }
      expect(find.text('Tebrikler!'), findsOneWidget);
      await tester.tap(find.text('Haritaya Dön'));
      await wait(500);
      await wait(500);
      // Chapter 4 haritasından ve bölüm seçim ekranından ana menüye dön
      await tester.tap(find.byType(CloseBtn));
      await wait(500);
      await wait(500);
      await tester.tap(find.byType(CloseBtn));
      await wait(500);
      await wait(500);

      // PVP: Ben Kimim? ve Champions League modlarını da test et
      await tester.tap(find.text('PVP OYNA'));
      await wait(500);
      await wait(500);
      for (final (title, pool) in [
        ('Ben Kimim?', benKimim),
        ('Champions League', championsLeague),
      ]) {
        state.addEnergy(6);
        await tester.tap(find.text(title));
        await wait(200);
        await wait(400);
        expect(find.text('Rakip aranıyor...'), findsOneWidget);
        await wait(2000);
        await wait(500);
        for (var i = 0; i < 5; i++) {
          final q = pool.firstWhere(
            (q) => find.text(q.text).evaluate().isNotEmpty,
          );
          await tester.tap(find.text(q.answer));
          await wait(1500);
          await wait(500);
        }
        expect(find.text('Kazandın!'), findsOneWidget);
        await tester.tap(find.text('Ana Menü'));
        await wait(500);
        await wait(500);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Hesaptan çıkış yapılıp misafir olarak devam edildiğinde hesap verileri yerine temiz misafir profili gelir',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = GameState.instance;
      state.setAccount('Ahmet1905');
      state.trophies = 150;
      state.coins = 5000;
      expect(state.playerName, 'Ahmet1905');
      expect(state.isAccount, isTrue);

      // Çıkış yap
      state.logout();
      expect(state.loggedIn, isFalse);
      expect(state.isAccount, isFalse);
      expect(state.trophies, 0);
      expect(state.playerName.startsWith('Misafir'), isTrue);

      // Misafir olarak devam et
      state.loginAsGuest();
      expect(state.loggedIn, isTrue);
      expect(state.isAccount, isFalse);
      expect(state.playerName.startsWith('Misafir'), isTrue);
      expect(state.playerName, isNot('Ahmet1905'));
      expect(state.trophies, 0);
      expect(state.coins, 500);
    },
  );

  testWidgets(
    'Giriş ekranında TextField tıklandığında klavye açılsa bile odak kaybolmaz ve dışarı tıklayınca kapanır',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GameState.instance
        ..resetProgress()
        ..logout();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const FootIQApp());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      final field = find.byType(TextField).first;
      expect(field, findsOneWidget);

      // Tıkla ve odaklan
      await tester.tap(field);
      await tester.pump();

      final primaryBefore = FocusManager.instance.primaryFocus;
      expect(
        primaryBefore?.context?.findAncestorWidgetOfExactType<TextField>() !=
            null,
        isTrue,
      );

      // Sanal klavyenin açıldığını simüle et (bottom insets = 300)
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      // Klavye açılınca ve ekran yukarı kayınca odağın bozulmadığını doğrula
      final primaryAfter = FocusManager.instance.primaryFocus;
      expect(
        primaryAfter?.context?.findAncestorWidgetOfExactType<TextField>() !=
            null,
        isTrue,
        reason: 'Klavye açıldığında odak kaybolmamalı',
      );

      // Dışarıya (boş arka plana) tıklandığında klavyenin ve odağın kapandığını doğrula
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      final primaryAfterTapOutside = FocusManager.instance.primaryFocus;
      expect(
        primaryAfterTapOutside?.context
            ?.findAncestorWidgetOfExactType<TextField>(),
        isNull,
        reason: 'Dışarı tıklandığında odak kapanmalı',
      );
    },
  );

  testWidgets(
    'Şifremi unuttum penceresi e-postayı taşır, geçersiz e-postayı reddeder ve kapanır',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GameState.instance
        ..resetProgress()
        ..logout();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const FootIQApp());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.enterText(find.byType(TextField).first, 'oyuncu@ornek.com');
      await tester.tap(find.text('Şifremi unuttum'));
      await tester.pumpAndSettle();

      // Pencere açılır ve girilen e-posta hazır gelir
      expect(find.text('Şifreni Sıfırla'), findsOneWidget);
      expect(find.text('KOD GÖNDER'), findsOneWidget);
      // (biri giriş ekranındaki alan, diğeri pencerenin alanı)
      expect(
        find.widgetWithText(TextField, 'oyuncu@ornek.com'),
        findsNWidgets(2),
      );
      final emailField = find.byType(TextField).last;

      // Geçersiz e-posta: kod gönderilmez, uyarı çıkar
      await tester.enterText(emailField, 'gecersiz');
      await tester.tap(find.text('KOD GÖNDER'));
      await tester.pump();
      expect(find.text('Geçerli bir e-posta gir.'), findsOneWidget);
      expect(find.text('ŞİFREYİ DEĞİŞTİR'), findsNothing);

      // Sunucu yokken (test) geçerli e-posta: hata gösterilir, adım ilerlemez
      await tester.enterText(find.byType(TextField).last, 'oyuncu@ornek.com');
      await tester.tap(find.text('KOD GÖNDER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sunucuya bağlanılamadı.'), findsOneWidget);
      expect(find.text('ŞİFREYİ DEĞİŞTİR'), findsNothing);

      // Vazgeç ile giriş ekranına dönülür
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('Şifreni Sıfırla'), findsNothing);
      expect(find.text('GİRİŞ YAP'), findsOneWidget);
    },
  );

  testWidgets(
    'Bölüm 1 son seviyesinden "Sonraki Bölüm" ile Bölüm 2 oynanır ve Bölüm 2 haritasına dönülür',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = GameState.instance
        ..resetProgress()
        ..logout();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      Future<void> wait([int ms = 500]) =>
          tester.pump(Duration(milliseconds: ms));
      Future<void> answerAll(List<Question> pool) async {
        for (var i = 0; i < 5; i++) {
          final q = pool.firstWhere(
            (q) => find.text(q.text).evaluate().isNotEmpty,
          );
          await tester.tap(find.text(q.answer));
          await wait(1500);
          await wait(500);
        }
      }

      Finder mapOf(int chapter) => find.byWidgetPredicate(
        (w) => w is ChapterMapScreen && w.chapter == chapter,
        skipOffstage: false,
      );

      await tester.pumpWidget(const FootIQApp());
      for (var i = 0; i < 10; i++) {
        await wait(300);
      }
      await tester.tap(find.text('MİSAFİR OLARAK DEVAM ET'));
      await wait(800);
      await wait(800);
      await tester.tap(find.text('Topla'));
      await wait(1000);
      await wait(1000);
      for (var lvl = 1; lvl <= 9; lvl++) {
        state.completeLevel(1, lvl, 3, 10);
      }
      state.addEnergy(6);

      await tester.tap(find.text('OYNA'));
      await wait(800);
      await wait(800);
      await tester.tap(find.text('Bölüm 1'));
      await wait(800);
      await wait(800);
      await tester.tap(
        find.byWidgetPredicate((w) => w is LevelButton && w.number == 10),
      );
      await wait(800);
      await wait(800);
      expect(find.text('Bölüm 1  •  Seviye 10'), findsOneWidget);
      await answerAll(chapter1);

      await tester.tap(find.text('Sonraki Bölüm'));
      await wait(800);
      await wait(800);
      expect(find.text('Bölüm 2  •  Seviye 1'), findsOneWidget);
      // Alttaki harita artık Bölüm 2 haritası (Bölüm 1 haritası yığından çıktı)
      expect(mapOf(1), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is ChapterMapScreen,
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await answerAll(chapter2);
      await tester.tap(find.text('Haritaya Dön'));
      await wait(800);
      await wait(800);
      expect(mapOf(2), findsOneWidget);
      expect(find.text('Bölüm 2  •  Seviye 1'), findsNothing);
      expect(state.stars(2, 1), 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PVP ekranındaki 3-2-1 düğmesi maç ekranını açar; sunucu yoksa düzgün hata gösterir',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GameState.instance
        ..resetProgress()
        ..logout();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Future<void> wait([int ms = 500]) =>
          tester.pump(Duration(milliseconds: ms));

      await tester.pumpWidget(const FootIQApp());
      for (var i = 0; i < 10; i++) {
        await wait(300);
      }
      await tester.tap(find.text('MİSAFİR OLARAK DEVAM ET'));
      await wait(800);
      await wait(800);
      await tester.tap(find.text('Topla'));
      await wait(1000);
      await wait(1000);
      await tester.tap(find.text('PVP OYNA'));
      await wait(800);
      await wait(800);
      await tester.tap(find.textContaining('Ortak futbolcuyu söyle'));
      await wait(800);
      await wait(800);
      // Önce oyunun kendi mikrofon penceresi çıkar (telefonun izin penceresi değil).
      expect(find.text('Mikrofonu Aç'), findsOneWidget);
      await tester.tap(find.text('Klavyeyle'));
      await wait(800);
      await wait(800);
      expect(find.textContaining('Sorular yüklenemedi'), findsOneWidget);
      await tester.tap(find.byType(CloseBtn));
      await wait(800);
      await wait(800);
      expect(find.text('Ben Kimim?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
