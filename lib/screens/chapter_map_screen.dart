import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';
import 'quiz_screen.dart';

/// Figma: "Single Game Mode Chapter 1..4" (25:11107, 25:11549, 25:12023, 25:12217)
/// ve kilitli seviye durumu (25:11298).
///
/// 1. bölüm düz saha üzerine katmanlı düğmelerle çizilir. 2-4. bölümlerin
/// temalı (kar, çöl, lav) düğmeleri Figma görselinde hazır olduğundan o görsel
/// tuvalle birebir hizalanır; üzerine dokunma alanı, kilit ve yıldız eklenir.
class ChapterMapScreen extends StatefulWidget {
  const ChapterMapScreen({super.key, required this.chapter});

  final int chapter;

  @override
  State<ChapterMapScreen> createState() => _ChapterMapScreenState();
}

/// Seviye 1'den 10'a düğme kutularının (200x258) sol üst köşeleri.
final _levelPositions = {
  1: [
    Offset(440, 1455), Offset(720, 1299), Offset(160, 1226), Offset(481, 1072), Offset(761, 926),
    Offset(141, 882), Offset(421, 740), Offset(720, 597), Offset(129, 521), Offset(440, 370),
  ],
  2: [
    Offset(462, 1451), Offset(176, 1258), Offset(715, 1193), Offset(416, 1044), Offset(152, 835),
    Offset(766, 870), Offset(492, 705), Offset(166, 510), Offset(712, 441), Offset(440, 331),
  ],
  3: _desert,
  4: [..._desert.take(3), Offset(406, 1040), ..._desert.skip(4)],
};

const _desert = [
  Offset(453, 1400), Offset(122, 1261), Offset(773, 1166), Offset(453, 1085), Offset(99, 891),
  Offset(770, 860), Offset(470, 761), Offset(149, 589), Offset(782, 519), Offset(434, 416),
];

class _ChapterMapScreenState extends State<ChapterMapScreen> {
  final _state = GameState.instance;

  bool get _baked => widget.chapter > 1;

  @override
  void initState() {
    super.initState();
    _state.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_refresh);
    super.dispose();
  }

  void _play(int level) {
    if (!_state.isLevelUnlocked(widget.chapter, level)) {
      toast(context, 'Bu seviyeyi açmak için önce Seviye ${level - 1}\'i geç!');
      return;
    }
    if (_state.energy <= 0) {
      promptRefillEnergy(context, onRefilled: () {
        if (mounted) goStage(context, QuizScreen.single(chapter: widget.chapter, level: level));
      });
      return;
    }
    goStage(context, QuizScreen.single(chapter: widget.chapter, level: level));
  }

  @override
  Widget build(BuildContext context) {
    final positions = _levelPositions[widget.chapter]!;
    final earnedStars = _state.chapterStars(widget.chapter);
    return Stage(
      background: _baked ? 'chapter${widget.chapter}.png' : 'bg_map.png',
      exactBackground: _baked,
      children: [
        for (var i = 0; i < 10; i++) ...() {
          final level = i + 1;
          final p = positions[i];
          final stars = _state.stars(widget.chapter, level);
          final locked = !_state.isLevelUnlocked(widget.chapter, level);
          final isCurrentTarget = !locked && stars == 0;
          return [
            if (isCurrentTarget)
              at(
                p.dx - 10,
                p.dy - 14,
                220,
                220,
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xCCF68537), blurRadius: 32, spreadRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            if (_baked)
              at(p.dx, p.dy, 200, 258, Tap(onTap: () => _play(level), child: locked ? const _LockOverlay() : const SizedBox.expand()))
            else
              at(p.dx, p.dy, 200, 258, Tap(onTap: () => _play(level), child: LevelButton(number: level, locked: locked))),
            if (stars > 0) ...[
              at(p.dx + 2, p.dy - 40, 80, 80, StarIcon(filled: stars >= 1, size: 80)),
              at(p.dx + 56, p.dy - 70, 90, 90, StarIcon(filled: stars >= 2, size: 90)),
              at(p.dx + 120, p.dy - 40, 80, 80, StarIcon(filled: stars >= 3, size: 80)),
            ],
          ];
        }(),
        at(
          280,
          1790,
          520,
          82,
          GlassBox(
            radius: 41,
            blur: 8,
            borderWidth: 3,
            color: const Color(0x80111111),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Bölüm ${widget.chapter}', style: londrina(38, shadows: kTextShadow)),
                  const SizedBox(width: 20),
                  const StarIcon(filled: true, size: 38),
                  const SizedBox(width: 8),
                  Text('$earnedStars / 30', style: londrina(36, color: const Color(0xFFFFE27A), shadows: kTextShadow)),
                ]),
              ),
            ),
          ),
        ),
        TopHud(top: 140, coverBaked: _baked),
        at(923, 80, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
      ],
    );
  }
}

/// Görselde çizili düğmenin üzerine koyulan kilit katmanı.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      at(6, -21, 192, 192, const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x8C1A1A1A)))),
      const Positioned(left: 70, top: 43, child: Icon(Icons.lock_rounded, color: Colors.white, size: 64, shadows: kTextShadow)),
    ]);
  }
}

/// Figma "Button" (25:11151): katmanlı yeşil seviye düğmesi.
class LevelButton extends StatelessWidget {
  const LevelButton({super.key, required this.number, this.locked = false});

  final int number;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    Widget body = Stack(clipBehavior: Clip.none, children: [
      at(0, 65, 200, 193, svg('lvl_e137.svg')),
      at(0, 0, 200, 192.846, svg('lvl_e136.svg')),
      at(5.17, 0, 191.379, 176.923, svg('lvl_e135.svg')),
      at(20.69, 10.62, 160.345, 152.154, svg('lvl_e134.svg')),
      at(36.21, 23, 129.31, 127.385, svg('lvl_e133.svg')),
      at(36.21, 14.15, 129.31, 127.385, svg('lvl_e132.svg')),
      at(41, 14, 120.69, 115, svg('lvl_e131.svg')),
      at(43.17, 14, 102.706, 63.846, svg('lvl_shine.svg')),
      at(41, 14, 120.69, 115, centerText('$number', londrina(64, color: const Color(0xFFD39A41)))),
      at(68.1, 22.5, 29, 12.476, Transform.rotate(angle: -0.2618, child: svg('lvl_e138.svg'))),
    ]);
    if (locked) {
      body = Stack(clipBehavior: Clip.none, children: [
        ColorFiltered(colorFilter: const ColorFilter.matrix(_greyMatrix), child: body),
        const Positioned(left: 68, top: 40, child: Icon(Icons.lock_rounded, color: Colors.white, size: 64, shadows: kTextShadow)),
      ]);
    }
    return body;
  }
}

const _greyMatrix = <double>[
  0.25, 0.5, 0.1, 0, -10, //
  0.25, 0.5, 0.1, 0, -10,
  0.25, 0.5, 0.1, 0, -10,
  0, 0, 0, 1, 0,
];
