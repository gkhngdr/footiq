import 'package:flutter/material.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/ui.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'preview.dart';

/// Figma: "Loading Screen" (25:152)
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    // precacheImage context'e ihtiyaç duyar; ilk kare çizildikten sonra başla.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    // Bulut başlatma tamamlandıktan sonra yerel durum okunur ve profil senkronize edilir.
    final Future<void> loading = () async {
      await Cloud.init().timeout(const Duration(seconds: 5), onTimeout: () {});
      await GameState.instance.load();
      if (GameState.instance.isAccount) {
        await Cloud.pullProfile().timeout(const Duration(seconds: 5), onTimeout: () {});
        GameState.instance.refreshRank();
      }
    }();
    // İlk açılışta yalnızca giriş ve ana menü görsellerini önbelleğe al (RAM sıçramasını önler).
    for (final name in [
      'bg_splash.png',
      'bg_main.png',
      'card_play_b.png',
      'card_pvp_b.png',
      'trophy.png',
    ]) {
      precacheImage(AssetImage(fig(name)), context);
    }
    await Future.wait([loading, _progress.forward()]);
    if (!mounted) return;
    if (kPreview && previewScreen(context)) return;
    final next = GameState.instance.loggedIn ? const MainScreen() : const LoginScreen();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => next,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stage(background: 'bg_splash.png', children: [
      at(243, 200, 594, 620, png('logo.png')),
      at(175, 1564, 730, 86, AnimatedBuilder(
        animation: _progress,
        builder: (_, _) => _LoadingBar(value: Curves.easeInOut.transform(_progress.value)),
      )),
      at(0, 1680, kDesignW, 50, centerText('Yükleniyor...', londrina(40, spacing: 0.05))),
    ]);
  }
}

/// Figma "Group 884" yükleme çubuğu: koyu yeşil zemin, parlak yeşil dolgu.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A2A),
            borderRadius: BorderRadius.circular(43),
            border: Border.all(color: const Color(0xFF2FD46B), width: 5),
            boxShadow: const [BoxShadow(color: Color(0x992FD46B), blurRadius: 18)],
          ),
        ),
      ),
      Positioned(
        left: 14,
        top: 14,
        bottom: 14,
        width: (730 - 28) * value.clamp(0.06, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFA6F5A0), Color(0xFF4CC94A), Color(0xFF2E9E3A)],
            ),
          ),
        ),
      ),
    ]);
  }
}
