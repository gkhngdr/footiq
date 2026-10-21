import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'chapter_map_screen.dart';

/// Figma: "Single Game Mode Chapter Select" (25:12422) ve
/// "Chapter Finish and Lock" (25:12672) durumları.
class ChapterSelectScreen extends StatefulWidget {
  const ChapterSelectScreen({super.key});

  @override
  State<ChapterSelectScreen> createState() => _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends State<ChapterSelectScreen> {
  final _state = GameState.instance;

  static const _tops = [344.0, 625.0, 916.0, 1202.0];
  static const _glow = [Colors.white, Color(0xFF79F3F3), Color(0xFFFFE100), Color(0xFFD71C00)];

  /// Kart görselinin Figma'daki dikey kaydırma oranı (h=%751.58).
  static const _imageTop = [-1.8014, -1.6529, -0.9688, -5.2385];

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

  void _open(int chapter) {
    if (!_state.isChapterUnlocked(chapter)) {
      toast(context, 'Chapter $chapter kilitli. Önce Chapter ${chapter - 1}\'deki tüm seviyeleri geç!');
      return;
    }
    goStage(context, ChapterMapScreen(chapter: chapter));
  }

  Widget _cardImage(String image, double imageTop) => ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned(left: 0, top: imageTop * 246, width: 1040, height: 7.5158 * 246, child: png(image, fit: BoxFit.fill)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final totalStars = List.generate(4, (i) => _state.chapterStars(i + 1)).fold(0, (a, b) => a + b);
    return Stage(background: 'bg_map.png', children: [
      const TopHud(top: 140),
      at(923, 80, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
      for (var i = 0; i < 4; i++) ...() {
        final chapter = i + 1;
        final unlocked = _state.isChapterUnlocked(chapter);
        final completed = _state.isChapterCompleted(chapter);
        final earnedStars = _state.chapterStars(chapter);
        return [
          at(20, _tops[i], 1040, 246, GlowFrame(radius: 40, color: _glow[i], blur: i == 3 ? 10.7 : 9.5)),
          at(20, _tops[i], 1040, 246, Tap(
            onTap: () => _open(chapter),
            child: Stack(fit: StackFit.expand, children: [
              _cardImage('chapter$chapter.png', _imageTop[i]),
              if (completed) const GlassBox(radius: 40, color: Color(0x80F68537)),
              if (!unlocked) const GlassBox(radius: 40, color: Color(0x8C3A3A3A)),
              const GlassBox(radius: 40, color: Colors.transparent, borderWidth: 6),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Chapter $chapter', style: londrina(64, color: unlocked ? Colors.white : Colors.white54, shadows: kTextShadow)),
                    if (completed) const Padding(padding: EdgeInsets.only(left: 18), child: Icon(Icons.check_rounded, color: Colors.white, size: 76)),
                    if (!unlocked) const Padding(padding: EdgeInsets.only(left: 18), child: Icon(Icons.lock_rounded, color: Colors.white54, size: 60)),
                  ]),
                  if (unlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const StarIcon(filled: true, size: 36),
                        const SizedBox(width: 8),
                        Text('$earnedStars / 30', style: londrina(34, color: const Color(0xFFFFE27A), shadows: kTextShadow)),
                      ]),
                    ),
                ]),
              ),
            ]),
          )),
        ];
      }(),
      at(180, 1520, 720, 96, GlassBox(
        radius: 48,
        blur: 8,
        borderWidth: 3,
        color: const Color(0x80111111),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const StarIcon(filled: true, size: 52),
              const SizedBox(width: 16),
              Text('Toplam Yıldız: $totalStars / 120', style: londrina(42, shadows: kTextShadow)),
            ]),
          ),
        ),
      )),
    ]);
  }
}
