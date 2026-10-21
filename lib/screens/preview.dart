import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../data/questions.dart';
import 'chapter_map_screen.dart';
import 'chapter_select_screen.dart';
import 'daily_reward_dialog.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'pvp_mode_screen.dart';
import 'quiz_screen.dart';
import 'result_dialog.dart';
import 'settings_dialog.dart';

/// Yalnızca `--dart-define=PREVIEW=true` ile derlenince açılır.
/// Web adresine `?screen=main` gibi bir parametre ekleyerek ekranları
/// doğrudan açmayı sağlar; tasarım kontrolü için kullanılır.
const kPreview = bool.fromEnvironment('PREVIEW');

bool previewScreen(BuildContext context) {
  final name = Uri.base.queryParameters['screen'];
  if (name == null) return false;
  final state = GameState.instance;
  if (Uri.base.queryParameters['progress'] == '1') {
    for (var l = 1; l <= 10; l++) {
      state.completeLevel(1, l, l <= 3 ? 3 : (l == 4 ? 2 : 1), 0);
    }
    for (var l = 1; l <= 3; l++) {
      state.completeLevel(2, l, 2, 0);
    }
  }
  // Diyalog önizlemelerinde günlük ödül penceresi araya girmesin.
  if (name != 'daily' && state.canClaimDaily) state.claimDaily();
  final nav = Navigator.of(context);
  void go(Widget w) => nav.pushReplacement(MaterialPageRoute(builder: (_) => w));
  switch (name) {
    case 'login':
      go(const LoginScreen());
    case 'main':
      go(const MainScreen());
    case 'daily':
      go(const MainScreen());
    case 'chapters':
      go(const ChapterSelectScreen());
    case 'map1' || 'map2' || 'map3' || 'map4':
      go(ChapterMapScreen(chapter: int.parse(name.substring(3))));
    case 'pvp':
      go(const PvpModeScreen());
    case 'quiz':
      go(const QuizScreen.single(chapter: 1, level: 1));
    case 'quizpvp':
      go(const QuizScreen.pvp(category: PvpCategory.benKimim));
    case 'settings':
      go(const _Host(dialog: showSettings));
    case 'result':
      go(_Host(
        dialog: (c) => showLevelResult(c, stars: 2, correct: 4, total: 5, coins: 60, trophies: 10, onReplay: () {}, onNext: () {}),
      ));
    case 'pvpresult':
      go(_Host(
        dialog: (c) => showPvpResult(c, outcome: 1, myScore: 1240, botScore: 860, botName: 'GolKralı34', trophies: 15, coins: 5000, onReplay: () {}),
      ));
    case 'dailyonly':
      go(const _Host(dialog: showDailyReward));
    default:
      return false;
  }
  return true;
}

class _Host extends StatefulWidget {
  const _Host({required this.dialog});

  final Future<void> Function(BuildContext) dialog;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.dialog(context));
  }

  @override
  Widget build(BuildContext context) => const MainScreen();
}
