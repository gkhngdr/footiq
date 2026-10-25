import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/sound.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';

/// "Davet Et Kazan": kendi davet kodunu paylaş, arkadaşının kodunu gir (+500 coin).
/// Hem hesaplı hem misafir oyuncularda çalışır.
Future<void> showInvite(BuildContext context, {String? initialCode}) {
  return showStageDialog(
    context,
    (ctx) => [_InvitePanel(initialCode: initialCode)],
    keyboardShift: true,
  );
}

class _InvitePanel extends StatefulWidget {
  const _InvitePanel({this.initialCode});

  final String? initialCode;

  @override
  State<_InvitePanel> createState() => _InvitePanelState();
}

class _InvitePanelState extends State<_InvitePanel> {
  late final TextEditingController _input = TextEditingController(text: widget.initialCode ?? '');
  final _state = GameState.instance;
  String? _code;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code = _state.localInviteCode;
    if (_state.isAccount) {
      Cloud.inviteCode().then((c) {
        if (mounted && c != null && c.isNotEmpty) setState(() => _code = c.toUpperCase());
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _copyMyCode() {
    final c = _code?.toUpperCase();
    if (c == null) return;
    Clipboard.setData(ClipboardData(text: c));
    toast(context, 'Davet kodun ($c) kopyalandı!');
  }

  Future<void> _pasteFriendCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim().toUpperCase() ?? '';
    if (text.isEmpty) {
      if (mounted) toast(context, 'Panoda kopyalanmış bir kod bulunamadı.');
      return;
    }
    final cleaned = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final clipped = cleaned.length > 8 ? cleaned.substring(0, 8) : cleaned;
    setState(() {
      _input.text = clipped;
      _input.selection = TextSelection.collapsed(offset: clipped.length);
    });
  }

  Future<void> _redeem() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final code = _input.text.trim().toUpperCase();
    if (_busy || !RegExp(r'^[A-Z0-9]{8}$').hasMatch(code)) {
      toast(context, 'Lütfen 8 haneli geçerli bir davet kodu gir.');
      return;
    }
    if (code == (_code?.toUpperCase() ?? _state.localInviteCode)) {
      toast(context, 'Kendi davet kodunu kullanamazsın.');
      return;
    }
    setState(() => _busy = true);
    var earned = 0;
    if (_state.isAccount) {
      earned = await Cloud.redeemInvite(code);
    }
    // Arkadaşı misafir moddaysa veya yerel kod paylaştıysa yerel davet ödülünü de destekle
    if (earned == 0 && _state.redeemGuestInvite(code)) {
      earned = 500;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (earned > 0) {
      Sound.coin();
      _input.clear();
      toast(context, '+$earned coin kazandın!');
    } else {
      toast(context, 'Kod geçersiz ya da daha önce davet ödülü aldın.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myCode = _code?.toUpperCase() ?? '...';
    final alreadyUsed = _state.guestInviteUsed;
    return Stack(clipBehavior: Clip.none, children: [
      at(80, 320, 920, 1280, svg('daily_panel.svg')),
      at(80, 395, 920, 95, centerText('Davet Et Kazan', londrina(56, shadows: kTextShadow))),
      at(130, 495, 820, 80, Center(
        child: Text(
          'Kodunu arkadaşınla paylaş veya arkadaşının kodunu aşağıya gir,\nikiniz de anında +500 Coin kazanın!',
          textAlign: TextAlign.center,
          style: exo(24, weight: 600, shadows: kTextShadow),
        ),
      )),

      // BÖLÜM 1: SENİN DAVET KODUN
      at(140, 600, 800, 44, Align(
        alignment: Alignment.centerLeft,
        child: Text('1. SENİN DAVET KODUN (Paylaş):', style: londrina(26, color: const Color(0xFFFFE27A), shadows: kTextShadow)),
      )),
      at(140, 650, 800, 130, Tap(
        onTap: _copyMyCode,
        child: GlassBox(
          radius: 34,
          borderWidth: 5,
          borderColor: Colors.white,
          color: const Color(0xBB0D261F),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(myCode, style: londrina(48, color: const Color(0xFFAEF8EA), shadows: kTextShadow)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: kOrange,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.copy_rounded, color: Colors.white, size: 30),
                    const SizedBox(width: 8),
                    Text('Kopyala', style: londrina(26, shadows: kTextShadow)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      )),

      // BÖLÜM 2: ARKADAŞININ KODUNU GİR (+500 COIN)
      at(140, 835, 800, 44, Align(
        alignment: Alignment.centerLeft,
        child: Text(
          alreadyUsed ? '2. ARKADAŞ DAVET ÖDÜLÜ (Alındı ✓):' : '2. ARKADAŞININ KODUNU BURAYA GİR (+500 Coin):',
          style: londrina(26, color: const Color(0xFFFFE27A), shadows: kTextShadow),
        ),
      )),
      at(140, 890, 800, 125, GlassBox(
        radius: 34,
        borderWidth: 5,
        borderColor: const Color(0xFFFFE27A),
        color: const Color(0xEE091E18),
        child: Padding(
          padding: const EdgeInsets.only(left: 28, right: 20),
          child: Center(
            child: Row(children: [
              const Icon(Icons.vpn_key_rounded, color: Color(0xFFFFE27A), size: 44),
              const SizedBox(width: 18),
              Expanded(
                child: TextField(
                  controller: _input,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  maxLength: 8,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _redeem(),
                  style: londrina(38, color: Colors.white),
                  cursorColor: const Color(0xFFFFE27A),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    counterText: '',
                    border: InputBorder.none,
                    hintText: '8 HANELİ KODU YAZ...',
                    hintStyle: exo(24, weight: 600, color: Colors.white54),
                  ),
                ),
              ),
              Tap(
                onTap: _pasteFriendCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.content_paste_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 6),
                    Text('Yapıştır', style: exo(22, weight: 700)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      )),
      at(190, 1055, 700, 135, Tap(
        onTap: _redeem,
        child: GlassBox(
          radius: 34,
          borderWidth: 5,
          gradient: kMint,
          child: _busy
              ? const Center(child: SizedBox(width: 50, height: 50, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6)))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 52, height: 52, child: svg('coin.svg')),
                        const SizedBox(width: 14),
                        Text('Kodu Kullan', style: londrina(38, shadows: kTextShadow)),
                        const SizedBox(width: 12),
                        Text('(+500)', style: londrina(30, color: const Color(0xFFFFE27A), shadows: kTextShadow)),
                      ],
                    ),
                  ),
                ),
        ),
      )),
      at(140, 1220, 800, 60, centerText(
        'Her oyuncu 1 kez arkadaş davet kodu kullanarak +500 Coin kazanabilir.',
        exo(25, color: Colors.white70),
      )),
      at(905, 285, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
    ]);
  }
}
