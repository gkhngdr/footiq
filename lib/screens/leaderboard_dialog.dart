import 'package:flutter/material.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';

/// Sezon Ligi ve Sıralama tablosu. Hem çevrimiçi gerçek oyuncuları hem de
/// sezon ligindeki rakipleri birleştirerek her zaman dolu ve canlı çalışır.
Future<void> showLeaderboard(BuildContext context) {
  return showStageDialog(context, (ctx) => [const _LeaderboardPanel()]);
}

class _LeaderboardPanel extends StatefulWidget {
  const _LeaderboardPanel();

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  List<({String name, int trophies, bool isMe})>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = GameState.instance;
    var online = <({String name, int trophies})>[];
    if (s.isAccount) {
      online = await Cloud.leaderboard();
      s.refreshRank();
    }
    final byName = <String, int>{
      for (final r in GameState.seasonRivals) r.name: r.trophies,
      for (final r in online) r.name: r.trophies,
    };
    byName[s.playerName] = s.trophies;

    final merged = [
      for (final e in byName.entries)
        (name: e.key, trophies: e.value, isMe: e.key == s.playerName),
    ]..sort((a, b) {
        final cmp = b.trophies.compareTo(a.trophies);
        if (cmp != 0) return cmp;
        if (a.isMe) return -1;
        if (b.isMe) return 1;
        return a.name.compareTo(b.name);
      });

    if (mounted) setState(() => _rows = merged);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final myIndex = rows?.indexWhere((r) => r.isMe) ?? -1;
    return Stack(clipBehavior: Clip.none, children: [
      at(80, 250, 920, 1520, svg('daily_panel.svg')),
      at(80, 325, 920, 100, centerText('Sezon Sıralaması', londrina(84, shadows: kTextShadow))),
      if (rows == null)
        at(80, 800, 920, 200, const Center(child: CircularProgressIndicator(color: Color(0xFF63D998), strokeWidth: 8)))
      else
        at(140, 450, 800, 1180, ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final r = rows[i];
            return SizedBox(
              height: 92,
              child: GlassBox(
                radius: 30,
                color: r.isMe ? const Color(0x80F68537) : const Color(0x26FFFFFF),
                borderWidth: r.isMe ? 4 : 1,
                borderColor: r.isMe ? const Color(0xFFFFE27A) : Colors.white30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        '#${i + 1}',
                        style: londrina(48, color: i < 3 ? const Color(0xFFFFE27A) : Colors.white, shadows: kTextShadow),
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
                    Text(formatNumber(r.trophies), style: londrina(46, shadows: kTextShadow)),
                  ]),
                ),
              ),
            );
          },
        )),
      if (myIndex >= 0)
        at(80, 1660, 920, 70, centerText('Senin sıran: #${myIndex + 1}', exo(40, weight: 700, shadows: kTextShadow))),
      at(895, 220, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
    ]);
  }
}
