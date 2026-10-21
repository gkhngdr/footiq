import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';

/// Ekranı bulanıklaştıran ve 1080x1920 tuval üzerinde çizilen tam ekran pencere.
Future<T?> showStageDialog<T>(BuildContext context, List<Widget> Function(BuildContext) children) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
    pageBuilder: (ctx, _, _) => Material(
      type: MaterialType.transparency,
      child: Stack(fit: StackFit.expand, children: [
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: const ColoredBox(color: Color(0x66000000))),
        Center(
          child: FittedBox(
            child: SizedBox(width: kDesignW, height: kDesignH, child: Stack(clipBehavior: Clip.none, children: children(ctx))),
          ),
        ),
      ]),
    ),
  );
}

/// Oyun tasarım diline (1080x1920 Stage, cam panel ve Londrina/Exo fontlar) uygun onay penceresi.
Future<bool> showStageConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Evet',
  String cancelLabel = 'Vazgeç',
}) async {
  final res = await showStageDialog<bool>(context, (ctx) => [
        at(110, 560, 860, 760, svg('daily_panel.svg')),
        at(140, 640, 800, 100, centerText(title, londrina(76, shadows: kTextShadow))),
        at(160, 770, 760, 220, Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: exo(38, weight: 600, shadows: kTextShadow),
          ),
        )),
        at(170, 1050, 350, 130, Tap(
          onTap: () => Navigator.of(ctx).pop(false),
          child: GlassBox(
            radius: 34,
            borderWidth: 5,
            gradient: kMint,
            child: centerText(cancelLabel, londrina(48, shadows: kTextShadow)),
          ),
        )),
        at(560, 1050, 350, 130, Tap(
          onTap: () => Navigator.of(ctx).pop(true),
          child: GlassBox(
            radius: 34,
            borderWidth: 5,
            gradient: kOrange,
            child: centerText(confirmLabel, londrina(48, shadows: kTextShadow)),
          ),
        )),
        at(890, 520, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(ctx).pop(false))),
      ]);
  return res ?? false;
}

/// Oyun tasarımına uygun ödüllü video / bonus bekleme ekranı.
void showFakeAd(BuildContext context, {required VoidCallback onDone}) {
  showStageDialog<void>(context, (ctx) => [_RewardedVideoPanel(onDone: onDone)]);
}

/// Enerji bittiğinde oyuncuyu ana menüye dönmeye zorlamadan bulunduğu ekranda
/// +1 enerji kazanma imkanı sunar.
Future<void> promptRefillEnergy(BuildContext context, {VoidCallback? onRefilled}) async {
  final state = GameState.instance;
  if (state.energy >= GameState.maxEnergy) {
    toast(context, 'Enerjin zaten dolu!');
    return;
  }
  final ok = await showStageConfirm(
    context,
    title: state.energy <= 0 ? 'Enerjin Bitti!' : 'Enerji Kazan',
    message: 'Kısa bonusu izleyerek hemen +1 enerji kazanmak ister misin?',
    confirmLabel: 'İzle (+1)',
    cancelLabel: 'Vazgeç',
  );
  if (ok && context.mounted) {
    showFakeAd(context, onDone: () {
      state.addEnergy(1);
      if (context.mounted) {
        toast(context, '+1 enerji kazandın!');
        onRefilled?.call();
      }
    });
  }
}

class _RewardedVideoPanel extends StatefulWidget {
  const _RewardedVideoPanel({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_RewardedVideoPanel> createState() => _RewardedVideoPanelState();
}

class _RewardedVideoPanelState extends State<_RewardedVideoPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      at(120, 620, 840, 680, svg('daily_panel.svg')),
      at(160, 710, 760, 90, centerText('Bonus Ödül', londrina(76, shadows: kTextShadow))),
      at(460, 830, 160, 160, const GlassBox(
        radius: 80,
        gradient: kMint,
        borderWidth: 5,
        child: Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 100)),
      )),
      at(160, 1020, 760, 60, centerText('Ödülün hazırlanıyor...', exo(38, weight: 600, shadows: kTextShadow))),
      at(200, 1110, 680, 64, AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A2A),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFF2FD46B), width: 4),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            bottom: 10,
            width: (680 - 20) * Curves.easeInOut.transform(_c.value).clamp(0.08, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: kMint,
              ),
            ),
          ),
        ]),
      )),
    ]);
  }
}

/// Figma: "Daily Login" (25:195) ve "Daily Aldıktan sonra" (25:7087)
Future<void> showDailyReward(BuildContext context) {
  return showStageDialog(context, (ctx) => [const _DailyPanel()]);
}

class _Cell {
  const _Cell(this.x, this.y, this.w, this.ray, this.rayBox, this.icon, this.iconBox, this.amountY, this.claimed, this.check);

  final double x, y, w;
  final String ray;
  final Rect rayBox;
  final String icon;
  final Rect iconBox;
  final double amountY;
  final Gradient claimed;
  final Offset check;
}

LinearGradient _up(Color bottom, Color top) =>
    LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [bottom, top]);

final _cells = [
  _Cell(173, 394, 200, 'd_union.svg', const Rect.fromLTWH(178, 424, 190, 190), 'd_coin.svg', const Rect.fromLTWH(233, 479, 80, 80), 589,
      _up(const Color(0xCCD6D85D), const Color(0xCCECEDB0)), const Offset(224, 481)),
  _Cell(452, 394, 200, 'd_union1.svg', const Rect.fromLTWH(457, 424, 190, 190), 'd_coin.svg', const Rect.fromLTWH(512, 479, 80, 80), 589,
      _up(const Color(0xCC555879), const Color(0xCC98A1BC)), const Offset(502, 479)),
  _Cell(728, 394, 200, 'd_union1.svg', const Rect.fromLTWH(733, 424, 190, 190), 'd_coin.svg', const Rect.fromLTWH(788, 479, 80, 80), 589,
      _up(const Color(0xCC458C49), const Color(0xCCFFF4A4)), const Offset(778, 479)),
  _Cell(174, 744, 200, 'd_union1.svg', const Rect.fromLTWH(179, 774, 190, 190), 'd_coin.svg', const Rect.fromLTWH(234, 829, 80, 80), 939,
      _up(const Color(0xCC819A91), const Color(0xCCFFF2E0)), const Offset(224, 829)),
  _Cell(452, 744, 200, 'd_union1.svg', const Rect.fromLTWH(457, 774, 190, 190), 'd_coin.svg', const Rect.fromLTWH(512, 829, 80, 80), 939,
      _up(const Color(0xCCE8988A), const Color(0xCCFFEAD8)), const Offset(502, 829)),
  _Cell(728, 744, 200, 'd_union3.svg', const Rect.fromLTWH(733, 769, 200, 200), 'd_bag_big.svg', const Rect.fromLTWH(772.57, 801.7, 110, 135), 939,
      _up(const Color(0xCCC0C9EE), const Color(0xCCFFF2E0)), const Offset(777, 829)),
  _Cell(365, 1094, 350, 'd_union2.svg', const Rect.fromLTWH(395, 1054, 290, 290), 'd_coin2.svg', const Rect.fromLTWH(419.52, 1104, 230, 200), 1297,
      _up(const Color(0xCC3F7D58), const Color(0xBFEFEFEF)), const Offset(490, 1179)),
];

Widget _rect(Rect r, Widget child) => at(r.left, r.top, r.width, r.height, child);

class _DailyPanel extends StatefulWidget {
  const _DailyPanel();

  @override
  State<_DailyPanel> createState() => _DailyPanelState();
}

class _DailyPanelState extends State<_DailyPanel> {
  final _state = GameState.instance;

  void _claim(int multiplier) {
    final reward = _state.claimDaily(multiplier: multiplier);
    setState(() {});
    toast(context, '+$reward coin kazandın!');
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canClaim = _state.canClaimDaily;
    final claimedCount = _state.dailyClaimedInCycle;
    final today = canClaim ? _state.dailyIndex : -1;
    final pillY = [664.0, 664.0, 664.0, 1014.0, 1014.0, 1014.0, 1364.0];
    final pillX = [173.0, 452.0, 728.0, 173.0, 452.0, 728.0, 452.0];

    return Stack(clipBehavior: Clip.none, children: [
      at(80, 250, 920, 1520, svg('daily_panel.svg')),
      for (var i = 0; i < 7; i++) ...() {
        final c = _cells[i];
        final claimed = i < claimedCount;
        final isToday = i == today;
        return [
          at(c.x, c.y, c.w, 250, GlassBox(
            radius: 40,
            borderWidth: 6,
            blur: 4,
            gradient: claimed ? c.claimed : null,
            color: isToday ? const Color(0x40FFFFFF) : const Color(0x1AFFFFFF),
          )),
          if (isToday) at(c.x, c.y, c.w, 250, const GlowFrame(radius: 40, color: Colors.white, width: 8, blur: 16)),
          if (!claimed) _rect(c.rayBox, svg(c.ray)),
          _rect(c.iconBox, Opacity(opacity: claimed ? 0.55 : 1, child: svg(c.icon))),
          at(c.x, c.amountY, c.w, 50, centerText('${GameState.dailyRewards[i]}', londrina(40, shadows: kTextShadow))),
          if (claimed) at(c.check.dx, c.check.dy, 100.342, 80.506, svg('d_check.svg')),
          at(pillX[i], pillY[i], 200, 50, GlassBox(
            radius: 40,
            borderWidth: 3,
            gradient: isToday
                ? _up(const Color(0xFFF68537), const Color(0xFFEAD8A4))
                : claimed
                    ? c.claimed
                    : _up(const Color(0x8063D998), const Color(0x80FFFFFF)),
            child: centerText('GÜN ${i + 1}', londrina(32, shadows: kTextShadow)),
          )),
        ];
      }(),
      at(895, 220, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
      if (canClaim) ...[
        // x2 Topla (bonus ile)
        at(339, 1451, 402, 123, Tap(
          onTap: () => showFakeAd(context, onDone: () => _claim(2)),
          child: Stack(clipBehavior: Clip.none, children: [
            const Positioned.fill(child: GlowFrame(radius: 27, color: Color(0x88FFFFFF), width: 15, blur: 50)),
            Positioned.fill(child: svg('d_group902.svg')),
            at(80.4, 27.5, 74, 14, Transform.rotate(angle: -0.122, child: svg('d_watch_top.svg'))),
            at(81, 44, 70, 50, DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFF17191C), border: Border.all(color: Colors.black, width: 2)),
            )),
            at(81, 44.01, 70, 10, svg('d_watch_stripe.svg')),
            at(108, 65, 16.87, 18.699, svg('d_watch_play.svg')),
            Positioned(left: 167, top: 31, child: Text('x2 Topla', style: londrina(48, shadows: kTextShadow))),
          ]),
        )),
        // Topla
        at(390, 1605, 300, 100, Tap(
          onTap: () => _claim(1),
          child: GlassBox(
            radius: 25,
            blur: 10,
            borderWidth: 4,
            color: const Color(0x66111111),
            child: centerText('Topla', londrina(48)),
          ),
        )),
      ] else
        at(240, 1500, 600, 120, centerText('Yarın yeni ödülün seni bekliyor!', londrina(44, shadows: kTextShadow))),
    ]);
  }
}
