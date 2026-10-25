import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/ui.dart';
import '../data/questions.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';
import 'quiz_screen.dart';

/// Figma: "Pvp Mode Change" (25:12502) — Hızlı açılış için RepaintBoundary ile optimize edildi.
class PvpModeScreen extends StatelessWidget {
  const PvpModeScreen({super.key});

  void _play(BuildContext context, PvpCategory category) {
    if (GameState.instance.energy <= 0) {
      promptRefillEnergy(context, onRefilled: () {
        if (context.mounted) goStage(context, QuizScreen.pvp(category: category));
      });
      return;
    }
    goStage(context, QuizScreen.pvp(category: category));
  }

  Widget _cardBg(String image, double imageTop, double imageH) => RepaintBoundary(
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: imageH == 1
                ? png(image)
                : Stack(clipBehavior: Clip.hardEdge, children: [
                    Positioned(left: 0, top: imageTop * 400, width: 1040, height: imageH * 400, child: png(image, fit: BoxFit.fill)),
                  ]),
          ),
          const GlassBox(radius: 40, color: Colors.transparent, borderWidth: 6),
        ]),
      );

  /// Kupa ve coin ödül satırı (+15 / +5k).
  List<Widget> _rewards(double trophyX, double coinX, double y) => [
        at(trophyX, y, 50, 50, png('trophy.png')),
        Positioned(left: trophyX + 58, top: y + 4, child: Text('+15', style: londrina(32, shadows: kTextShadow))),
        at(coinX, y, 50, 50, svg('coin.svg')),
        Positioned(left: coinX + 58, top: y + 4, child: Text('+5k', style: londrina(32, shadows: kTextShadow))),
      ];

  @override
  Widget build(BuildContext context) {
    return Stage(background: 'bg_pvp.png', children: [
      for (final top in [344.0, 804.0, 1264.0])
        at(20, top, 1040, 400, const GlowFrame(radius: 40, color: Colors.white, width: 3, blur: 4)),
      // 1. Mod: Ben Kimim?
      at(20, 344, 1040, 400, Tap(
        onTap: () => _play(context, PvpCategory.benKimim),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: _cardBg('pvp_card1.png', 0, 1)),
          at(80, 30, 174, 364, flipX(png('pvp_char1.png'))),
          at(0, 162, 1040, 80, centerText('Ben Kimim?', londrina(64, shadows: kTextShadow))),
          ..._rewards(404, 532, 246),
        ]),
      )),
      // 2. Mod: Champions League
      at(20, 804, 1040, 400, Tap(
        onTap: () => _play(context, PvpCategory.championsLeague),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: _cardBg('pvp_card2.png', -2.0731, 3.9)),
          at(717, 9, 243, 385, ClipRect(
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned(left: 0, top: -0.001 * 385, width: 243, height: 1.0099 * 385, child: png('pvp_char3.png', fit: BoxFit.fill)),
            ]),
          )),
          Positioned(left: 206, top: 162, child: Text('Champions League', style: londrina(64, shadows: kTextShadow))),
          ..._rewards(326, 454, 246),
        ]),
      )),
      // 3. Mod: Hangi Takım?
      at(20, 1264, 1040, 400, Tap(
        onTap: () => _play(context, PvpCategory.hangiTakim),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: _cardBg('pvp_card3.png', -0.8702, 3.9)),
          at(80, 6, 218, 388, flipX(png('pvp_char2.png'))),
          at(0, 162, 1040, 80, centerText('Hangi Takım?', londrina(64, shadows: kTextShadow))),
          ..._rewards(404, 532, 246),
        ]),
      )),
      at(
        140,
        1725,
        800,
        92,
        GlassBox(
          radius: 46,
          borderWidth: 3,
          color: const Color(0xBB0D261F),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFF63D998), size: 42),
                const SizedBox(width: 10),
                Text('Canlı Eşzamanlı PVP  •  5 Soru  •  15 sn', style: exo(30, weight: 700, shadows: kTextShadow)),
              ]),
            ),
          ),
        ),
      ),
      const TopHud(top: 140),
      at(923, 80, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
    ]);
  }
}
