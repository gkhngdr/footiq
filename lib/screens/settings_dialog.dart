import 'package:flutter/material.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';
import 'login_screen.dart';

/// Figma'da ayarlar ekranı yok; mevcut tasarım diliyle (1080x1920 Stage) oluşturuldu.
Future<void> showSettings(BuildContext context) {
  return showStageDialog(context, (ctx) => [const _SettingsPanel()], keyboardShift: true);
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel();

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  final _state = GameState.instance;
  late final TextEditingController _nameCtrl = TextEditingController(text: _state.playerName);
  bool _editingName = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveName() {
    final v = _nameCtrl.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$').hasMatch(v)) {
      toast(context, 'İsim 3-20 karakter olmalı (harf, rakam, _).');
      return;
    }
    _state.updatePlayerName(v);
    setState(() => _editingName = false);
    toast(context, 'Oyuncu adı güncellendi!');
  }

  Widget _button(double y, String label, VoidCallback onTap, {Gradient gradient = kMint}) {
    return at(240, y, 600, 130, Tap(
      onTap: onTap,
      child: GlassBox(
        radius: 34,
        borderWidth: 5,
        gradient: gradient,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: centerText(label, londrina(36, shadows: kTextShadow)),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      at(80, 360, 920, 1200, svg('daily_panel.svg')),
      at(80, 440, 920, 100, centerText('Ayarlar', londrina(58, shadows: kTextShadow))),
      if (_editingName)
        at(200, 560, 680, 96, GlassBox(
          radius: 48,
          color: const Color(0xCC0D261F),
          borderWidth: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: 20,
                  autofocus: true,
                  style: exo(30, weight: 700),
                  cursorColor: Colors.white,
                  onSubmitted: (_) => _saveName(),
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                ),
              ),
              Tap(
                onTap: _saveName,
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF63D998), size: 56),
              ),
            ]),
          ),
        ))
      else
        at(200, 565, 680, 80, Tap(
          onTap: () => setState(() {
            _nameCtrl.text = _state.playerName;
            _editingName = true;
          }),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(_state.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: exo(32, weight: 700, shadows: kTextShadow))),
            const SizedBox(width: 14),
            const Icon(Icons.edit_rounded, color: Colors.white70, size: 38),
          ]),
        )),
      _button(690, _state.soundOn ? 'Ses: Açık' : 'Ses: Kapalı', () => setState(() => _state.toggleSound())),
      _button(855, 'İlerlemeyi Sıfırla', () async {
        final ok = await showStageConfirm(
          context,
          title: 'İlerlemeyi Sıfırla',
          message: 'Tüm ilerlemen, coin ve kupaların sıfırlanacak. Emin misin?',
          confirmLabel: 'Sıfırla',
        );
        if (ok) {
          _state.resetProgress();
          if (context.mounted) toast(context, 'İlerleme sıfırlandı.');
        }
      }),
      _button(1020, _state.isAccount ? 'Çıkış Yap' : 'Hesap Değiştir / Giriş', () async {
        final text = _state.isAccount
            ? 'Hesabından çıkış yapılsın mı? İlerlemen bulutta saklı.'
            : 'Giriş ekranına dönmek istiyor musun?';
        final ok = await showStageConfirm(
          context,
          title: 'Çıkış Yap',
          message: text,
          confirmLabel: 'Çıkış Yap',
        );
        if (ok) {
          _state.logout();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        }
      }, gradient: kOrange),
      if (_state.isAccount)
        _button(1185, 'Hesabı Sil', () async {
          final ok = await showStageConfirm(
            context,
            title: 'Hesabı Sil',
            message: 'Hesabın ve tüm bulut verilerin kalıcı olarak silinecek. Emin misin?',
            confirmLabel: 'Kalıcı Sil',
          );
          if (ok) {
            final deleted = await Cloud.deleteAccount();
            if (!context.mounted) return;
            if (!deleted) {
              toast(context, 'Hesap silinemedi. Bağlantını kontrol et.');
              return;
            }
            _state.resetProgress();
            _state.logout();
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }
        }, gradient: const LinearGradient(colors: [Color(0xFFEB5A3C), Color(0xFFB42A12)])),
      at(80, 1365, 920, 60, centerText('FootIQ v1.0', exo(26, color: Colors.white70))),
      at(905, 320, 116.715, 116.715, CloseBtn(onTap: () => Navigator.of(context).pop())),
    ]);
  }
}
