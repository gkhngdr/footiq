import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'chapter_select_screen.dart';
import 'daily_reward_dialog.dart';
import 'invite_dialog.dart';
import 'leaderboard_dialog.dart';
import 'pvp_mode_screen.dart';
import 'settings_dialog.dart';

/// Figma: "Main Screen" (25:10784)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _state = GameState.instance;

  @override
  void initState() {
    super.initState();
    _state.addListener(_refresh);
    // Günlük ödül alınmadıysa açılışta göster; alt ekran arka planlarını arka planda ısıt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_state.canClaimDaily) showDailyReward(context);
      for (final bg in ['bg_map.png', 'bg_pvp.png', 'chapter1.png']) {
        precacheImage(AssetImage(fig(bg)), context);
      }
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_refresh);
    super.dispose();
  }

  void _open(Widget screen) => goStage(context, screen);

  void _watchAd() {
    if (_state.energy >= GameState.maxEnergy) {
      toast(context, 'Enerjin zaten dolu!');
      return;
    }
    showFakeAd(context, onDone: () {
      _state.addEnergy(1);
      toast(context, '+1 enerji kazandın!');
    });
  }

  void _gift() {
    if (_state.giftReady) {
      _state.claimGift();
      toast(context, '+${GameState.giftReward} coin kazandın!');
    } else {
      toast(context, '${GameState.giftGoal} oyun tamamla, hediyeyi aç! (${_state.giftProgress}/${GameState.giftGoal})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stage(background: 'bg_main.png', children: [
      at(1000, 84, 60, 60, Tap(onTap: () => showSettings(context), child: svg('settings.svg'))),
      const _SeasonBar(),
      _GiftButton(progress: _state.giftProgress, onTap: _gift),
      const TopHud(top: 160, rankX: 390),
      // OYNA
      ..._playCard(
        left: 110,
        cardLeft: 148,
        label: 'OYNA',
        layers: const [
          _CardLayer('card_play.png', 148, 330, 303, 6, -0.4437, 0, 1.884, 1.0007),
        ],
        topLayer: const _CardLayer.cover('card_play_b.png', 147.5, 329.063, 292.5, 2),
        onTap: () => _open(const ChapterSelectScreen()),
      ),
      // PVP OYNA
      ..._playCard(
        left: 565,
        cardLeft: 602.5,
        label: 'PVP OYNA',
        layers: const [
          _CardLayer('card_pvp.png', 602.5, 330, 303, 6, -0.3099, -0.0013, 1.6387, 1.0012),
        ],
        topLayer: const _CardLayer('card_pvp_b.png', 603, 330, 303, 2, -0.3184, -0.0395, 1.6368, 1.0),
        onTap: () => _open(const PvpModeScreen()),
        extra: Positioned(
          left: 751,
          top: 1395,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'V', style: londrina(36, color: const Color(0xFFEB6CA1))),
              TextSpan(text: 'S', style: londrina(36, color: const Color(0xFF21ABD1))),
            ]),
          ),
        ),
      ),
      _SideButton(top: 384, label: 'Izle Kazan', fontSize: 32, labelX: 774, labelY: 439, icon: const _WatchIcon(), onTap: _watchAd),
      _SideButton(
        top: 561,
        label: 'Davet Et Kazan',
        fontSize: 24,
        labelX: 767,
        labelY: 621,
        icon: const _PlusBadge(),
        onTap: () => showInvite(context),
      ),
    ]);
  }

  List<Widget> _playCard({
    required double left,
    required double cardLeft,
    required String label,
    required List<_CardLayer> layers,
    required _CardLayer topLayer,
    required VoidCallback onTap,
    Widget? extra,
  }) {
    final btnL = left + 405 * 0.0245;
    return [
      for (final l in layers) l.build(),
      topLayer.build(),
      ?extra,
      // Kart görseline dokununca da ölçekleme + sesli tepki
      at(cardLeft, 1265, 330, 270, Tap(onTap: onTap, child: const SizedBox.expand())),
      // Düğme: gölge, gövde, parlama ve süsler (tümü birlikte basılma animasyonu yapar)
      at(btnL, 1536, 383, 144, Tap(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          at(0, 8, 382.912, 136, svg(left < 500 ? 'btn_play_shadow.svg' : 'btn_pvp_shadow.svg')),
          at(15.9 - (btnL - left), 0, 372.642, 137, svg('btn_body.svg')),
          at(25 - (btnL - left), 2, 177.883, 48.492, svg('btn_shine.svg')),
          at(329.52 - (btnL - left), 4.33, 14.468, 5.526, svg('btn_dot.svg')),
          at(101.25 - (btnL - left), 4.33, 225.394, 4.667, svg('btn_line.svg')),
          at(15.9 - (btnL - left), 0, 372.642, 137, centerText(label, londrina(54, shadows: kTextShadow))),
        ]),
      )),
    ];
  }
}

/// Kart görseli: beyaz çerçeveli, köşeleri yuvarlatılmış ve Figma'daki gibi kırpılmış.
class _CardLayer {
  const _CardLayer(this.image, this.left, this.w, this.h, this.border, this.dx, this.dy, this.sw, this.sh) : cover = false;

  const _CardLayer.cover(this.image, this.left, this.w, this.h, this.border)
      : dx = 0,
        dy = 0,
        sw = 1,
        sh = 1,
        cover = true;

  final String image;
  final double left, w, h, border, dx, dy, sw, sh;
  final bool cover;

  Widget build() => at(left, 1265, w, h, RepaintBoundary(
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: cover
                ? png(image)
                : Stack(clipBehavior: Clip.hardEdge, children: [
                    Positioned(left: dx * w, top: dy * h, width: sw * w, height: sh * h, child: png(image, fit: BoxFit.fill)),
                  ]),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white, width: border),
            ),
          ),
        ]),
      ));
}

/// Kupa simgesi + sezon çubuğu (Figma 25:10787 ve 25:10798). Dokununca sıralama açılır.
class _SeasonBar extends StatelessWidget {
  const _SeasonBar();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 1);
    final left = end.difference(now);
    return at(278, 1095, 524, 132, RepaintBoundary(
      child: Tap(
        onTap: () => showLeaderboard(context),
        child: Stack(clipBehavior: Clip.none, children: [
          at(60, 40.5, 463.5, 46.5, flipX(svg('season_bar.svg'))),
          at(165, 43.5, 48, 39.75, flipX(svg('season_r128.svg'))),
          at(114, 43.5, 48, 39.75, flipX(svg('season_r130.svg'))),
          at(64.5, 43.5, 46.5, 39.75, flipX(svg('season_r132.svg'))),
          at(165, 63, 48, 20.25, flipX(svg('season_r129.svg'))),
          at(114, 63, 48, 20.25, flipX(svg('season_r129.svg'))),
          at(64.5, 63, 46.5, 20.25, flipX(svg('season_r133.svg'))),
          at(0, 0, 120, 120, png('trophy.png')),
          at(138, 100, 247.5, 30, const GlassBox(radius: 12, color: Color(0x4D111111))),
          at(138, 100, 247.5, 30, centerText('Sezonun bitmesine ${left.inDays}g ${left.inHours % 24}h', londrina(22.5, spacing: -0.02))),
        ]),
      ),
    ));
  }
}

/// "Oynadıkça kazan" hediye düğmesi (Figma 25:10801).
class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.progress, required this.onTap});

  final int progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ratio = 165.0;
    final fill = (ratio * progress / GameState.giftGoal).clamp(0.0, ratio);
    return at(19.9, 384, 174.2, 168.1, RepaintBoundary(
      child: Tap(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          at(9.1, 3, 156, 156, const _Blurred(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0D3329))))),
          at(12.1, 3, 150, 150, const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFAEF8EA), Color(0xFF63D998), Color(0xFF029D88)],
                stops: [0, 0.52885, 1],
              ),
            ),
          )),
          ..._greenDisc(19.6, 7.5),
          at(30.1, 0, 114, 114, png('gift_blue.png')),
          at(0, 121.4, 174.2, 46.7, svg('gift_r136.svg')),
          at(0.1, 121.5, 174, 42, svg('gift_r134.svg')),
          at(4.6, 124.5, 165, 36, svg('gift_r135.svg')),
          if (fill > 0)
            at(4.6, 124.5, fill, 36, ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7BB00), Color(0xFFFDE00A), Color(0xFFFDE00A), Color(0xFFF7BB00)],
                    stops: [0, 0.144, 0.51, 0.738],
                  ),
                ),
              ),
            )),
          at(6.1, 130.44, 61.5, 14.298, flipX(svg('gift_r137.svg'))),
          at(
            4.6,
            124.5,
            165,
            36,
            centerText(
              progress >= GameState.giftGoal ? 'AÇ! ($progress/${GameState.giftGoal})' : '$progress/${GameState.giftGoal}',
              londrina(25, shadows: const [
                Shadow(color: Color(0xFF3A2A00), offset: Offset(-2, -2)),
                Shadow(color: Color(0xFF3A2A00), offset: Offset(2, -2)),
                Shadow(color: Color(0xFF3A2A00), offset: Offset(-2, 2)),
                Shadow(color: Color(0xFF3A2A00), offset: Offset(2, 2)),
              ]),
            ),
          ),
        ]),
      ),
    ));
  }
}

/// İç içe yeşil daireler + radyal degrade (hediye ve yan düğmelerde ortak).
List<Widget> _greenDisc(double x, double y) => [
      at(x, y, 135, 135, const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF75E0AB)))),
      at(x + 1.5, y + 1.5, 132, 132, const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF349D75)))),
      at(x + 4.5, y + 4.5, 126, 126, const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFF89E8C2), Color(0xFF6CC0A0), Color(0xFF50987F), Color(0xFF33705D), Color(0xFF245C4C), Color(0xFF16483B)],
            stops: [0, 0.25, 0.5, 0.75, 0.875, 1],
          ),
        ),
      )),
    ];

class _Blurred extends StatelessWidget {
  const _Blurred({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 1.7, sigmaY: 1.7), child: child);
}

/// "İzle Kazan" / "Davet Et Kazan" düğmeleri (Figma 25:10892, 25:10928).
class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.top,
    required this.label,
    required this.fontSize,
    required this.labelX,
    required this.labelY,
    required this.icon,
    required this.onTap,
  });

  final double top;
  final String label;
  final double fontSize;
  final double labelX;
  final double labelY;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return at(742, top, 318, 157, RepaintBoundary(
      child: Tap(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          at(165, 7, 153, 150, const _Round(Color(0xFF0D3329), 100)),
          at(0, 46, 215, 76, const _Round(Color(0xFF0D3329), 34)),
          at(0, 38, 216, 80, const _Round(Color(0xFF3E8778), 34)),
          at(167, 4, 150, 150, const _Round(Color(0xFF3E8778), 100)),
          at(1, 34, 308, 80, const GlassBox(radius: 34, gradient: LinearGradient(colors: [Color(0xFF58B387), Color(0xFFAEF8EA)]))),
          at(37.5, 34, 137.4, 80, svg('side_r321.svg')),
          at(13, 38, 207.753, 22.351, Transform.rotate(angle: 3.14159, child: svg('side_v14.svg'))),
          at(167, 0, 150, 150, const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFAEF8EA), Color(0xFF58B387)], stops: [0.87333, 1]),
            ),
          )),
          at(7.97, 59.9, 7.457, 6.618, Transform.rotate(angle: -2.0944, child: svg('side_v15.svg'))),
          ..._greenDisc(175.5, 4.5),
          Positioned.fill(child: Stack(clipBehavior: Clip.none, children: [icon])),
          Positioned(left: labelX - 742, top: labelY - top, child: Text(label, style: londrina(fontSize, shadows: kTextShadow))),
        ]),
      ),
    ));
  }
}

class _Round extends StatelessWidget {
  const _Round(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)));
}

/// Klaket (video) simgesi — "İzle Kazan".
class _WatchIcon extends StatelessWidget {
  const _WatchIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      at(202.4, 16.3, 84, 15.43, Transform.rotate(angle: -0.122, child: svg('watch_top.svg'))),
      at(203.14, 35.85, 80, 57.143, DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF17191C),
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(1),
        ),
      )),
      at(203.14, 35.86, 80, 11.429, svg('watch_stripe.svg')),
      at(234, 59.86, 19.28, 21.371, svg('watch_play.svg')),
    ]);
  }
}

/// "Davet Et Kazan" sarı artı rozeti (Figma 25:10943).
class _PlusBadge extends StatelessWidget {
  const _PlusBadge();

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      at(181.72, 9, 123.285, 123.285, const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, gradient: kCreamRing))),
      at(187.64, 10.73, 113.422, 113.422, const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFECB56)))),
      at(189.64, 58, 111.673, 66.002, svg('plus_sub.svg')),
      at(194.76, 8, 96.332, 30.555, Transform.rotate(angle: 3.14159, child: svg('plus_sub1.svg'))),
      at(215.62, 57.17, 55.478, 12.329, DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)))),
      at(237.19, 35.59, 12.329, 55.478, DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)))),
      at(203, 29, 10, 8, svg('plus_e129.svg')),
      at(212.8, 11, 56.838, 19.233, flipX(svg('plus_e130.svg'))),
    ]);
  }
}
