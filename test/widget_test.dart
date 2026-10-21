import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:footiq/data/questions.dart';

void main() {
  test('her bölümde 80 soru, her PVP modunda 60 soru (toplam 500 benzersiz soru) ve 4 benzersiz seçenek var', () {
    final allTexts = <String>{};
    for (final pool in [chapter1, chapter2, chapter3, chapter4]) {
      expect(pool.length, 80);
      for (final q in pool) {
        expect(q.options.length, 4, reason: q.text);
        expect(q.options.toSet().length, 4, reason: 'Tekrarlanan seçenek: ${q.text}');
        expect(allTexts.add(q.text), isTrue, reason: 'Tekrarlanan soru metni: ${q.text}');
      }
    }
    for (final pool in [benKimim, championsLeague, hangiTakim]) {
      expect(pool.length, 60);
      for (final q in pool) {
        expect(q.options.length, 4, reason: q.text);
        expect(q.options.toSet().length, 4, reason: 'Tekrarlanan seçenek: ${q.text}');
        expect(allTexts.add(q.text), isTrue, reason: 'Tekrarlanan soru metni: ${q.text}');
      }
    }
    expect(allTexts.length, 500);
  });

  test('aynı bölümdeki 1..10 seviyeleri çakışmaz ve aynı seviye tekrar oynandığında farklı kombinasyonlar üretir', () {
    for (var ch = 1; ch <= 4; ch++) {
      final seen = <String>{};
      for (var lvl = 1; lvl <= 10; lvl++) {
        final qs = pickLevelQuestions(ch, lvl, 5, Random(42));
        expect(qs.length, 5);
        for (final q in qs) {
          expect(seen.add(q.text), isTrue, reason: 'Bölüm $ch Seviye $lvl sorusu tekrar etti: ${q.text}');
        }
        // Aynı seviye farklı rng ile tekrar oynandığında 8'lik dilimden farklı sıralama/soru seçebilmeli
        final runA = pickLevelQuestions(ch, lvl, 5, Random(1)).map((q) => q.text).join('|');
        final runB = pickLevelQuestions(ch, lvl, 5, Random(2)).map((q) => q.text).join('|');
        expect(runA, isNot(equals(runB)));
      }
    }
  });

  test('online PVP modunda aynı seed iki oyuncuya birebir aynı soru ve şık sırasını verir', () {
    const seed = 987654321;
    for (final cat in PvpCategory.values) {
      final playerA = pickSeededPvpQuestions(cat, 5, seed);
      final playerB = pickSeededPvpQuestions(cat, 5, seed);
      expect(playerA.map((q) => q.text).toList(), playerB.map((q) => q.text).toList());
      for (var i = 0; i < 5; i++) {
        final (optsA, corrA) = playerA[i].shuffled(Random(seed * 31 + i + 7));
        final (optsB, corrB) = playerB[i].shuffled(Random(seed * 31 + i + 7));
        expect(optsA, optsB);
        expect(corrA, corrB);
      }
    }
  });
}
