import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 't21_api.dart';

/// 3-2-1 maç kuralları. Turnuva da aynı kuralları kullanır; sayılar ayarlanabilir.
@immutable
class T21Rules {
  const T21Rules({
    this.winTarget = 3,
    this.regularQuestions = 5,
    this.answerSeconds = 12,
    this.countdownSeconds = 3,
    this.maxGolden = 3,
    this.maxDifficulty = 1,
  });

  /// İlk bu kadar doğruya ulaşan maçı kazanır.
  final int winTarget;

  /// Normal soru sayısı; sonunda eşitlik varsa altın soru(lar).
  final int regularQuestions;
  final int answerSeconds;
  final int countdownSeconds;

  /// Kimse bilemezse en fazla kaç altın soru sorulur (sonra beraberlik/tiebreak).
  final int maxGolden;
  final int maxDifficulty;

  int get questionsNeeded => regularQuestions + maxGolden;
}

enum T21Phase {
  loading,
  intro,
  countdown,
  answering,
  questionResult,
  finished,
  error,
}

enum T21Side { me, opponent }

/// Oyuncuya o anki cevabı hakkında gösterilen geri bildirim.
@immutable
class T21Feedback {
  const T21Feedback(this.verdict, {this.name});

  final T21Verdict verdict;
  final String? name;
}

/// Rakip: bot, online oyuncu veya turnuva rakibi. Maç motoru rakibin türünü bilmez.
abstract class T21Opponent {
  String get name;
  bool get isBot;

  /// Cevap süresi başladığında çağrılır. Rakip, cevabını [T21Match.opponentAttempt] ile bildirir.
  void onAnswering(T21Match match, T21Question question);

  /// Soru bittiğinde (puan verildi ya da süre doldu).
  void onQuestionEnd();

  void dispose();
}

/// Test (pratik) rakibi: soruların bir kısmını bilir, rastgele bir sürede cevaplar.
class T21BotOpponent implements T21Opponent {
  T21BotOpponent({required this.name, this.skill = 0.5, int? seed})
    : _rng = Random(seed);

  @override
  final String name;

  /// 0..1: bir soruyu bilme olasılığı.
  final double skill;
  final Random _rng;
  Timer? _timer;

  @override
  bool get isBot => true;

  @override
  void onAnswering(T21Match match, T21Question question) {
    _timer?.cancel();
    final limit = match.rules.answerSeconds;
    final knows = _rng.nextDouble() < skill;
    final wrongFirst = !knows && _rng.nextDouble() < 0.35;
    if (!knows && !wrongFirst) return; // bu soruyu bilmiyor, hiç cevap vermez
    final delayMs = (2500 + _rng.nextDouble() * (limit - 3.5) * 1000).round();
    _timer = Timer(Duration(milliseconds: delayMs), () async {
      if (!match.isAnswering || match.question != question) return;
      if (wrongFirst) {
        match.opponentAttempt(correct: false, name: 'yanlış bir isim');
        return;
      }
      final answers = await T21Api.reveal(question.pairId, limit: 8);
      final pick = answers
          .where((a) => !match.usedPlayerIds.contains(a.id))
          .firstOrNull;
      if (!match.isAnswering || match.question != question) return;
      if (pick == null) return;
      match.opponentAttempt(correct: true, playerId: pick.id, name: pick.name);
    });
  }

  @override
  void onQuestionEnd() => _timer?.cancel();

  @override
  void dispose() => _timer?.cancel();
}

/// 3-2-1 maç motoru. Ekrandan bağımsızdır; pratik, online 1'e 1 ve 32 kişilik
/// turnuvanın her eşleşmesi bu motoru kullanır (rakip türü değişir).
class T21Match extends ChangeNotifier {
  T21Match({
    required this.opponent,
    this.rules = const T21Rules(),
    this.label = 'PRATİK MAÇI',
    List<T21Question>? questions,
  }) : _preset = questions;

  final T21Opponent opponent;
  final T21Rules rules;

  /// Üstte gösterilen etiket (ör. "SON 32 • MAÇ 4").
  final String label;
  final List<T21Question>? _preset;

  T21Phase phase = T21Phase.loading;
  List<T21Question> _questions = const [];
  int index = 0;
  int myScore = 0;
  int opponentScore = 0;
  int countdown = 0;
  bool myLocked = false;
  bool opponentLocked = false;
  bool _judging = false;

  /// Her sorunun sonucu (kim aldı; null = kimse) — skor noktaları için.
  final List<T21Side?> results = [];

  /// Bu maçta doğru kabul edilmiş futbolcular (tekrar edilemez).
  final Set<int> usedPlayerIds = {};

  T21Feedback? myFeedback;
  String? opponentStatus;

  /// Soru sonucu: kim bildi, hangi isimle, diğer doğru cevaplar.
  T21Side? questionWinner;
  String? winningName;
  List<String> otherAnswers = const [];

  /// Maç sonucu (finished): kazanan; null = berabere.
  T21Side? matchWinner;

  final ValueNotifier<double> timeLeft = ValueNotifier(0);
  Timer? _ticker;
  Timer? _step;
  final Stopwatch _clock = Stopwatch();
  bool _disposed = false;

  T21Question? get question =>
      (index < _questions.length) ? _questions[index] : null;
  bool get isAnswering => phase == T21Phase.answering;
  bool get isGolden => index >= rules.regularQuestions;
  int get goldenNumber => index - rules.regularQuestions + 1;

  Future<void> start() async {
    phase = T21Phase.loading;
    _notify();
    _questions =
        _preset ??
        await T21Api.pickQuestions(
          count: rules.questionsNeeded,
          maxDifficulty: rules.maxDifficulty,
        );
    if (_disposed) return;
    if (_questions.length < rules.regularQuestions) {
      phase = T21Phase.error;
      _notify();
      return;
    }
    phase = T21Phase.intro;
    _notify();
    _later(const Duration(milliseconds: 2600), _beginQuestion);
  }

  void _beginQuestion() {
    myLocked = false;
    opponentLocked = false;
    myFeedback = null;
    opponentStatus = null;
    questionWinner = null;
    winningName = null;
    otherAnswers = const [];
    countdown = rules.countdownSeconds;
    phase = T21Phase.countdown;
    _notify();
    _tickCountdown();
  }

  void _tickCountdown() {
    _later(const Duration(seconds: 1), () {
      countdown--;
      if (countdown > 0) {
        _notify();
        _tickCountdown();
      } else {
        _startAnswering();
      }
    });
  }

  void _startAnswering() {
    phase = T21Phase.answering;
    timeLeft.value = rules.answerSeconds.toDouble();
    _clock
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final left = rules.answerSeconds - _clock.elapsedMilliseconds / 1000;
      if (left <= 0) {
        timeLeft.value = 0;
        _endQuestion(null);
      } else {
        timeLeft.value = left;
      }
    });
    _notify();
    opponent.onAnswering(this, question!);
  }

  /// Oyuncunun cevabı. [said]: ses tanımanın tahminleri ya da yazılan metin.
  Future<T21Feedback?> submit(List<String> said) async {
    final q = question;
    if (!isAnswering || myLocked || _judging || q == null) return null;
    _judging = true;
    final j = await T21Api.judge(
      pairId: q.pairId,
      said: said,
      used: usedPlayerIds.toList(),
    );
    _judging = false;
    if (_disposed || !isAnswering || question != q) return null;
    final fb = T21Feedback(j.verdict, name: j.playerName);
    myFeedback = fb;
    switch (j.verdict) {
      case T21Verdict.correct:
        if (j.playerId != null) usedPlayerIds.add(j.playerId!);
        _endQuestion(T21Side.me, name: j.playerName);
        return fb;
      case T21Verdict.wrong:
        myLocked = true;
        if (opponentLocked) _endQuestion(null);
      case T21Verdict.repeat:
      case T21Verdict.unknown:
        break;
    }
    _notify();
    return fb;
  }

  /// Rakibin cevabı (bot, online oyuncu ya da turnuva sunucusu bildirir).
  void opponentAttempt({required bool correct, int? playerId, String? name}) {
    if (!isAnswering || opponentLocked) return;
    if (correct) {
      if (playerId != null) usedPlayerIds.add(playerId);
      _endQuestion(T21Side.opponent, name: name);
      return;
    }
    opponentLocked = true;
    opponentStatus = 'Rakip yanlış cevap verdi, kilitlendi';
    if (myLocked) {
      _endQuestion(null);
    } else {
      _notify();
    }
  }

  void _endQuestion(T21Side? winner, {String? name}) {
    if (phase != T21Phase.answering) return;
    _ticker?.cancel();
    _clock.stop();
    opponent.onQuestionEnd();
    questionWinner = winner;
    winningName = name;
    results.add(winner);
    if (winner == T21Side.me) myScore++;
    if (winner == T21Side.opponent) opponentScore++;
    phase = T21Phase.questionResult;
    _notify();
    final q = question!;
    T21Api.reveal(q.pairId).then((list) {
      if (_disposed || question != q) return;
      otherAnswers = [
        for (final a in list)
          if (a.name != name) a.name,
      ].take(4).toList();
      _notify();
    });
    _later(const Duration(milliseconds: 3800), _afterQuestion);
  }

  void _afterQuestion() {
    final decided =
        myScore >= rules.winTarget || opponentScore >= rules.winTarget;
    final golden = isGolden;
    if (golden && questionWinner != null) {
      return _finish(questionWinner);
    }
    if (decided) {
      return _finish(myScore > opponentScore ? T21Side.me : T21Side.opponent);
    }
    final next = index + 1;
    if (next < rules.regularQuestions) {
      index = next;
      return _beginQuestion();
    }
    // Normal sorular bitti.
    if (!golden && myScore != opponentScore) {
      return _finish(myScore > opponentScore ? T21Side.me : T21Side.opponent);
    }
    if (next < _questions.length && next < rules.questionsNeeded) {
      index = next; // altın soru
      return _beginQuestion();
    }
    _finish(null); // altın sorularda da kimse bilemedi: berabere
  }

  void _finish(T21Side? winner) {
    matchWinner = winner;
    phase = T21Phase.finished;
    _notify();
  }

  void _later(Duration d, VoidCallback f) {
    _step?.cancel();
    _step = Timer(d, () {
      if (!_disposed) f();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _step?.cancel();
    opponent.dispose();
    timeLeft.dispose();
    super.dispose();
  }
}
