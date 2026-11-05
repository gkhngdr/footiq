import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/sound.dart';
import '../core/ui.dart';
import '../screens/daily_reward_dialog.dart';
import '../widgets/common.dart';
import 't21_api.dart';
import 't21_match.dart';
import 't21_mic_permission.dart';
import 't21_voice.dart';

const _botNames = [
  'GolKralı34',
  'Libero61',
  'Forvet07',
  'TribünSesi',
  'KornerUstası',
];

/// 3-2-1 maç ekranı. Şimdilik bot rakiple "pratik maçı"; turnuvada aynı ekran
/// farklı rakip ve etiketle kullanılır.
class T21MatchScreen extends StatefulWidget {
  const T21MatchScreen({super.key, this.match, this.voice = !kIsWeb});

  /// Ses modu ile mi başlasın? Giriş düğmesi izin akışına göre belirler
  /// (bkz. `t21PrepareMic`); izin yoksa klavye ile başlar.
  final bool voice;

  /// Dışarıdan hazırlanmış maç (turnuva/test). Yoksa bot rakiple pratik maçı kurulur.
  final T21Match? match;

  @override
  State<T21MatchScreen> createState() => _T21MatchScreenState();
}

class _T21MatchScreenState extends State<T21MatchScreen> {
  late T21Match _m;
  final _input = TextEditingController();

  /// Yazı kutusu maç boyunca aynı kalır: telefonda klavye her soruda kapanıp
  /// açılmasın (her açılış/kapanış tüm ekranı yeniden boyutlandırıp kasıyordu).
  final _focus = FocusNode();
  late bool _keyboard = !widget.voice;
  bool _listening = false;
  String _heard = '';
  List<String> _heardAlternatives = const [];
  List<String> _suggestions = const [];
  Timer? _suggestDebounce;
  T21Phase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _m =
        widget.match ??
        T21Match(
          opponent: T21BotOpponent(
            name: _botNames[Random().nextInt(_botNames.length)],
            skill: 0.45,
          ),
        );
    _m.addListener(_onMatch);
    _m.start();
  }

  void _onMatch() {
    if (!mounted) return;
    final p = _m.phase;
    if (p != _lastPhase) {
      _lastPhase = p;
      switch (p) {
        case T21Phase.countdown:
          _input.clear();
          _suggestions = const [];
          _heard = '';
          _heardAlternatives = const [];
          Sound.tick();
        case T21Phase.answering:
          Sound.click();
          if (_keyboard && !_focus.hasFocus) _focus.requestFocus();
        case T21Phase.questionResult:
          if (_m.questionWinner == T21Side.me) {
            Sound.correct();
          } else if (_m.questionWinner == T21Side.opponent) {
            Sound.wrong();
          } else {
            Sound.timeout();
          }
        case T21Phase.finished:
          if (_m.matchWinner == T21Side.me) {
            Sound.win();
          } else {
            Sound.lose();
          }
        default:
          break;
      }
    } else if (p == T21Phase.countdown) {
      Sound.tick();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    T21Voice.instance.cancel();
    _m.removeListener(_onMatch);
    _m.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ cevaplar

  Future<void> _send(List<String> said) async {
    if (said.isEmpty) return;
    final fb = await _m.submit(said);
    if (!mounted || fb == null) return;
    switch (fb.verdict) {
      case T21Verdict.wrong:
        Sound.wrong();
        _input.clear();
      case T21Verdict.repeat:
      case T21Verdict.unknown:
        _input.clear();
      case T21Verdict.correct:
        break;
    }
    setState(() {
      _heard = '';
      _heardAlternatives = const [];
      _suggestions = const [];
    });
  }

  void _onTyping(String v) {
    _suggestDebounce?.cancel();
    if (v.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 250), () async {
      final s = await T21Api.suggest(v);
      if (mounted && _m.isAnswering) setState(() => _suggestions = s);
    });
  }

  DateTime? _pressedAt;

  /// Mikrofona dokunuldu: dinlemiyorsa başla, dinliyorsa bitir (dokun-konuş).
  Future<void> _micPressed() async {
    if (_listening) {
      await T21Voice.instance.stop();
      return;
    }
    if (!_m.isAnswering || _m.myLocked) return;
    _pressedAt = DateTime.now();
    setState(() {
      _listening = true;
      _heard = '';
      _heardAlternatives = const [];
    });
    final ok = await T21Voice.instance.start(
      onPartial: (t) {
        if (mounted) setState(() => _heard = t);
      },
      onFinal: _voiceDone,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _listening = false;
        _keyboard = true;
      });
      await t21MicUnavailable(context);
    }
  }

  /// Parmak kalktı: uzun basılı tutulduysa (basılı tut-konuş) dinlemeyi bitir;
  /// kısa dokunuşsa dinleme sessizlik olunca kendiliğinden biter.
  void _micReleased() {
    final at = _pressedAt;
    _pressedAt = null;
    if (!_listening || at == null) return;
    if (DateTime.now().difference(at) >= const Duration(milliseconds: 700)) {
      T21Voice.instance.stop();
    }
  }

  void _voiceDone(List<String> alts) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _heardAlternatives = alts;
      if (alts.isNotEmpty) _heard = alts.first;
    });
    if (alts.isEmpty && _m.isAnswering) {
      toast(context, 'Duyamadım, tekrar dene.');
    }
  }

  Future<void> _quit() async {
    if (_m.phase == T21Phase.finished || _m.phase == T21Phase.error) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showStageConfirm(
      context,
      title: 'Maçtan Çık',
      message: 'Maçtan çıkarsan hükmen kaybedersin. Emin misin?',
      confirmLabel: 'Çık',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------ çizim

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Stage(
        background: 'bg_pvp.webp',
        backgroundBlur: 8,
        keyboardShift: true,
        children: [
          at(
            0,
            0,
            kDesignW,
            kDesignH,
            const ColoredBox(color: Color(0x88000000)),
          ),
          at(
            100,
            80,
            760,
            110,
            Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'FOOTIQ ',
                      style: londrina(64, shadows: kTextShadow),
                    ),
                    TextSpan(
                      text: '3-2-1',
                      style: londrina(
                        64,
                        color: const Color(0xFFC6F24E),
                        shadows: kTextShadow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._body(),
          at(923, 80, 116.715, 116.715, CloseBtn(onTap: _quit)),
        ],
      ),
    );
  }

  List<Widget> _body() {
    switch (_m.phase) {
      case T21Phase.loading:
        return [_centerMessage('Maç hazırlanıyor…')];
      case T21Phase.error:
        return [
          _centerMessage(
            'Sorular yüklenemedi.\nİnternet bağlantını kontrol et.',
          ),
        ];
      case T21Phase.intro:
        return [_intro()];
      case T21Phase.finished:
        return [_scoreboard(), _finished()];
      default:
        return [
          _scoreboard(),
          _countdownRow(),
          _questionCard(),
          ..._answerArea(),
          if (_m.phase == T21Phase.questionResult) _questionResult(),
        ];
    }
  }

  Widget _centerMessage(String text) => at(
    80,
    760,
    920,
    300,
    Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: exo(40, weight: 700, shadows: kTextShadow),
      ),
    ),
  );

  Widget _panel({required Widget child, Color border = Colors.white24}) =>
      GlassBox(
        radius: 40,
        color: const Color(0xCC0B1E18),
        borderWidth: 3,
        borderColor: border,
        child: child,
      );

  Widget _intro() {
    final me = GameState.instance.playerName;
    return at(
      80,
      560,
      920,
      720,
      _panel(
        border: const Color(0x99C6F24E),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _m.label,
              style: exo(34, weight: 800, color: const Color(0xFFC6F24E)),
            ),
            const SizedBox(height: 40),
            FittedBox(
              child: Text(me, style: londrina(72, shadows: kTextShadow)),
            ),
            Text(
              'VS',
              style: londrina(
                96,
                color: const Color(0xFFFF9EC6),
                shadows: kTextShadow,
              ),
            ),
            FittedBox(
              child: Text(
                _m.opponent.name,
                style: londrina(72, shadows: kTextShadow),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'İlk ${_m.rules.winTarget} doğruya ulaşan kazanır',
              style: exo(32, weight: 700, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots(T21Side side) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < _m.rules.regularQuestions; i++)
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _m.results.length
                ? (_m.results[i] == side
                      ? (side == T21Side.me
                            ? const Color(0xFFC6F24E)
                            : const Color(0xFFFF7A45))
                      : Colors.white24)
                : Colors.white10,
          ),
        ),
    ],
  );

  Widget _scoreboard() {
    final status =
        _m.opponentStatus ??
        (_m.myLocked ? 'Yanlış cevap verdin, bu soruda kilitlendin' : null);
    return at(
      60,
      210,
      960,
      230,
      _panel(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SEN',
                            style: londrina(44, shadows: kTextShadow),
                          ),
                          const SizedBox(height: 8),
                          _dots(T21Side.me),
                        ],
                      ),
                    ),
                    Text(
                      '${_m.myScore} : ${_m.opponentScore}',
                      style: londrina(
                        80,
                        color: const Color(0xFFC6F24E),
                        shadows: kTextShadow,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            child: Text(
                              _m.opponent.name,
                              style: londrina(
                                40,
                                color: const Color(0xFFFF9EC6),
                                shadows: kTextShadow,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _dots(T21Side.opponent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: FittedBox(
                  child: Text(
                    status ??
                        (_m.isGolden
                            ? 'ALTIN SORU • İlk bilen kazanır'
                            : 'Soru ${_m.index + 1} / ${_m.rules.regularQuestions}'),
                    style: exo(26, weight: 700, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countdownRow() {
    if (_m.phase == T21Phase.answering) {
      return at(
        80,
        470,
        920,
        110,
        ValueListenableBuilder<double>(
          valueListenable: _m.timeLeft,
          builder: (_, left, _) {
            final frac = (left / _m.rules.answerSeconds).clamp(0.0, 1.0);
            return Column(
              children: [
                Row(
                  children: [
                    Text(
                      'KALAN SÜRE',
                      style: exo(
                        30,
                        weight: 800,
                        color: const Color(0xFFFF7A45),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${left.ceil().toString().padLeft(2, '0')} SN',
                      style: londrina(52, color: const Color(0xFFFF7A45)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 16,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFFF7A45),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    final current = _m.phase == T21Phase.countdown ? _m.countdown : 0;
    return at(
      240,
      460,
      600,
      150,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final n in [3, 2, 1])
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: n == current ? 150 : 100,
              height: n == current ? 150 : 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n == current
                    ? const Color(0xFFFF6A2B)
                    : Colors.transparent,
              ),
              child: Center(
                child: Text(
                  '$n',
                  style: londrina(
                    n == current ? 96 : 64,
                    color: n == current ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _questionCard() {
    final q = _m.question!;
    return at(
      60,
      630,
      960,
      600,
      _panel(
        border: _m.isGolden ? const Color(0xFFFFE27A) : Colors.white24,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              GlassBox(
                radius: 30,
                color: const Color(0x33C6F24E),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 6,
                  ),
                  child: Text(
                    _m.isGolden ? 'ALTIN SORU' : 'ORTAK FUTBOLCU',
                    style: londrina(34, color: const Color(0xFFC6F24E)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'İki takımda da forma giymiş bir futbolcu söyle!',
                textAlign: TextAlign.center,
                style: exo(34, weight: 700, shadows: kTextShadow),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: T21ClubBadge(club: q.a)),
                    Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFC6F24E),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 64,
                        color: Color(0xFF0B1E18),
                      ),
                    ),
                    Expanded(child: T21ClubBadge(club: q.b)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _answerArea() {
    final fb = _m.myFeedback;
    final answering = _m.isAnswering;
    final active = answering && !_m.myLocked;
    final feedbackText = switch (fb?.verdict) {
      T21Verdict.wrong =>
        '${fb!.name ?? 'Bu isim'} bu iki takımda birlikte oynamadı',
      T21Verdict.repeat => '${fb!.name} bu maçta zaten söylendi',
      T21Verdict.unknown => 'Bu ismi tanıyamadım, tekrar dene',
      _ => null,
    };
    final widgets = <Widget>[
      if (answering && feedbackText != null)
        at(
          80,
          1250,
          920,
          80,
          Center(
            child: Text(
              feedbackText,
              textAlign: TextAlign.center,
              style: exo(
                30,
                weight: 700,
                color: const Color(0xFFFFB199),
                shadows: kTextShadow,
              ),
            ),
          ),
        ),
    ];

    if (_keyboard) {
      widgets.addAll([
        if (active && _suggestions.isNotEmpty)
          at(
            110,
            1340,
            860,
            min(90.0 * _suggestions.length, 270),
            _panel(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final s in _suggestions.take(3))
                    Tap(
                      onTap: () => _send([s]),
                      child: SizedBox(
                        height: 90,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(s, style: exo(32, weight: 700)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        at(
          80,
          1630,
          720,
          110,
          GlassBox(
            radius: 55,
            color: const Color(0xCC0B1E18),
            borderWidth: 3,
            borderColor: const Color(0xFFC6F24E),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Center(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  readOnly: !active,
                  onTapOutside: kIsWeb
                      ? null
                      : (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: _onTyping,
                  onSubmitted: (v) => _send([v]),
                  textInputAction: TextInputAction.send,
                  autocorrect: false,
                  style: exo(34, weight: 700),
                  cursorColor: const Color(0xFFC6F24E),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Futbolcu adını yaz…',
                    hintStyle: exo(32, weight: 500, color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),
        ),
        at(
          820,
          1630,
          180,
          110,
          Tap(
            onTap: active ? () => _send([_input.text]) : null,
            child: const GlassBox(
              radius: 55,
              gradient: LinearGradient(
                colors: [Color(0xFFC6F24E), Color(0xFF8CC63F)],
              ),
              child: Icon(
                Icons.send_rounded,
                size: 56,
                color: Color(0xFF0B1E18),
              ),
            ),
          ),
        ),
        at(
          340,
          1770,
          400,
          90,
          Tap(
            onTap: () => setState(() => _keyboard = false),
            child: GlassBox(
              radius: 45,
              color: const Color(0x99102A22),
              borderWidth: 2,
              child: centerText('🎤  Sesle söyle', exo(30, weight: 700)),
            ),
          ),
        ),
      ]);
      return widgets;
    }

    // Ses modu: basılı tut-konuş, sonra onay
    final hasHeard = !_listening && _heardAlternatives.isNotEmpty;
    widgets.addAll([
      if (_listening || hasHeard)
        at(
          80,
          1330,
          920,
          150,
          _panel(
            border: const Color(0x99C6F24E),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Text(
                      _listening
                          ? (_heard.isEmpty ? 'Dinliyorum…' : '"$_heard…"')
                          : '"$_heard" mi dedin?',
                      style: londrina(46, color: const Color(0xFFC6F24E)),
                    ),
                  ),
                  if (hasHeard) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tap(
                          onTap: () => _send(_heardAlternatives),
                          child: GlassBox(
                            radius: 30,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFC6F24E), Color(0xFF8CC63F)],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 6,
                              ),
                              child: Text(
                                '✓ EVET, ONAYLA',
                                style: londrina(
                                  34,
                                  color: const Color(0xFF0B1E18),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Tap(
                          onTap: () => setState(() {
                            _heard = '';
                            _heardAlternatives = const [];
                          }),
                          child: Text(
                            '↻ Tekrar',
                            style: exo(30, weight: 700, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      at(
        390,
        1500,
        300,
        300,
        // Ham dokunuş olayları: hareket/izin penceresi hareketi iptal etmesin.
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => active || _listening ? _micPressed() : null,
          onPointerUp: (_) => _micReleased(),
          onPointerCancel: (_) => _micReleased(),
          child: AnimatedScale(
            scale: _listening ? 1.08 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC6F24E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC6F24E)
                        .withValues(alpha: _listening ? 0.8 : 0.4),
                    blurRadius: 24,
                    spreadRadius: _listening ? 10 : 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mic_rounded,
                    size: 110,
                    color: Color(0xFF0B1E18),
                  ),
                  Text(
                    _listening
                        ? 'DİNLİYORUM\n(bitirmek için dokun)'
                        : 'DOKUN\nVE SÖYLE',
                    textAlign: TextAlign.center,
                    style: londrina(28, color: const Color(0xFF0B1E18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      at(
        340,
        1820,
        400,
        80,
        Tap(
          onTap: () => setState(() => _keyboard = true),
          child: GlassBox(
            radius: 40,
            color: const Color(0x99102A22),
            borderWidth: 2,
            child: centerText('⌨  Klavye ile yaz', exo(28, weight: 700)),
          ),
        ),
      ),
    ]);
    return widgets;
  }

  Widget _questionResult() {
    final w = _m.questionWinner;
    final title = switch (w) {
      T21Side.me => 'DOĞRU! +1',
      T21Side.opponent => '${_m.opponent.name} BİLDİ',
      null => 'KİMSE BİLEMEDİ',
    };
    final color = switch (w) {
      T21Side.me => const Color(0xFFC6F24E),
      T21Side.opponent => const Color(0xFFFF7A45),
      null => Colors.white,
    };
    return at(
      60,
      1250,
      960,
      560,
      _panel(
        border: color,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                child: Text(
                  title,
                  style: londrina(72, color: color, shadows: kTextShadow),
                ),
              ),
              if (_m.winningName != null)
                FittedBox(
                  child: Text(
                    _m.winningName!,
                    style: londrina(56, shadows: kTextShadow),
                  ),
                ),
              const SizedBox(height: 20),
              if (_m.otherAnswers.isNotEmpty) ...[
                Text(
                  'Diğer doğru cevaplar',
                  style: exo(28, weight: 700, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  _m.otherAnswers.join('  •  '),
                  textAlign: TextAlign.center,
                  style: exo(30, weight: 700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _finished() {
    final w = _m.matchWinner;
    final title = switch (w) {
      T21Side.me => 'KAZANDIN!',
      T21Side.opponent => 'KAYBETTİN',
      null => 'BERABERE',
    };
    return at(
      80,
      560,
      920,
      900,
      _panel(
        border: w == T21Side.me ? const Color(0xFFC6F24E) : Colors.white24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_m.label, style: exo(32, weight: 800, color: Colors.white70)),
            const SizedBox(height: 20),
            Text(
              title,
              style: londrina(
                110,
                color: const Color(0xFFC6F24E),
                shadows: kTextShadow,
              ),
            ),
            Text(
              '${_m.myScore} : ${_m.opponentScore}',
              style: londrina(90, shadows: kTextShadow),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 600,
              height: 120,
              child: Tap(
                onTap: () =>
                    goStage(
                  context,
                  T21MatchScreen(voice: !_keyboard),
                  replace: true,
                ),
                child: GlassBox(
                  radius: 30,
                  gradient: kOrange,
                  borderWidth: 3,
                  borderColor: const Color(0xFFFEC665),
                  child: centerText(
                    'TEKRAR OYNA',
                    londrina(44, shadows: kTextShadow),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 600,
              height: 110,
              child: Tap(
                onTap: () => Navigator.of(context).pop(),
                child: GlassBox(
                  radius: 30,
                  color: const Color(0x99102A22),
                  borderWidth: 3,
                  child: centerText(
                    'ÇIKIŞ',
                    londrina(40, shadows: kTextShadow),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kulüp rozeti: logo yerine kulüp rengiyle arma şekli + kısa kod (telif riski yok).
class T21ClubBadge extends StatelessWidget {
  const T21ClubBadge({super.key, required this.club});

  final T21Club club;

  @override
  Widget build(BuildContext context) {
    final c = club.color ?? const Color(0xFF3E8778);
    final dark = Color.lerp(c, Colors.black, 0.45)!;
    final light = c.computeLuminance() > 0.6;
    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 0.82,
            child: ClipPath(
              clipper: _ShieldClipper(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c, dark],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: FittedBox(
                      child: Text(
                        club.short,
                        style: londrina(
                          72,
                          color: light ? const Color(0xFF0B1E18) : Colors.white,
                          shadows: light ? null : kTextShadow,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          child: Text(club.name, style: londrina(38, shadows: kTextShadow)),
        ),
        Text(
          club.leagueName,
          style: exo(24, weight: 600, color: Colors.white60),
        ),
      ],
    );
  }
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * 0.1, 0)
    ..lineTo(s.width * 0.9, 0)
    ..quadraticBezierTo(s.width, 0, s.width, s.height * 0.1)
    ..lineTo(s.width, s.height * 0.55)
    ..quadraticBezierTo(s.width, s.height * 0.85, s.width * 0.5, s.height)
    ..quadraticBezierTo(0, s.height * 0.85, 0, s.height * 0.55)
    ..lineTo(0, s.height * 0.1)
    ..quadraticBezierTo(0, 0, s.width * 0.1, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
