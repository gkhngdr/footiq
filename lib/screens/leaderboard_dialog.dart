import 'package:flutter/material.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';

/// Sezon Ligi ve Sıralama tablosu. İlk 3 ödül bilgisi, madalyalı sıralama listesi
/// ve en altta sabit "Senin Sıran" kartıyla çalışır.
Future<void> showLeaderboard(BuildContext context) {
  return showStageDialog(context, (ctx) => [const _LeaderboardPanel()]);
}

class _LeaderboardPanel extends StatefulWidget {
  const _LeaderboardPanel();

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  late List<({String name, int trophies, bool isMe})> _rows = _mergeRows(const []);

  @override
  void initState() {
    super.initState();
    _loadOnline();
  }

  List<({String name, int trophies, bool isMe})> _mergeRows(List<({String name, int trophies})> online) {
    final s = GameState.instance;
    final byName = <String, int>{
      for (final r in GameState.seasonRivals) r.name: r.trophies,
      for (final r in online) r.name: r.trophies,
    };
    byName[s.playerName] = s.trophies;

    return [
      for (final e in byName.entries)
        (name: e.key, trophies: e.value, isMe: e.key == s.playerName),
    ]..sort((a, b) {
        final cmp = b.trophies.compareTo(a.trophies);
        if (cmp != 0) return cmp;
        if (a.isMe) return -1;
        if (b.isMe) return 1;
        return a.name.compareTo(b.name);
      });
  }

  Future<void> _loadOnline() async {
    final s = GameState.instance;
    final online = await Cloud.leaderboard();
    if (s.isAccount) {
      s.refreshRank();
    }
    if (mounted && online.isNotEmpty) {
      setState(() => _rows = _mergeRows(online));
    }
  }

  Widget _prizeChip(String medal, String title, String reward, Color border) {
    return Expanded(
      child: GlassBox(
        radius: 24,
        color: const Color(0xAA0D261F),
        borderWidth: 3,
        borderColor: border,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$medal $title', style: londrina(26, color: border, shadows: kTextShadow)),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 26, height: 26, child: svg('coin.svg')),
                  const SizedBox(width: 6),
                  Text(reward, style: exo(22, weight: 800, shadows: kTextShadow)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final myIndex = rows.indexWhere((r) => r.isMe);
    final myRow = myIndex >= 0 ? rows[myIndex] : null;
    final now = DateTime.now();
    final left = DateTime(now.year, now.month + 1).difference(now);

    return Stack(clipBehavior: Clip.none, children: [
      at(80, 220, 920, 1560, svg('daily_panel.svg')),
      at(80, 290, 920, 88, centerText('Sezon Sıralaması', londrina(78, shadows: kTextShadow))),
      at(
        220,
        378,
        640,
        44,
        GlassBox(
          radius: 22,
          color: const Color(0x880D261F),
          borderWidth: 2,
          borderColor: const Color(0x99FFE27A),
          child: centerText(
            'Sezon bitimine: ${left.inDays} gün ${left.inHours % 24} saat  •  İlk 3\'e Sezon Ödülü',
            exo(22, weight: 700, color: const Color(0xFFFFE27A)),
          ),
        ),
      ),
      // Sezon ödül rozetleri (1., 2., 3.)
      at(
        130,
        436,
        820,
        102,
        Row(children: [
          _prizeChip('🥇', '1. Ödülü', '+10.000', const Color(0xFFFFE27A)),
          const SizedBox(width: 14),
          _prizeChip('🥈', '2. Ödülü', '+5.000', const Color(0xFFE0E6ED)),
          const SizedBox(width: 14),
          _prizeChip('🥉', '3. Ödülü', '+2.500', const Color(0xFFFFB07C)),
        ]),
      ),
      at(
        130,
        556,
        820,
        960,
        ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final r = rows[i];
            final isTop3 = i < 3;
            final badgeColor = switch (i) {
              0 => const Color(0xFFFFE27A),
              1 => const Color(0xFFE0E6ED),
              2 => const Color(0xFFFFB07C),
              _ => Colors.white,
            };
            final medal = switch (i) {
              0 => '🥇 #1',
              1 => '🥈 #2',
              2 => '🥉 #3',
              _ => '#${i + 1}',
            };
            return SizedBox(
              height: 92,
              child: GlassBox(
                radius: 30,
                color: r.isMe
                    ? const Color(0xCCF68537)
                    : isTop3
                        ? const Color(0xAA0D261F)
                        : const Color(0x33FFFFFF),
                borderWidth: r.isMe || isTop3 ? 4 : 1.5,
                borderColor: r.isMe ? const Color(0xFFFFE27A) : (isTop3 ? badgeColor : Colors.white30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    SizedBox(
                      width: 125,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          medal,
                          style: londrina(isTop3 ? 42 : 44, color: badgeColor, shadows: kTextShadow),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.isMe ? '${r.name} (Sen)' : r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: exo(34, weight: 700, shadows: kTextShadow),
                      ),
                    ),
                    SizedBox(width: 44, height: 44, child: png('trophy.png')),
                    const SizedBox(width: 10),
                    Text(formatNumber(r.trophies), style: londrina(46, color: badgeColor, shadows: kTextShadow)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      // Altta sabit "Senin Sıran" kartı
      if (myRow != null)
        at(
          130,
          1545,
          820,
          115,
          GlassBox(
            radius: 36,
            gradient: kOrange,
            borderWidth: 5,
            borderColor: const Color(0xFFFFE27A),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(children: [
                Text(
                  'Senin sıran: #${myIndex + 1}',
                  style: londrina(42, color: const Color(0xFFFFE27A), shadows: kTextShadow),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    myRow.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: exo(30, weight: 700, shadows: kTextShadow),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(width: 46, height: 46, child: png('trophy.png')),
                const SizedBox(width: 8),
                Text(formatNumber(myRow.trophies), style: londrina(44, shadows: kTextShadow)),
              ]),
            ),
          ),
        ),
      at(895, 190, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
    ]);
  }
}
