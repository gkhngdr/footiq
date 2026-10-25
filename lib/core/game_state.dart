import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';

/// Oyuncunun tüm ilerlemesi. Cihazda SharedPreferences ile saklanır ve
/// hesapla giriş yapıldığında Supabase ile senkronize edilir.
class GameState extends ChangeNotifier with WidgetsBindingObserver {
  GameState._();
  static final GameState instance = GameState._();

  bool _observerAttached = false;

  static const int maxEnergy = 6;
  static const Duration energyRegen = Duration(minutes: 20);
  static const int chapterCount = 4;
  static const int levelsPerChapter = 10;
  static const List<int> dailyRewards = [20, 30, 50, 50, 50, 150, 200];
  static const int giftGoal = 7;
  static const int giftReward = 100;

  static const _key = 'footiq_state_v1';
  SharedPreferences? _prefs;

  bool loggedIn = false;
  String playerId = _generateId();
  String playerName = 'Misafir';
  int trophies = 0;
  int coins = 500;
  bool soundOn = true;

  int _energy = maxEnergy;
  DateTime _energyStamp = DateTime.now();

  /// "bölüm-seviye" -> yıldız (1..3). Kayıt yoksa seviye geçilmemiştir.
  final Map<String, int> _stars = {};

  int _dailyStreak = 0;
  String? _lastDailyClaim;

  int _giftProgress = 0;
  bool _guestInviteUsed = false;

  static String _generateId() {
    final rng = Random();
    const chars = 'abcdef0123456789';
    return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Sezon ligindeki sabit rakipler (sıralama tablosu ve yerel Rank hesabı için).
  static const List<({String name, int trophies})> seasonRivals = [
    (name: 'EfsaneKaptan10', trophies: 420),
    (name: 'ŞampiyonlarKralı', trophies: 360),
    (name: 'GolMakinesi9', trophies: 310),
    (name: 'TaktikDehası', trophies: 265),
    (name: 'PanenkaUstası', trophies: 220),
    (name: 'BoğazınBoğası', trophies: 185),
    (name: 'TrivelaQuaresma', trophies: 150),
    (name: 'KadıköyBoğası', trophies: 120),
    (name: 'AslanYürek1905', trophies: 95),
    (name: 'KaraKartal1903', trophies: 75),
    (name: 'Fırtına61', trophies: 55),
    (name: 'AltınAyakkabı', trophies: 40),
    (name: 'Maestro8', trophies: 25),
    (name: 'YeşilSaha34', trophies: 15),
    (name: 'ÇaylakForvet', trophies: 5),
  ];

  /// Oyuncunun kupa sayısına göre sezon içindeki sırası (#1 ve üzeri).
  int get displayRank {
    if (rank != null && rank! > 0) return rank!;
    final ahead = seasonRivals.where((r) => r.trophies > trophies).length;
    return ahead + 1;
  }

  /// Oyuncunun cihaz kimliğinden türetilen 8 karakterlik davet kodu.
  String get localInviteCode => playerId.substring(0, 8).toUpperCase();

  bool get guestInviteUsed => _guestInviteUsed;

  Future<void> load() async {
    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      loggedIn = m['loggedIn'] as bool? ?? false;
      final savedId = m['playerId'] as String?;
      if (savedId != null && savedId.length >= 8) playerId = savedId;
      // Hesaplı oturum yalnızca Supabase oturumu hâlâ geçerliyse sürer.
      isAccount = loggedIn && Cloud.signedIn;
      if (loggedIn && !isAccount && !(m['playerName'] as String? ?? '').startsWith('Misafir')) loggedIn = false;
      playerName = m['playerName'] as String? ?? 'Misafir';
      trophies = (m['trophies'] as int? ?? 0).clamp(0, 1000000);
      coins = (m['coins'] as int? ?? 500).clamp(0, 100000000);
      soundOn = m['soundOn'] as bool? ?? true;
      _energy = (m['energy'] as int? ?? maxEnergy).clamp(0, maxEnergy);
      _energyStamp = DateTime.tryParse(m['energyStamp'] as String? ?? '') ?? DateTime.now();
      _stars
        ..clear()
        ..addAll((m['stars'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v is int ? v.clamp(0, 3) : 0))
          ..removeWhere((k, v) => v == 0 || !RegExp(r'^[1-4]-([1-9]|10)$').hasMatch(k)));
      _dailyStreak = (m['dailyStreak'] as int? ?? 0).clamp(0, 3650);
      _lastDailyClaim = m['lastDailyClaim'] as String?;
      _giftProgress = (m['giftProgress'] as int? ?? 0).clamp(0, giftGoal);
      _guestInviteUsed = m['guestInviteUsed'] as bool? ?? false;
    } catch (_) {
      // Bozuk kayıt: varsayılanlarla devam.
    }
  }

  /// Cihaza ve buluta yazılan oyun verisi.
  Map<String, dynamic> toMap() => {
        'loggedIn': loggedIn,
        'playerId': playerId,
        'playerName': playerName,
        'trophies': trophies,
        'coins': coins,
        'soundOn': soundOn,
        'energy': _energy,
        'energyStamp': _energyStamp.toIso8601String(),
        'stars': _stars,
        'dailyStreak': _dailyStreak,
        'lastDailyClaim': _lastDailyClaim,
        'giftProgress': _giftProgress,
        'guestInviteUsed': _guestInviteUsed,
      };

  Timer? _cloudTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Uygulama arka plana alındığında bekleyen bulut kaydını anında gönder.
      if (_cloudTimer?.isActive ?? false) {
        _cloudTimer?.cancel();
        if (isAccount) Cloud.pushProfile();
      }
    }
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode(toMap()));
    notifyListeners();
    // Hesaplı oyuncularda değişiklikleri kısa gecikmeyle buluta gönder.
    if (isAccount) {
      _cloudTimer?.cancel();
      _cloudTimer = Timer(const Duration(seconds: 3), Cloud.pushProfile);
    }
  }

  // ---------------------------------------------------------------- hesap

  /// Misafir değil, e-posta hesabıyla giriş yapılmış mı.
  bool isAccount = false;

  /// Oyuncunun sıralaması (hesaplı ise buluttan gelir).
  int? rank;

  void loginAsGuest() {
    loggedIn = true;
    isAccount = false;
    if (playerName == 'Misafir' || playerName.isEmpty) {
      playerName = 'Misafir${Random().nextInt(9000) + 1000}';
    }
    _save();
  }

  void setAccount(String name) {
    loggedIn = true;
    isAccount = true;
    playerName = name;
    _save();
  }

  void updatePlayerName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 3 || trimmed.length > 20) return;
    playerName = trimmed;
    _save();
  }

  /// Buluttaki profili cihaza uygular. Kupa/coin için büyük olan korunur,
  /// seviye yıldızları birleştirilir (veri kaybı olmasın).
  void applyCloud(Map<String, dynamic> row) {
    final p = (row['progress'] as Map?)?.cast<String, dynamic>() ?? {};
    loggedIn = true;
    isAccount = true;
    playerName = row['username'] as String? ?? playerName;
    trophies = max(trophies, row['trophies'] as int? ?? trophies);
    coins = max(coins, row['coins'] as int? ?? coins);
    soundOn = p['soundOn'] as bool? ?? soundOn;
    _energy = (p['energy'] as int? ?? _energy).clamp(0, maxEnergy);
    _energyStamp = DateTime.tryParse(p['energyStamp'] as String? ?? '') ?? _energyStamp;
    final cloudStars = (p['stars'] as Map?)?.cast<String, dynamic>() ?? {};
    cloudStars.forEach((k, v) {
      if (v is int && RegExp(r'^[1-4]-([1-9]|10)$').hasMatch(k) && v.clamp(1, 3) > (_stars[k] ?? 0)) {
        _stars[k] = v.clamp(1, 3);
      }
    });
    _dailyStreak = max(_dailyStreak, p['dailyStreak'] as int? ?? 0);
    final cloudClaim = p['lastDailyClaim'] as String?;
    if (cloudClaim != null) _lastDailyClaim = cloudClaim;
    _giftProgress = (p['giftProgress'] as int? ?? _giftProgress).clamp(0, giftGoal);
    _prefs?.setString(_key, jsonEncode(toMap()));
    notifyListeners();
  }

  Future<void> refreshRank() async {
    if (!isAccount) return;
    rank = await Cloud.myRank();
    notifyListeners();
  }

  void logout() {
    _cloudTimer?.cancel();
    Cloud.signOut();
    loggedIn = false;
    isAccount = false;
    rank = null;
    _save();
  }

  void toggleSound() {
    soundOn = !soundOn;
    _save();
  }

  void resetProgress() {
    trophies = 0;
    coins = 500;
    _energy = maxEnergy;
    _energyStamp = DateTime.now();
    _stars.clear();
    _dailyStreak = 0;
    _lastDailyClaim = null;
    _giftProgress = 0;
    _guestInviteUsed = false;
    rank = null;
    _save();
  }

  bool redeemGuestInvite(String code) {
    final clean = code.trim().toUpperCase();
    if (_guestInviteUsed) return false;
    if (clean.length != 8 || clean == localInviteCode) return false;
    _guestInviteUsed = true;
    coins += 500;
    _save();
    return true;
  }

  // ---------------------------------------------------------------- enerji

  /// Bekleyen enerji yenilemelerini uygular.
  void _tickEnergy() {
    if (_energy >= maxEnergy) {
      _energyStamp = DateTime.now();
      return;
    }
    final gained = DateTime.now().difference(_energyStamp).inSeconds ~/ energyRegen.inSeconds;
    if (gained > 0) {
      _energy = min(maxEnergy, _energy + gained);
      _energyStamp = _energyStamp.add(energyRegen * gained);
      if (_energy >= maxEnergy) _energyStamp = DateTime.now();
    }
  }

  int get energy {
    _tickEnergy();
    return _energy;
  }

  /// Bir sonraki enerjiye kalan süre (enerji doluysa null).
  Duration? get nextEnergyIn {
    _tickEnergy();
    if (_energy >= maxEnergy) return null;
    return energyRegen - DateTime.now().difference(_energyStamp);
  }

  bool useEnergy() {
    _tickEnergy();
    if (_energy <= 0) return false;
    if (_energy == maxEnergy) _energyStamp = DateTime.now();
    _energy--;
    _save();
    return true;
  }

  void addEnergy(int n) {
    _tickEnergy();
    _energy = min(maxEnergy, _energy + n);
    _save();
  }

  // ---------------------------------------------------------------- para / kupa

  void addCoins(int n) {
    coins = max(0, coins + n);
    _save();
  }

  void addTrophies(int n) {
    trophies = max(0, trophies + n);
    _save();
  }

  // ---------------------------------------------------------------- seviyeler

  int stars(int chapter, int level) => _stars['$chapter-$level'] ?? 0;

  int chapterStars(int chapter) =>
      List.generate(levelsPerChapter, (i) => stars(chapter, i + 1)).fold(0, (a, b) => a + b);

  bool isLevelPassed(int chapter, int level) => stars(chapter, level) > 0;

  bool isChapterCompleted(int chapter) =>
      List.generate(levelsPerChapter, (i) => isLevelPassed(chapter, i + 1)).every((p) => p);

  bool isChapterUnlocked(int chapter) => chapter == 1 || isChapterCompleted(chapter - 1);

  bool isLevelUnlocked(int chapter, int level) =>
      isChapterUnlocked(chapter) && (level == 1 || isLevelPassed(chapter, level - 1));

  /// Seviye sonucunu kaydeder; yalnızca yeni kazanılan yıldızlar kupa verir.
  /// Dönen değer: kazanılan kupa sayısı.
  int completeLevel(int chapter, int level, int newStars, int earnedCoins) {
    final old = stars(chapter, level);
    final gainedTrophies = max(0, newStars - old) * 5;
    if (newStars > old) _stars['$chapter-$level'] = newStars;
    trophies += gainedTrophies;
    coins += earnedCoins;
    _giftProgress = min(giftGoal, _giftProgress + 1);
    _save();
    return gainedTrophies;
  }

  // ---------------------------------------------------------------- oynadıkça kazan

  int get giftProgress => _giftProgress;

  bool get giftReady => _giftProgress >= giftGoal;

  void claimGift() {
    if (!giftReady) return;
    _giftProgress = 0;
    coins += giftReward;
    _save();
  }

  void countGame() {
    _giftProgress = min(giftGoal, _giftProgress + 1);
    _save();
  }

  // ---------------------------------------------------------------- günlük ödül

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool get canClaimDaily => _lastDailyClaim != _day(DateTime.now());

  /// Bugün alınacak ödülün sırası (0..6).
  int get dailyIndex {
    if (!canClaimDaily) return (_dailyStreak - 1) % 7;
    final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastDailyClaim == yesterday) return _dailyStreak % 7;
    return 0;
  }

  /// Bu döngüde alınmış ödüllerin sayısı (ekrandaki tik işaretleri).
  int get dailyClaimedInCycle {
    if (!canClaimDaily) return ((_dailyStreak - 1) % 7) + 1;
    return dailyIndex;
  }

  int claimDaily({int multiplier = 1}) {
    if (!canClaimDaily) return 0;
    final index = dailyIndex;
    final reward = dailyRewards[index] * multiplier;
    _dailyStreak = index + 1;
    _lastDailyClaim = _day(DateTime.now());
    coins += reward;
    _save();
    return reward;
  }
}
