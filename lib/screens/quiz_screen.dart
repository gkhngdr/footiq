import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/sound.dart';
import '../core/ui.dart';
import '../data/questions.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';
import 'result_dialog.dart';

/// Soru ekranı. Tek oyunculu modda seviyeye özel ve kademeli zorlaşan soru dilimiyle,
/// PVP modunda ise ortak [seed] üzerinden iki oyuncunun birebir aynı soruları
/// ve aynı şık sırasını eşzamanlı görmesini sağlayacak şekilde çalışır.
class QuizScreen extends StatefulWidget {
  const QuizScreen.single({super.key, required int this.chapter, required int this.level}) : category = null;

  const QuizScreen.pvp({super.key, required PvpCategory this.category})
      : chapter = null,
        level = null;

  final int? chapter;
  final int? level;
  final PvpCategory? category;

  bool get isPvp => category != null;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

const _questionCount = 5;
const _timeLimit = 15;
const _botNames = [
  'GolKralı34',
  'Kaleci_Kemal',
  'FutbolDahisi',
  'OfsaytAvcısı',
  'TribünSesi',
  'Forvet07',
  'KornerUstası',
  'Libero61',
];

class _QuizScreenState extends State<QuizScreen> {
  final _rng = Random();
  final _state = GameState.instance;

  late List<Question> _questions;
  late List<String> _options;
  late int _correctIndex;
  late int _matchSeed;

  int _index = 0;
  int _correctCount = 0;
  int? _selected;
  bool _revealed = false;
  int _lastTickSec = _timeLimit;

  Timer? _timer;
  Timer? _pvpPollTimer;
  final Stopwatch _clock = Stopwatch();

  /// Yalnızca süre çubuğunun saniyede 10 kez yeniden çizilmesi için izole sayaç.
  final ValueNotifier<double> _timeLeft = ValueNotifier<double>(_timeLimit.toDouble());

  // PVP (gerçek oyuncu veya bot fallback)
  late String _opponentName = _botNames[_rng.nextInt(_botNames.length)];
  String? _roomId;
  bool _onlineOpponent = false;
  bool _waitingForOpponent = false;
  int _myScore = 0;
  int _opponentScore = 0;
  int _opponentStep = 0;
  final ValueNotifier<bool> _opponentAnsweredCurrent = ValueNotifier<bool>(false);
  late double _botTime;
  late bool _botCorrect;
  bool _matching = false;

  @override
  void initState() {
    super.initState();
    // Dinleyen ekranlar build sırasında yenilenmesin diye ilk kareden sonra düş.
    WidgetsBinding.instance.addPostFrameCallback((_) => _state.useEnergy());
    _matchSeed = _rng.nextInt(1 << 30);
    if (widget.isPvp) {
      _questions = pickSeededPvpQuestions(widget.category!, _questionCount, _matchSeed);
      _matching = true;
      _initPvpMatchmaking();
    } else {
      _questions = pickLevelQuestions(widget.chapter!, widget.level!, _questionCount, _rng);
      _startQuestion();
    }
  }

  Future<void> _initPvpMatchmaking() async {
    final minWait = Future<void>.delayed(const Duration(milliseconds: 1400));
    final room = await Cloud.joinOrCreatePvp(
      category: widget.category!,
      playerId: _state.playerId,
      playerName: _state.playerName,
      seed: _matchSeed,
    );
    if (room != null) {
      _roomId = room.id;
      _matchSeed = room.seed;
      // Ortak seed ile her iki oyuncu birebir aynı 5 soruyu aynı sırada görür.
      _questions = pickSeededPvpQuestions(widget.category!, _questionCount, _matchSeed);
      if (room.isMatched) {
        _onlineOpponent = true;
        _opponentName = room.opponentName(_state.playerId);
        if (mounted) setState(() {});
      } else {
        // Gerçek bir oyuncunun odaya katılmasını bekle (eşzamanlı başlangıç için)
        for (var i = 0; i < 4 && mounted && !_onlineOpponent; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final polled = await Cloud.pollPvpRoom(roomId: room.id, playerId: _state.playerId);
          if (polled != null && polled.isMatched) {
            _onlineOpponent = true;
            _opponentName = polled.opponentName(_state.playerId);
            if (mounted) setState(() {});
            await Future<void>.delayed(const Duration(milliseconds: 350));
            break;
          }
        }
      }
    }
    await minWait;
    if (!mounted) return;
    Sound.matchFound();
    setState(() => _matching = false);
    if (_roomId != null) {
      _pvpPollTimer = Timer.periodic(const Duration(milliseconds: 600), (_) => _pollOnlineOpponent());
    }
    _startQuestion();
  }

  Future<void> _pollOnlineOpponent() async {
    final roomId = _roomId;
    if (roomId == null || !mounted) return;
    final room = await Cloud.pollPvpRoom(roomId: roomId, playerId: _state.playerId);
    if (room == null || !mounted) return;
    if (room.isMatched && !_onlineOpponent) {
      _onlineOpponent = true;
      _opponentName = room.opponentName(_state.playerId);
    }
    if (!_onlineOpponent) return;
    final opScore = room.opponentScore(_state.playerId);
    final opStep = room.opponentStep(_state.playerId);
    _opponentAnsweredCurrent.value = opStep > _index;
    if (opScore != _opponentScore || opStep != _opponentStep) {
      setState(() {
        _opponentScore = opScore;
        _opponentStep = opStep;
      });
    }
  }

  void _startQuestion() {
    // PVP'de şıkların sırası da ortak seed ile belirlenir: iki ekran birebir aynıdır.
    final optionRng = widget.isPvp ? Random(_matchSeed * 31 + _index + 7) : _rng;
    final (opts, correct) = _questions[_index].shuffled(optionRng);
    _options = opts;
    _correctIndex = correct;
    _selected = null;
    _revealed = false;
    _waitingForOpponent = false;
    _lastTickSec = _timeLimit;
    _timeLeft.value = _timeLimit.toDouble();
    _opponentAnsweredCurrent.value = _onlineOpponent && _opponentStep > _index;
    final botRng = Random(_matchSeed * 17 + _index + 3);
    _botTime = 2.5 + botRng.nextDouble() * 8.5;
    _botCorrect = botRng.nextDouble() < 0.6;
    _clock
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final left = _timeLimit - _clock.elapsedMilliseconds / 1000;
      if (left <= 0) {
        _answer(null);
      } else {
        _timeLeft.value = left;
        final sec = left.ceil();
        if (sec <= 5 && sec < _lastTickSec) {
          _lastTickSec = sec;
          Sound.tick();
        }
        if (widget.isPvp && !_onlineOpponent && _clock.elapsedMilliseconds / 1000 >= _botTime) {
          _opponentAnsweredCurrent.value = true;
        }
      }
    });
    setState(() {});
  }

  Future<void> _answer(int? choice) async {
    if (_revealed) return;
    _timer?.cancel();
    _clock.stop();
    final remainingSec = _timeLeft.value;
    final correct = choice == _correctIndex;
    if (choice == null) {
      Sound.timeout();
    } else if (correct) {
      Sound.correct();
    } else {
      Sound.wrong();
    }
    if (correct) {
      _correctCount++;
      _myScore += 100 + (remainingSec * 10).round();
    }
    if (widget.isPvp && !_onlineOpponent) {
      _opponentAnsweredCurrent.value = true;
      if (_botCorrect && _botTime < _timeLimit) {
        _opponentScore += 100 + ((_timeLimit - _botTime) * 10).round();
      }
    }
    setState(() {
      _selected = choice;
      _revealed = true;
    });

    final minReveal = Future<void>.delayed(const Duration(milliseconds: 1300));

    if (widget.isPvp && _roomId != null) {
      final updated = await Cloud.updatePvpProgress(
        roomId: _roomId!,
        playerId: _state.playerId,
        score: _myScore,
        step: _index + 1,
      );
      if (updated != null && mounted) {
        if (updated.isMatched && !_onlineOpponent) {
          _onlineOpponent = true;
          _opponentName = updated.opponentName(_state.playerId);
        }
        if (_onlineOpponent) {
          setState(() {
            _opponentScore = updated.opponentScore(_state.playerId);
            _opponentStep = updated.opponentStep(_state.playerId);
            _opponentAnsweredCurrent.value = _opponentStep > _index;
          });
        }
      }

      // Online PVP'de iki oyuncunun da her soruyu eşzamanlı görmesi ve bir sonraki
      // soruya birlikte geçmesi için rakibin de mevcut soruyu cevaplamasını bekle.
      if (_onlineOpponent && _opponentStep < _index + 1 && mounted) {
        setState(() => _waitingForOpponent = true);
        final maxPolls = ((remainingSec + 2.5) * 2.5).ceil().clamp(2, 42);
        for (var i = 0; i < maxPolls && mounted && _opponentStep < _index + 1; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          await _pollOnlineOpponent();
        }
        if (mounted) setState(() => _waitingForOpponent = false);
      }
    }

    await minReveal;
    if (!mounted) return;
    if (_index + 1 < _questions.length) {
      _index++;
      _startQuestion();
    } else {
      _finish();
    }
  }

  void _finish() {
    _pvpPollTimer?.cancel();
    if (widget.isPvp) {
      final outcome = _myScore.compareTo(_opponentScore);
      final rawTrophies = outcome > 0 ? 15 : (outcome == 0 ? 5 : -5);
      final beforeTrophies = _state.trophies;
      _state.addTrophies(rawTrophies);
      // Oyuncunun kupası 0 iken kaybettiğinde -5 yerine gerçek değişimi (0) göster.
      final actualTrophies = _state.trophies - beforeTrophies;
      final coins = outcome > 0 ? 5000 : (outcome == 0 ? 1000 : 0);
      _state.addCoins(coins);
      _state.countGame();
      if (outcome >= 0) {
        Sound.win();
      } else {
        Sound.lose();
      }
      showPvpResult(
        context,
        outcome: outcome,
        myScore: _myScore,
        botScore: _opponentScore,
        botName: _opponentName,
        trophies: actualTrophies,
        coins: coins,
        onReplay: () => _replace(QuizScreen.pvp(category: widget.category!)),
      );
    } else {
      final stars = switch (_correctCount) { 5 => 3, 4 => 2, 3 => 1, _ => 0 };
      final coins = _correctCount * 10 + stars * 10;
      final trophies = _state.completeLevel(widget.chapter!, widget.level!, stars, coins);
      if (stars > 0) {
        Sound.win();
      } else {
        Sound.lose();
      }
      final hasNextLevel = widget.level! < GameState.levelsPerChapter;
      final hasNextChapter = widget.level! == GameState.levelsPerChapter && widget.chapter! < GameState.chapterCount;
      showLevelResult(
        context,
        stars: stars,
        correct: _correctCount,
        total: _questions.length,
        coins: coins,
        trophies: trophies,
        nextLabel: hasNextLevel ? 'Sonraki Seviye' : 'Sonraki Bölüm',
        onReplay: () => _replace(QuizScreen.single(chapter: widget.chapter!, level: widget.level!)),
        onNext: stars > 0 && (hasNextLevel || hasNextChapter)
            ? () => _replace(
                  hasNextLevel
                      ? QuizScreen.single(chapter: widget.chapter!, level: widget.level! + 1)
                      : QuizScreen.single(chapter: widget.chapter! + 1, level: 1),
                )
            : null,
      );
    }
  }

  void _replace(Widget next) {
    if (_state.energy <= 0) {
      promptRefillEnergy(context, onRefilled: () {
        if (mounted) goStage(context, next, replace: true);
      });
      return;
    }
    goStage(context, next, replace: true);
  }

  Future<void> _quit() async {
    final leave = await showStageConfirm(
      context,
      title: 'Oyundan Çık',
      message: 'Oyundan çıkarsan harcanan enerji geri gelmez. Çıkmak istiyor musun?',
      confirmLabel: 'Çık',
      cancelLabel: 'Devam Et',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pvpPollTimer?.cancel();
    _timeLeft.dispose();
    _opponentAnsweredCurrent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPvp ? 'bg_pvp.png' : 'chapter${widget.chapter}.png';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: _matching ? _buildMatching(bg) : _buildQuiz(bg),
    );
  }

  Widget _buildMatching(String bg) {
    return Stage(background: bg, backgroundBlur: 10, children: [
      at(0, 0, kDesignW, kDesignH, const ColoredBox(color: Color(0x99000000))),
      at(923, 80, 116.715, 116.715, CloseBtn(onTap: _quit)),
      ..._matchmaking(),
    ]);
  }

  Widget _buildQuiz(String bg) {
    // PVP modunda üstte skor tablosu olduğu için içerik aşağı kayar.
    final pvp = widget.isPvp;
    final currentQ = _questions[_index];
    final dotsY = pvp ? 440.0 : 250.0;
    final cardY = pvp ? 590.0 : 410.0;
    final cardH = pvp ? 400.0 : 500.0;
    final optionsY = pvp ? 1020.0 : 960.0;
    final optionGap = pvp ? 182.0 : 192.0;
    final optionH = pvp ? 156.0 : 164.0;
    return Stage(background: bg, backgroundBlur: 10, children: [
      at(0, 0, kDesignW, kDesignH, const ColoredBox(color: Color(0x73000000))),
      at(923, 80, 116.715, 116.715, CloseBtn(onTap: _quit)),
      if (widget.isPvp) ..._scoreboard() else ..._levelHeader(currentQ),
      // İlerleme noktaları
      for (var i = 0; i < _questions.length; i++)
        at(40 + i * 64.0, dotsY, 48, 48, DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: i < _index
                ? const Color(0xFF63D998)
                : i == _index
                    ? const Color(0xFFF68537)
                    : const Color(0x33FFFFFF),
          ),
        )),
      Positioned(
        right: 40,
        top: dotsY - 2,
        child: Text(
          'Soru ${_index + 1}/${_questions.length}  •  ${currentQ.difficultyLabel} (${currentQ.difficulty}/10)',
          style: londrina(38, shadows: kTextShadow),
        ),
      ),
      // Süre çubuğu (izole ValueListenableBuilder: tüm ekranı yeniden çizmez)
      at(40, dotsY + 80, 1000, 56, ValueListenableBuilder<double>(
        valueListenable: _timeLeft,
        builder: (_, left, _) => _TimerBar(value: left / _timeLimit, seconds: left.ceil()),
      )),
      // Soru kartı (soru değişiminde yumuşak geçiş)
      at(40, cardY, 1000, cardH, RepaintBoundary(
        child: GlassBox(
          radius: 40,
          blur: 10,
          borderWidth: 6,
          color: const Color(0x99102A22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  currentQ.text,
                  key: ValueKey<int>(_index),
                  textAlign: TextAlign.center,
                  style: exo(currentQ.text.length > 110 ? 44 : 52, weight: 700, shadows: kTextShadow),
                ),
              ),
            ),
          ),
        ),
      )),
      for (var i = 0; i < _options.length; i++)
        at(90, optionsY + i * optionGap, 900, optionH, _OptionButton(
          letter: String.fromCharCode(65 + i),
          text: _options[i],
          state: !_revealed
              ? _OptionState.idle
              : i == _correctIndex
                  ? _OptionState.correct
                  : i == _selected
                      ? _OptionState.wrong
                      : _OptionState.dim,
          onTap: () => _answer(i),
        )),
      if (_revealed && _selected == null)
        at(0, 1805, kDesignW, 70, centerText('Süre doldu!', londrina(52, color: const Color(0xFFFFB199), shadows: kTextShadow)))
      else if (_waitingForOpponent)
        at(0, 1805, kDesignW, 70, centerText('Rakibin cevabı bekleniyor...', exo(36, weight: 700, color: const Color(0xFF9BE7FF), shadows: kTextShadow))),
    ]);
  }

  List<Widget> _levelHeader(Question currentQ) => [
        at(40, 96, 560, 100, GlassBox(
          radius: 100,
          color: const Color(0x88111111),
          borderWidth: 3,
          child: centerText('Chapter ${widget.chapter}  •  Seviye ${widget.level}', londrina(48, shadows: kTextShadow)),
        )),
      ];

  List<Widget> _scoreboard() {
    Widget side(String name, int score, Color color, {Widget? status}) => GlassBox(
          radius: 40,
          borderWidth: 4,
          borderColor: color,
          color: const Color(0xAA111111),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(name, style: exo(32), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('$score', style: londrina(64, color: color, shadows: kTextShadow)),
            ?status,
          ]),
        );
    return [
      at(40, 220, 420, 200, side(
        _state.playerName,
        _myScore,
        const Color(0xFF21ABD1),
        status: _revealed ? Text('cevapladı ✓', style: exo(22, color: const Color(0xFF63D998))) : null,
      )),
      at(480, 270, 120, 100, centerText('VS', londrina(64, color: const Color(0xFFEB6CA1), shadows: kTextShadow))),
      at(620, 220, 420, 200, ValueListenableBuilder<bool>(
        valueListenable: _opponentAnsweredCurrent,
        builder: (_, answered, _) => side(
          _opponentName,
          _opponentScore,
          const Color(0xFFEB6CA1),
          status: answered
              ? Text('cevapladı ✓', style: exo(22, color: const Color(0xFF63D998)))
              : _waitingForOpponent
                  ? Text('düşünüyor...', style: exo(22, color: Colors.white70))
                  : null,
        ),
      )),
      at(40, 90, 800, 100, Align(
        alignment: Alignment.centerLeft,
        child: Text(widget.category!.title, style: londrina(56, shadows: kTextShadow)),
      )),
    ];
  }

  List<Widget> _matchmaking() => [
        at(0, 600, kDesignW, 100, centerText(widget.category!.title, londrina(80, shadows: kTextShadow))),
        at(
          0,
          720,
          kDesignW,
          60,
          centerText(
            _onlineOpponent ? 'Rakip bulundu: $_opponentName' : 'Rakip aranıyor...',
            exo(40),
          ),
        ),
        at(140, 880, 300, 300, const _Pulse(child: Icon(Icons.person_rounded, size: 200, color: Color(0xFF21ABD1)))),
        at(440, 960, 200, 140, centerText('VS', londrina(110, color: const Color(0xFFEB6CA1), shadows: kTextShadow))),
        at(
          640,
          880,
          300,
          300,
          _Pulse(
            child: Icon(
              _onlineOpponent ? Icons.person_rounded : Icons.help_outline_rounded,
              size: 200,
              color: const Color(0xFFEB6CA1),
            ),
          ),
        ),
        at(0, 1240, kDesignW, 60, centerText('5 soru • Eşzamanlı karşılaşma', exo(34, color: Colors.white70))),
      ];
}

enum _OptionState { idle, correct, wrong, dim }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.letter, required this.text, required this.state, required this.onTap});

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = switch (state) {
      _OptionState.correct => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC6FF9E), Color(0xFF3FCB4F), Color(0xFF1E8E3A)]),
      _OptionState.wrong => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFB199), Color(0xFFEB5A3C), Color(0xFFB42A12)]),
      _ => kMint,
    };
    return Opacity(
      opacity: state == _OptionState.dim ? 0.55 : 1,
      child: Tap(
        playSound: false,
        onTap: state == _OptionState.idle ? onTap : null,
        child: Stack(children: [
          Positioned(left: 0, right: 0, top: 12, bottom: 0, child: DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xFF0D3329), borderRadius: BorderRadius.circular(34)),
          )),
          Positioned(left: 0, right: 0, top: 0, bottom: 12, child: GlassBox(
            radius: 34,
            borderWidth: 5,
            gradient: gradient,
            child: Row(children: [
              const SizedBox(width: 22),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x33000000),
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: centerText(letter, londrina(50)),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: exo(text.length > 26 ? 36 : 44, weight: 700, shadows: kTextShadow),
                ),
              ),
              if (state == _OptionState.correct) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 70),
              if (state == _OptionState.wrong) const Icon(Icons.cancel_rounded, color: Colors.white, size: 70),
              const SizedBox(width: 24),
            ]),
          )),
        ]),
      ),
    );
  }
}

/// Enerji çubuğu tarzında süre göstergesi.
class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.value, required this.seconds});

  final double value;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final low = seconds <= 5;
    return Stack(children: [
      Positioned.fill(child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1580C0),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF27CDF9), width: 5),
        ),
      )),
      Positioned(
        left: 9,
        top: 9,
        bottom: 9,
        width: (1000 - 18) * value.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: low ? const Color(0xFFFF6B4A) : const Color(0xFF2DEAFE),
          ),
        ),
      ),
      Positioned.fill(child: centerText('$seconds sn', londrina(36, shadows: kTextShadow))),
    ]);
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.05).animate(_c),
      child: const GlassBox(radius: 150, blur: 6, borderWidth: 6, color: Color(0x66111111)).withChild(widget.child),
    );
  }
}

extension on GlassBox {
  Widget withChild(Widget child) => Stack(alignment: Alignment.center, children: [Positioned.fill(child: this), child]);
}
