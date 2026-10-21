import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footiq/core/cloud.dart';
import 'package:footiq/core/game_state.dart';
import 'package:footiq/data/questions.dart';
import 'package:footiq/main.dart';
import 'package:footiq/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerçek kullanıcı akışı: tüm modlar, pencereler ve oyun döngüsü.
void main() {
  Cloud.disabled = true;

  testWidgets('misafir olarak giriş yapıp ilk seviyeyi 3 yıldızla geçer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    GameState.instance
      ..resetProgress()
      ..logout();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> wait([int ms = 500]) => tester.pump(Duration(milliseconds: ms));

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
    await tester.tap(find.text('Chapter 1'));
    await wait(800);
    await wait(800);
    final energyBefore = GameState.instance.energy;
    await tester.tap(find.text('1').first);
    await wait(800);
    await wait(800);
    expect(find.text('Chapter 1  •  Seviye 1'), findsOneWidget);
    expect(GameState.instance.energy, energyBefore - 1);

    // 5 soruyu doğru cevapla
    for (var i = 0; i < 5; i++) {
      final question = chapter1.firstWhere((q) => find.text(q.text).evaluate().isNotEmpty);
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
    expect(find.text('Chapter 1  •  Seviye 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PVP maçında tüm soruları doğru cevaplayınca kazanır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    GameState.instance
      ..resetProgress()
      ..logout();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> wait([int ms = 500]) => tester.pump(Duration(milliseconds: ms));

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
      final question = hangiTakim.firstWhere((q) => find.text(q.text).evaluate().isNotEmpty);
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

  testWidgets('Sıralama, Davet Et Kazan, İzle Kazan ve Ayarlar pencereleri sorunsuz çalışır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    GameState.instance
      ..resetProgress()
      ..logout();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> wait([int ms = 500]) => tester.pump(Duration(milliseconds: ms));

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

    // Sıralama penceresi (Rank etiketine tıkla)
    expect(find.textContaining('Rank: #'), findsOneWidget);
    await tester.tap(find.textContaining('Rank: #'));
    await wait(600);
    expect(find.text('Sezon Sıralaması'), findsOneWidget);
    expect(find.textContaining('Senin sıran: #'), findsOneWidget);
    // Kapat
    await tester.tap(find.byType(CloseBtn));
    await wait(600);

    // Davet Et Kazan penceresi
    await tester.tap(find.text('Davet Et Kazan'));
    await wait(600);
    expect(find.text('Kodu Kullan'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ABCD1234');
    final coinsBeforeInvite = GameState.instance.coins;
    await tester.tap(find.text('Kodu Kullan'));
    await wait(400);
    expect(GameState.instance.coins, coinsBeforeInvite + 500);
    await tester.tap(find.byType(CloseBtn));
    await wait(600);

    // İzle Kazan (önce 1 enerji harca)
    GameState.instance.useEnergy();
    await wait(200);
    expect(GameState.instance.energy, 5);
    await tester.tap(find.text('Izle Kazan'));
    await wait(400);
    expect(find.text('Bonus Ödül'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await wait(400);
    }
    expect(GameState.instance.energy, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tüm bölümler (Chapter 1..4) ve tüm PVP modları (Ben Kimim, Champions League, Hangi Takım) uçtan uca çalışır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState.instance
      ..resetProgress()
      ..logout();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> wait([int ms = 500]) => tester.pump(Duration(milliseconds: ms));

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
    await tester.tap(find.text('Chapter 4'));
    await wait(500);
    await wait(500);
    state.addEnergy(6);
    // Chapter 4 haritasında 1. seviye düğmesine (453, 1400 -> logical 276, 760) dokun
    await tester.tapAt(const Offset(276, 760));
    await wait(500);
    await wait(500);
    expect(find.text('Chapter 4  •  Seviye 1'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      final q = chapter4.firstWhere((q) => find.text(q.text).evaluate().isNotEmpty);
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
        final q = pool.firstWhere((q) => find.text(q.text).evaluate().isNotEmpty);
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
  });
}
