import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud.dart';

/// 3-2-1 modunda bir kulüp (logo yerine renk + kısa kod rozeti).
@immutable
class T21Club {
  const T21Club({
    required this.code,
    required this.name,
    required this.short,
    required this.league,
    this.color,
  });

  final String code;
  final String name;
  final String short;
  final String league;
  final Color? color;

  static const leagueNames = {
    'TR': 'Süper Lig',
    'EN': 'Premier Lig',
    'ES': 'La Liga',
    'IT': 'Serie A',
    'DE': 'Bundesliga',
    'FR': 'Ligue 1',
  };

  String get leagueName => leagueNames[league] ?? league;

  static Color? parseColor(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }
}

/// Bir soru: iki kulüp. Doğru cevaplar istemciye gönderilmez.
@immutable
class T21Question {
  const T21Question({required this.pairId, required this.a, required this.b});

  final int pairId;
  final T21Club a;
  final T21Club b;
}

enum T21Verdict { correct, wrong, repeat, unknown }

@immutable
class T21Judgement {
  const T21Judgement(
    this.verdict, {
    this.playerId,
    this.playerName,
    this.score = 0,
  });

  final T21Verdict verdict;
  final int? playerId;
  final String? playerName;
  final double score;
}

/// 3-2-1 sunucu fonksiyonları (supabase/three21.sql). Cevap kontrolü ve soru
/// seçimi sunucuda yapılır; uygulama yalnızca sonucu gösterir.
class T21Api {
  T21Api._();

  static SupabaseClient? get _db => Cloud.client;

  /// Bir maç için [count] soru; hiçbir kulüp iki kez görünmez.
  static Future<List<T21Question>> pickQuestions({
    int count = 8,
    int maxDifficulty = 1,
  }) async {
    final db = _db;
    if (db == null) return const [];
    try {
      final rows = await db.rpc(
        't21_pick_pairs',
        params: {'p_count': count, 'p_max_difficulty': maxDifficulty},
      ) as List;
      return [
        for (final r in rows.cast<Map>())
          T21Question(
            pairId: (r['pair_id'] as num).toInt(),
            a: T21Club(
              code: r['club_a'] as String,
              name: r['name_a'] as String,
              short: r['short_a'] as String,
              league: r['league_a'] as String,
              color: T21Club.parseColor(r['color_a'] as String?),
            ),
            b: T21Club(
              code: r['club_b'] as String,
              name: r['name_b'] as String,
              short: r['short_b'] as String,
              league: r['league_b'] as String,
              color: T21Club.parseColor(r['color_b'] as String?),
            ),
          ),
      ];
    } catch (e) {
      debugPrint('3-2-1 soruları alınamadı: $e');
      return const [];
    }
  }

  /// Söylenen/yazılan isim(ler)i değerlendirir. [said]: ses tanımanın tahminleri.
  static Future<T21Judgement> judge({
    required int pairId,
    required List<String> said,
    List<int> used = const [],
  }) async {
    final db = _db;
    final inputs = said
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(5)
        .toList();
    if (db == null || inputs.isEmpty) {
      return const T21Judgement(T21Verdict.unknown);
    }
    try {
      final r = await db.rpc(
        't21_judge',
        params: {'p_pair': pairId, 'p_said': inputs, 'p_used': used},
      ) as Map;
      final verdict = switch (r['result']) {
        'correct' => T21Verdict.correct,
        'wrong' => T21Verdict.wrong,
        'repeat' => T21Verdict.repeat,
        _ => T21Verdict.unknown,
      };
      return T21Judgement(
        verdict,
        playerId: (r['player_id'] as num?)?.toInt(),
        playerName: r['player'] as String?,
        score: (r['score'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('3-2-1 cevap kontrolü başarısız: $e');
      return const T21Judgement(T21Verdict.unknown);
    }
  }

  /// Soru bitince gösterilecek doğru cevaplar (en bilinenler önce).
  static Future<List<({int id, String name})>> reveal(
    int pairId, {
    int limit = 5,
  }) async {
    final db = _db;
    if (db == null) return const [];
    try {
      final rows = await db.rpc(
        't21_reveal',
        params: {'p_pair': pairId, 'p_limit': limit},
      ) as List;
      return [
        for (final r in rows.cast<Map>())
          (id: (r['player_id'] as num).toInt(), name: r['name'] as String),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Yazarken öneri listesi (3+ harf).
  static Future<List<String>> suggest(String prefix) async {
    final db = _db;
    if (db == null || prefix.trim().length < 3) return const [];
    try {
      final rows =
          await db.rpc('t21_suggest', params: {'p_prefix': prefix}) as List;
      return [for (final r in rows.cast<Map>()) r['name'] as String];
    } catch (_) {
      return const [];
    }
  }
}
