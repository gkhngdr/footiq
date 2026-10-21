import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';

/// "Davet Et Kazan": kendi davet kodunu paylaş, arkadaşının kodunu gir.
/// Hem hesaplı hem misafir oyuncularda çalışır.
Future<void> showInvite(BuildContext context) {
  return showStageDialog(context, (ctx) => [const _InvitePanel()]);
}

class _InvitePanel extends StatefulWidget {
  const _InvitePanel();

  @override
  State<_InvitePanel> createState() => _InvitePanelState();
}

class _InvitePanelState extends State<_InvitePanel> {
  final _input = TextEditingController();
  final _state = GameState.instance;
  String? _code;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code = _state.localInviteCode;
    if (_state.isAccount) {
      Cloud.inviteCode().then((c) {
        if (mounted && c != null) setState(() => _code = c);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _input.text.trim();
    if (_busy || !RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(code)) {
      toast(context, 'Davet kodu 8 karakterli olmalı.');
      return;
    }
    setState(() => _busy = true);
    var earned = 0;
    if (_state.isAccount) {
      earned = await Cloud.redeemInvite(code);
    } else if (_state.redeemGuestInvite(code)) {
      earned = 500;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    toast(context, earned > 0 ? '+$earned coin kazandın!' : 'Kod geçersiz ya da daha önce davet kodu kullanmışsın.');
    if (earned > 0) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      at(80, 420, 920, 1080, svg('daily_panel.svg')),
      at(80, 500, 920, 100, centerText('Davet Et Kazan', londrina(80, shadows: kTextShadow))),
      at(140, 620, 800, 110, Center(
        child: Text('Arkadaşınla kodunu paylaş, 500 coin ödül kazan!', textAlign: TextAlign.center, style: exo(34, shadows: kTextShadow)),
      )),
      at(140, 750, 800, 130, Tap(
        onTap: _code == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: _code!.toUpperCase()));
                toast(context, 'Davet kodun kopyalandı!');
              },
        child: GlassBox(
          radius: 34,
          borderWidth: 5,
          color: const Color(0x66111111),
          child: centerText(_code?.toUpperCase() ?? '...', londrina(72, shadows: kTextShadow)),
        ),
      )),
      at(80, 885, 920, 50, centerText('Kopyalamak için koda dokun', exo(26, color: Colors.white70))),
      at(140, 970, 800, 100, GlassBox(
        radius: 50,
        blur: 8,
        borderWidth: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: TextField(
            controller: _input,
            maxLength: 8,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            style: poppins(34, color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: 'ARKADAŞININ KODU',
              hintStyle: poppins(28, weight: FontWeight.w300, color: Colors.white60),
            ),
          ),
        ),
      )),
      at(240, 1110, 600, 130, Tap(
        onTap: _redeem,
        child: GlassBox(
          radius: 34,
          borderWidth: 5,
          gradient: kMint,
          child: _busy
              ? const Center(child: SizedBox(width: 50, height: 50, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6)))
              : centerText('Kodu Kullan', londrina(52, shadows: kTextShadow)),
        ),
      )),
      at(905, 380, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
    ]);
  }
}
