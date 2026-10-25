import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'sound.dart';

/// Figma tasarımları 1080x1920 boyutunda. Tüm ekranlar bu sanal tuval
/// üzerinde, Figma'daki koordinatlarla çizilir ve ekrana ölçeklenir.
const double kDesignW = 1080;
const double kDesignH = 1920;

String fig(String name) => 'assets/figma/$name';

class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.background,
    required this.children,
    this.exactBackground = false,
    this.backgroundBlur = 0,
    this.keyboardShift = false,
  });

  /// Arka planı bulanıklaştırır (soru ekranında okunabilirlik için).
  final double backgroundBlur;

  final String background;
  final List<Widget> children;

  /// Arka plan görseli tuvalle birebir hizalanmalıysa (üzerinde çizili
  /// düğmeler varsa) true. Kenarlarda kalan boşluk yine görselle doldurulur.
  final bool exactBackground;

  /// Klavye açıldığında tuvali küçültmek yerine form alanlarını yukarı kaydırır.
  final bool keyboardShift;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final shiftY = (keyboardShift && bottomInset > 0) ? -(bottomInset * 0.85).clamp(0.0, 260.0) : 0.0;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: backgroundBlur > 0
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: backgroundBlur, sigmaY: backgroundBlur, tileMode: TileMode.mirror),
                        child: Image.asset(fig(background), fit: BoxFit.cover, gaplessPlayback: true),
                      )
                    : Image.asset(fig(background), fit: BoxFit.cover, gaplessPlayback: true),
              ),
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: kDesignW,
                    height: kDesignH,
                    child: Stack(clipBehavior: Clip.none, children: [
                      if (exactBackground)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: Image.asset(fig(background), fit: BoxFit.fill, gaplessPlayback: true),
                          ),
                        ),
                      if (shiftY != 0)
                        Transform.translate(
                          offset: Offset(0, shiftY),
                          child: SizedBox(
                            width: kDesignW,
                            height: kDesignH,
                            child: Stack(clipBehavior: Clip.none, children: children),
                          ),
                        )
                      else
                        ...children,
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma koordinatlarıyla konumlandırma kısayolu.
Widget at(double x, double y, double w, double h, Widget child) =>
    Positioned(left: x, top: y, width: w, height: h, child: child);

Widget svg(String name, {BoxFit fit = BoxFit.fill}) =>
    SvgPicture.asset(fig(name), fit: fit);

Widget png(String name, {BoxFit fit = BoxFit.cover}) =>
    Image.asset(fig(name), fit: fit, filterQuality: FilterQuality.medium, gaplessPlayback: true);

/// Figma'daki "-scale-y-100 rotate-180" = yatay ayna.
Widget flipX(Widget child) =>
    Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1), child: child);

Widget flipY(Widget child) =>
    Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(1, -1, 1), child: child);

/// Ana oyun başlıkları, düğmeler ve sayaçlar için %100 kusursuz Türkçe destekli (ğ, ş, ı, İ, ö, ü, ç),
/// modern, güçlü spor ve bilgi yarışması fontu (Montserrat ExtraBold).
TextStyle londrina(double size, {Color color = Colors.white, double spacing = -0.015, List<Shadow>? shadows, FontWeight weight = FontWeight.w800}) =>
    TextStyle(
      fontFamily: 'Montserrat',
      fontFamilyFallback: const ['Outfit', 'Rubik'],
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: size * spacing,
      height: 1.15,
      shadows: shadows,
    );

/// Soru metinleri, açıklamalar ve listeler için %100 Türkçe destekli,
/// net ve dengeli modern font (Montserrat).
TextStyle exo(double size, {Color color = Colors.white, double weight = 700, List<Shadow>? shadows}) => TextStyle(
      fontFamily: 'Montserrat',
      fontFamilyFallback: const ['Outfit', 'Rubik'],
      fontSize: size,
      color: color,
      fontWeight: weight >= 800
          ? FontWeight.w800
          : (weight >= 700
              ? FontWeight.w700
              : (weight >= 600 ? FontWeight.w600 : (weight >= 500 ? FontWeight.w500 : FontWeight.w400))),
      letterSpacing: -0.2,
      height: 1.25,
      shadows: shadows,
    );

/// Giriş ekranı ve form alanları için modern font (Montserrat).
TextStyle poppins(double size, {FontWeight weight = FontWeight.w600, Color color = Colors.white, double spacing = 0}) =>
    TextStyle(
      fontFamily: 'Montserrat',
      fontFamilyFallback: const ['Outfit', 'Rubik'],
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
      height: 1.25,
    );

const kTextShadow = [Shadow(color: Color(0xAA000000), offset: Offset(0, 3), blurRadius: 5)];

Widget centerText(String text, TextStyle style) =>
    Center(child: Text(text, style: style, textAlign: TextAlign.center, maxLines: 1, softWrap: false));

/// Kenarlıklı, yuvarlak köşeli bir kutu; isteğe bağlı arka plan bulanıklığı.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.radius,
    this.color = const Color(0x33FFFFFF),
    this.gradient,
    this.borderWidth = 0,
    this.borderColor = Colors.white,
    this.blur = 0,
    this.child,
  });

  final double radius;
  final Color color;
  final Gradient? gradient;
  final double borderWidth;
  final Color borderColor;
  final double blur;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
      ),
      child: child,
    );
    if (blur > 0) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: box),
      );
    }
    return box;
  }
}

/// Figma'daki "blur + border" ile yapılan parlama çerçevesi.
class GlowFrame extends StatelessWidget {
  const GlowFrame({super.key, required this.radius, required this.color, this.width = 5, this.blur = 9.5});

  final double radius;
  final Color color;
  final double width;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: color, width: width),
          ),
        ),
      ),
    );
  }
}

/// Basılınca hafifçe küçülen dokunma alanı.
class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.playSound = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool playSound;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.playSound) Sound.click();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

/// Tasarımdaki krem/turuncu yuvarlak düğmelerin dış halkası.
const kCreamRing = LinearGradient(
  colors: [Color(0xFFFFF6E2), Color(0xFFFFD0A7), Color(0xFFFFDBC2)],
  stops: [0.02128, 0.59667, 0.90968],
);

const kOrange = LinearGradient(colors: [Color(0xFFED7F42), Color(0xFFDF673E)], stops: [0, 0.43269]);

const kMint = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFAEF8EA), Color(0xFF63D998), Color(0xFF029D88)],
  stops: [0, 0.528846, 1],
);

String formatNumber(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(3)}M';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: exo(16)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xEE0D3329),
      duration: const Duration(seconds: 2),
    ));
}

/// Oyun ekranları arasında yumuşak ve hızlı geçiş (200ms fade + hafif ölçekleme).
Future<T?> goStage<T>(BuildContext context, Widget screen, {bool replace = false}) {
  final route = PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => screen,
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(begin: 0.97, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}
