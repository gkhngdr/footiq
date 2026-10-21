import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/questions.dart';
import 'game_state.dart';

/// Online PVP oda durumu. İki oyuncu aynı [seed] ile aynı soruları eşzamanlı görür.
class PvpRoomState {
  const PvpRoomState({
    required this.id,
    required this.seed,
    required this.hostId,
    required this.hostName,
    required this.hostScore,
    required this.hostStep,
    required this.guestId,
    required this.guestName,
    required this.guestScore,
    required this.guestStep,
    required this.status,
  });

  factory PvpRoomState.fromMap(Map<String, dynamic> m) => PvpRoomState(
        id: m['id'] as String,
        seed: (m['seed'] as num).toInt(),
        hostId: m['host_id'] as String,
        hostName: m['host_name'] as String? ?? 'Oyuncu',
        hostScore: (m['host_score'] as num? ?? 0).toInt(),
        hostStep: (m['host_step'] as num? ?? 0).toInt(),
        guestId: m['guest_id'] as String?,
        guestName: m['guest_name'] as String?,
        guestScore: (m['guest_score'] as num? ?? 0).toInt(),
        guestStep: (m['guest_step'] as num? ?? 0).toInt(),
        status: m['status'] as String? ?? 'open',
      );

  final String id;
  final int seed;
  final String hostId;
  final String hostName;
  final int hostScore;
  final int hostStep;
  final String? guestId;
  final String? guestName;
  final int guestScore;
  final int guestStep;
  final String status;

  bool get isMatched => status == 'playing' || status == 'done' || guestId != null;

  bool isHost(String myPlayerId) => hostId == myPlayerId;

  String opponentName(String myPlayerId) =>
      isHost(myPlayerId) ? (guestName ?? 'Rakip') : hostName;

  int opponentScore(String myPlayerId) =>
      isHost(myPlayerId) ? guestScore : hostScore;

  int opponentStep(String myPlayerId) =>
      isHost(myPlayerId) ? guestStep : hostStep;
}

/// Supabase bağlantısı. Yalnızca publishable (anon) key kullanılır; güvenlik
/// `supabase/schema.sql` içindeki RLS politikalarına dayanır.
class Cloud {
  Cloud._();

  static const url = 'https://adxkmacrsylhacxsmktr.supabase.co';
  static const publishableKey = 'sb_publishable_cvBVu2lB5zZdINYGMx2czg_sAo0W5BF';

  static bool ready = false;

  /// Testlerde ağ bağlantısı kurulmaması için.
  @visibleForTesting
  static bool disabled = false;

  /// Bulut kullanılabilirse (init başarılı) true.
  static SupabaseClient? get _db => (!disabled && ready) ? Supabase.instance.client : null;

  static bool get signedIn => _db?.auth.currentUser != null;

  static Future<void> init() async {
    if (disabled || ready) return;
    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      ready = true;
    } catch (e) {
      debugPrint('Supabase başlatılamadı: $e');
    }
  }

  static String _clean(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login')) return 'E-posta veya şifre hatalı.';
      if (m.contains('already registered')) return 'Bu e-posta zaten kayıtlı.';
      if (m.contains('confirm')) return 'Lütfen önce e-postanı doğrula.';
      if (m.contains('password')) return 'Şifre en az 6 karakter olmalı.';
      if (m.contains('rate') || m.contains('too many')) return 'Çok fazla deneme. Biraz bekle.';
      return 'Giriş yapılamadı. Bilgilerini kontrol et.';
    }
    return 'Bağlantı hatası. İnternetini kontrol et.';
  }

  /// Hata mesajı döner, başarılıysa null.
  static Future<String?> signIn(String email, String password) async {
    if (_db == null) return 'Sunucuya bağlanılamadı.';
    try {
      await _db!.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
      await pullProfile();
      await GameState.instance.refreshRank();
      return null;
    } catch (e) {
      return _clean(e);
    }
  }

  /// Dönüş: (hata, e-posta doğrulaması gerekiyor mu)
  static Future<(String?, bool)> signUp(String email, String password, String username) async {
    if (_db == null) return ('Sunucuya bağlanılamadı.', false);
    try {
      final cleanEmail = email.trim().toLowerCase();
      var res = await _db!.auth.signUp(email: cleanEmail, password: password, data: {'username': username});
      // Supabase, zaten kayıtlı bir e-posta ile tekrar kayıt denendiğinde
      // identities listesini boş döndürür.
      if (res.user?.identities != null && res.user!.identities!.isEmpty) {
        return ('Bu e-posta zaten kayıtlı. Giriş yapabilirsin.', false);
      }
      if (res.session == null) {
        // Sunucu tarafında on_auth_user_autoconfirm trigger'ı aktif olduğundan doğrudan oturum aç.
        try {
          res = await _db!.auth.signInWithPassword(email: cleanEmail, password: password);
        } on AuthException catch (e) {
          if (e.message.toLowerCase().contains('invalid login')) {
            return ('Bu e-posta zaten kayıtlı. Giriş yapabilirsin.', false);
          }
        } catch (_) {}
      }
      if (res.session == null) return (null, true);
      try {
        await _createProfile(username);
      } catch (_) {}
      await pullProfile();
      await GameState.instance.refreshRank();
      return (null, false);
    } catch (e) {
      return (_clean(e), false);
    }
  }

  static Future<bool> deleteAccount() async {
    if (!signedIn) return false;
    try {
      await _db!.rpc('delete_account');
      await _db!.auth.signOut();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> resetPassword(String email) async {
    if (_db == null) return 'Sunucuya bağlanılamadı.';
    try {
      await _db!.auth.resetPasswordForEmail(email.trim());
      return null;
    } catch (e) {
      return _clean(e);
    }
  }

  static Future<void> signOut() async {
    try {
      await _db?.auth.signOut();
    } catch (_) {}
  }

  static Future<void> _createProfile(String username) async {
    final user = _db?.auth.currentUser;
    if (user == null) return;
    final s = GameState.instance;
    // upsert değil insert: id sütunu için UPDATE yetkisi verilmedi (güvenlik).
    await _db!.from('profiles').insert({
      'id': user.id,
      'username': username,
      'trophies': s.trophies,
      'coins': s.coins,
      'progress': s.toMap(),
    });
  }

  /// Buluttaki profili cihaza alır; yoksa cihazdakini yükler.
  static Future<void> pullProfile() async {
    final user = _db?.auth.currentUser;
    if (user == null) return;
    try {
      final row = await _db!.from('profiles').select('id, username, trophies, coins, progress').eq('id', user.id).maybeSingle();
      if (row == null) {
        final name = (user.userMetadata?['username'] as String?) ?? 'Oyuncu${user.id.substring(0, 4)}';
        await _createProfile(name);
        GameState.instance.setAccount(name);
        return;
      }
      GameState.instance.applyCloud(row);
    } catch (e) {
      debugPrint('Profil alınamadı: $e');
    }
  }

  static Future<void> pushProfile() async {
    final user = _db?.auth.currentUser;
    if (user == null) return;
    final s = GameState.instance;
    try {
      await _db!.from('profiles').update({
        'username': s.playerName,
        'trophies': s.trophies,
        'coins': s.coins,
        'progress': s.toMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Profil kaydedilemedi: $e');
    }
  }

  static Future<int?> myRank() async {
    if (!signedIn) return null;
    try {
      return await _db!.rpc('my_rank') as int?;
    } catch (_) {
      return null;
    }
  }

  static Future<List<({String name, int trophies})>> leaderboard() async {
    if (!signedIn) return [];
    try {
      final rows = await _db!.rpc('leaderboard') as List;
      return [for (final r in rows) (name: r['username'] as String, trophies: r['trophies'] as int)];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> inviteCode() async {
    if (!signedIn) return null;
    try {
      return await _db!.rpc('my_invite_code') as String?;
    } catch (_) {
      return null;
    }
  }

  /// Kazanılan coin (0 ise geçersiz/kullanılmış kod).
  static Future<int> redeemInvite(String code) async {
    if (!signedIn) return 0;
    try {
      final n = await _db!.rpc('redeem_invite', params: {'code': code.trim().toLowerCase()}) as int? ?? 0;
      if (n > 0) await pullProfile();
      return n;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------- Online PVP

  static Future<PvpRoomState?> joinOrCreatePvp({
    required PvpCategory category,
    required String playerId,
    required String playerName,
    required int seed,
  }) async {
    if (_db == null) return null;
    try {
      final res = await _db!.rpc('join_or_create_pvp', params: {
        'p_category': category.name,
        'p_player_id': playerId,
        'p_name': playerName,
        'p_seed': seed,
      });
      if (res is Map && res['id'] is String) {
        return PvpRoomState.fromMap(res.cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      debugPrint('PVP odaya katılınamadı: $e');
      return null;
    }
  }

  static Future<PvpRoomState?> pollPvpRoom({
    required String roomId,
    required String playerId,
  }) async {
    if (_db == null) return null;
    try {
      final res = await _db!.rpc('poll_pvp_room', params: {
        'p_room_id': roomId,
        'p_player_id': playerId,
      });
      if (res is Map && res['id'] is String) {
        return PvpRoomState.fromMap(res.cast<String, dynamic>());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<PvpRoomState?> updatePvpProgress({
    required String roomId,
    required String playerId,
    required int score,
    required int step,
  }) async {
    if (_db == null) return null;
    try {
      final res = await _db!.rpc('update_pvp_progress', params: {
        'p_room_id': roomId,
        'p_player_id': playerId,
        'p_score': score,
        'p_step': step,
      });
      if (res is Map && res['id'] is String) {
        return PvpRoomState.fromMap(res.cast<String, dynamic>());
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
