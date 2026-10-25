import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';

/// Seviye sonu penceresi. Figma'da yok; günlük ödül paneli üzerine kuruldu.
Future<void> showLevelResult(
  BuildContext context, {
  required int stars,
  required int correct,
  required int total,
  required int coins,
  required int trophies,
  required VoidCallback onReplay,
  VoidCallback? onNext,
  String nextLabel = 'Sonraki Seviye',
}) {
  final passed = stars > 0;
  return showStageDialog(context, (ctx) => [
        at(80, 250, 920, 1520, svg('daily_panel.svg')),
        at(80, 330, 920, 120, centerText(passed ? 'Tebrikler!' : 'Olmadı!', londrina(50, shadows: kTextShadow))),
        at(205, 500, 200, 200, StarIcon(filled: stars >= 1, size: 200)),
        at(420, 440, 240, 240, StarIcon(filled: stars >= 2, size: 240)),
        at(675, 500, 200, 200, StarIcon(filled: stars >= 3, size: 200)),
        at(80, 730, 920, 80, centerText('$correct / $total doğru', exo(42, weight: 700, shadows: kTextShadow))),
        if (!passed)
          at(120, 810, 840, 70, centerText('Seviyeyi geçmek için en az 3 doğru gerekli', exo(28, color: Colors.white))),
        ..._rewardRow(900, coins, trophies),
        ..._buttons(ctx, [
          if (onNext != null) (nextLabel, kOrange, onNext),
          ('Tekrar Oyna', kMint, onReplay),
          ('Haritaya Dön', null, null),
        ]),
      ]);
}

/// PVP maç sonu penceresi.
Future<void> showPvpResult(
  BuildContext context, {
  required int outcome,
  required int myScore,
  required int botScore,
  required String botName,
  required int trophies,
  required int coins,
  required VoidCallback onReplay,
}) {
  final title = switch (outcome) { > 0 => 'Kazandın!', 0 => 'Berabere', _ => 'Kaybettin' };
  return showStageDialog(context, (ctx) => [
        at(80, 250, 920, 1520, svg('daily_panel.svg')),
        at(80, 330, 920, 120, centerText(title, londrina(50, shadows: kTextShadow))),
        at(80, 480, 920, 260, Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _scoreColumn('Sen', myScore, const Color(0xFF21ABD1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text('-', style: londrina(70))),
          _scoreColumn(botName, botScore, const Color(0xFFEB6CA1)),
        ])),
        ..._rewardRow(800, coins, trophies),
        ..._buttons(ctx, [
          ('Tekrar Oyna', kOrange, onReplay),
          ('Ana Menü', null, null),
        ]),
      ]);
}

Widget _scoreColumn(String name, int score, Color color) => SizedBox(
      width: 330,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: exo(30), maxLines: 1),
          Text('$score', style: londrina(50, color: color, shadows: kTextShadow)),
        ]),
      ),
    );

List<Widget> _rewardRow(double y, int coins, int trophies) => [
      at(80, y, 920, 120, Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 90, height: 90, child: svg('coin.svg')),
        const SizedBox(width: 16),
        Text('+$coins', style: londrina(50, shadows: kTextShadow)),
        const SizedBox(width: 80),
        SizedBox(width: 90, height: 90, child: png('trophy.png')),
        const SizedBox(width: 16),
        Text(trophies >= 0 ? '+$trophies' : '$trophies', style: londrina(50, shadows: kTextShadow)),
      ])),
    ];

/// Alt düğmeler. Eylemi null olan düğme sonuç penceresini ve oyun ekranını kapatır.
List<Widget> _buttons(BuildContext ctx, List<(String, Gradient?, VoidCallback?)> items) {
  final nav = Navigator.of(ctx);
  return [
    for (var i = 0; i < items.length; i++)
      at(190, 1100 + i * 175.0, 700, 140, Tap(
        onTap: () {
          nav.pop(); // sonuç penceresi
          final action = items[i].$3;
          if (action != null) {
            action();
          } else {
            nav.pop(); // oyun ekranı
          }
        },
        child: GlassBox(
          radius: 34,
          borderWidth: 5,
          gradient: items[i].$2,
          color: const Color(0x66111111),
          child: centerText(items[i].$1, londrina(40, shadows: kTextShadow)),
        ),
      )),
  ];
}
