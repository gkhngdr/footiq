import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/ui.dart';
import '../screens/daily_reward_dialog.dart';
import '../screens/leaderboard_dialog.dart';
import '../screens/settings_dialog.dart';

/// Turuncu yuvarlak kapatma düğmesi (Figma "Group 890", 116.7px).
class CloseBtn extends StatelessWidget {
  const CloseBtn({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: SizedBox(
        width: 116.715,
        height: 116.715,
        child: Stack(children: [
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, gradient: kCreamRing))),
          const Positioned(
            left: 4.67,
            top: 1.64,
            width: 107.378,
            height: 107.378,
            child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, gradient: kOrange)),
          ),
          for (final angle in [-0.785398, 0.785398])
            Positioned(
              left: 35.66 + 22.7 - 26.26,
              top: 28.74 + 22.7 - 5.84,
              width: 52.522,
              height: 11.671,
              child: Transform.rotate(
                angle: angle,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Üst bilgi çubuğu (Figma "Main Hero"): avatar, isim, kupa, coin, enerji.
/// [top] ana ekranda 160, diğer ekranlarda 140.
class TopHud extends StatefulWidget {
  const TopHud({super.key, required this.top, this.rankX = 405, this.coverBaked = false});

  final double top;
  final double rankX;

  /// Arka plan görselinde hazır çizili bir üst çubuk varsa onu bulanıklaştırarak örter.
  final bool coverBaked;

  @override
  State<TopHud> createState() => _TopHudState();
}

class _TopHudState extends State<TopHud> {
  final _state = GameState.instance;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _syncTimer();
  }

  void _onStateChanged() {
    _syncTimer();
    if (mounted) setState(() {});
  }

  /// Yalnızca enerji doluyorken (6'nın altındayken) saniyelik sayaç çalıştır.
  void _syncTimer() {
    final needsTimer = _state.energy < GameState.maxEnergy;
    if (needsTimer && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_state.energy >= GameState.maxEnergy) {
          _timer?.cancel();
          _timer = null;
        }
      });
    } else if (!needsTimer && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.top;
    final energy = _state.energy;
    final next = _state.nextEnergyIn;
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(clipBehavior: Clip.none, children: [
          at(32, t + 9, 1028, 129, widget.coverBaked
              ? const GlassBox(radius: 100, color: Color(0xB3111111), blur: 18)
              : const GlassBox(radius: 100, color: Color(0x66111111), blur: 7.5)),
          // Enerji
          at(676, t + 68, 315, 53, svg('energy_back.svg')),
          if (energy > 0)
            at(
              681,
              t + 72,
              (306.0 * energy / GameState.maxEnergy).clamp(0.0, 306.0),
              45,
              ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(22.5),
                  right: Radius.circular(energy >= GameState.maxEnergy ? 10 : 6),
                ),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 306,
                  maxWidth: 306,
                  minHeight: 45,
                  maxHeight: 45,
                  child: SizedBox(
                    width: 306,
                    height: 45,
                    child: svg('energy_full.svg'),
                  ),
                ),
              ),
            ),
          at(676, t + 70, 300, 45, centerText('$energy / ${GameState.maxEnergy}', londrina(36, shadows: kTextShadow))),
          if (next != null)
            at(676, t + 122, 300, 30, centerText(
              '+1 ${next.inMinutes.toString().padLeft(2, '0')}:${(next.inSeconds % 60).toString().padLeft(2, '0')}',
              londrina(24),
            )),
          at(972, t + 57, 64.5, 76.5, svg('energy_icon.svg')),
          at(676, t + 57, 360, 76, Tap(
            onTap: () => promptRefillEnergy(context),
            child: const SizedBox.expand(),
          )),
          // Avatar
          at(20, t, 144, 144, svg('avatar_ring1.svg')),
          at(26.26, t + 6.26, 131.478, 131.478, svg('avatar_ring2.svg')),
          at(29.39, t + 9.39, 125.217, 125.217, Tap(onTap: () => showSettings(context), child: const _Avatar())),
          // İsim ve sıralama etiketleri
          Positioned(
            left: 174,
            top: t + 25,
            child: SizedBox(
              width: widget.rankX - 182,
              child: Text(_state.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: exo(24)),
            ),
          ),
          at(widget.rankX - 10, t + 15, 240, 52, Tap(
            onTap: () => showLeaderboard(context),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: Text('Rank: #${_state.displayRank}', style: exo(24)),
            ),
          )),
          // Kupa (dokununca sıralama açılır)
          at(174, t + 68, 220, 53, Tap(
            onTap: () => showLeaderboard(context),
            child: Stack(clipBehavior: Clip.none, children: [
              const Positioned.fill(
                child: GlassBox(
                  radius: 140,
                  borderWidth: 1,
                  gradient: LinearGradient(colors: [Color(0xFFF68537), Color(0xFFEAD8A4)], stops: [0.49038, 1]),
                ),
              ),
              at(0, 1, 50, 50, png('trophy.png')),
              Positioned(left: 58, top: 4, child: Text(formatNumber(_state.trophies), style: londrina(32, color: const Color(0xFFFEFEFE)))),
            ]),
          )),
          // Coin
          at(405, t + 68, 251, 53, const GlassBox(
            radius: 140,
            borderWidth: 1,
            gradient: LinearGradient(colors: [Color(0xFF58B387), Color(0xFFD6D85D)], stops: [0.38462, 1]),
          )),
          at(406, t + 69, 50, 50, svg('coin.svg')),
          Positioned(left: 464, top: t + 73, child: Text(formatNumber(_state.coins), style: londrina(32, color: const Color(0xFFFEFEFE)))),
          at(622.29, t + 72.64, 42.715, 42.715, Tap(
            onTap: () => showDailyReward(context),
            child: const _SmallPlus(),
          )),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    // Figma'da avatar görseli daire içinde kırpılmış ve aynalanmış.
    return ClipOval(
      child: LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth;
        return flipX(SizedBox(
          width: s,
          height: s,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
              left: -1.1348 * s,
              top: -0.0669 * s,
              width: 3.4934 * s,
              height: 1.6707 * s,
              child: png('avatar_b.png', fit: BoxFit.fill),
            ),
          ]),
        ));
      }),
    );
  }
}

class _SmallPlus extends StatelessWidget {
  const _SmallPlus();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, gradient: kCreamRing))),
      const Positioned(
        left: 1.7,
        top: 0.6,
        width: 39.298,
        height: 39.298,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFFF68537), Color(0xFFEAD8A4)]),
          ),
        ),
      ),
      Positioned(left: 11.74, top: 16.69, width: 19.222, height: 4.271, child: _bar()),
      Positioned(left: 19.22, top: 9.22, width: 4.271, height: 19.222, child: _bar()),
    ]);
  }

  Widget _bar() => DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)));
}

/// Yıldız şekli (seviye haritası ve sonuç ekranı).
class StarIcon extends StatelessWidget {
  const StarIcon({super.key, required this.filled, this.size = 80});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(filled)),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.filled);

  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.48;
      final a = -1.5708 + i * 0.6283185;
      final p = c + Offset(radius * math.cos(a), radius * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path.shift(const Offset(0, 4)), Paint()..color = const Color(0x55000000));
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: filled ? const [Color(0xFFFFE27A), Color(0xFFF7B500)] : const [Color(0xFF8C7A3E), Color(0xFF5E4F22)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.04
        ..strokeJoin = StrokeJoin.round
        ..color = filled ? const Color(0xFFC98A00) : const Color(0xFF4A3E1A),
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.filled != filled;
}
