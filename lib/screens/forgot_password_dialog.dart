import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/ui.dart';
import '../widgets/common.dart';
import 'daily_reward_dialog.dart';

/// "Şifremi unuttum": e-postaya gelen kodla yeni şifre belirleme.
/// Bağlantıya tıklama gerektirmez; web'de ve telefonda aynı şekilde çalışır.
/// Şifre değişince oyuncu giriş yapmış olur ve `true` döner.
Future<bool> showForgotPassword(
  BuildContext context, {
  String email = '',
}) async {
  final ok = await showStageDialog<bool>(
    context,
    (ctx) => [_ForgotPanel(initialEmail: email)],
    keyboardShift: true,
  );
  return ok ?? false;
}

/// E-postadaki sıfırlama bağlantısıyla gelen (oturumu açılmış) oyuncuya
/// yeni şifre belirletir.
Future<void> showSetNewPassword(BuildContext context) {
  return showStageDialog<bool>(
    context,
    (ctx) => [const _ForgotPanel(initialEmail: '', setOnly: true)],
    keyboardShift: true,
  );
}

class _ForgotPanel extends StatefulWidget {
  const _ForgotPanel({required this.initialEmail, this.setOnly = false});

  final String initialEmail;

  /// Yalnızca yeni şifre adımı (bağlantıyla gelindiğinde).
  final bool setOnly;

  @override
  State<_ForgotPanel> createState() => _ForgotPanelState();
}

class _ForgotPanelState extends State<_ForgotPanel> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _resendWait = 60;

  late final _email = TextEditingController(text: widget.initialEmail.trim());
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _hidePass = true;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendWait);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_busy || _cooldown > 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_emailRe.hasMatch(_email.text.trim())) {
      toast(context, 'Geçerli bir e-posta gir.');
      return;
    }
    setState(() => _busy = true);
    final err = await Cloud.resetPassword(_email.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      toast(context, err);
      return;
    }
    setState(() => _codeSent = true);
    _startCooldown();
    toast(context, 'Kod e-postana gönderildi. Gereksiz klasörüne de bak.');
  }

  Future<void> _confirm() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      toast(context, 'E-postadaki kodu eksiksiz yaz.');
      return;
    }
    if (_password.text.length < 6) {
      toast(context, 'Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    setState(() => _busy = true);
    final err = await Cloud.confirmPasswordReset(
      _email.text,
      code,
      _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      toast(context, err);
      return;
    }
    GameState.instance.loggedIn = true;
    toast(context, 'Şifren değişti, hoş geldin!');
    Navigator.of(context).pop(true);
  }

  Future<void> _saveNewPassword() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_password.text.length < 6) {
      toast(context, 'Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    setState(() => _busy = true);
    final err = await Cloud.setNewPassword(_password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      toast(context, err);
      return;
    }
    toast(context, 'Yeni şifren kaydedildi!');
    Navigator.of(context).pop(true);
  }

  Widget _field(
    double y,
    String hint,
    TextEditingController c, {
    bool password = false,
    TextInputType? type,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    List<TextInputFormatter>? formatters,
    int maxLength = 64,
  }) {
    return at(
      170,
      y,
      740,
      84,
      GlassBox(
        radius: 50,
        color: const Color(0x66102A22),
        borderWidth: 2.5,
        child: Padding(
          padding: const EdgeInsets.only(left: 38, right: 8),
          child: Center(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: c,
                    onTapOutside: kIsWeb
                        ? null
                        : (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    obscureText: password && _hidePass,
                    keyboardType:
                        type ??
                        (password
                            ? TextInputType.visiblePassword
                            : TextInputType.text),
                    textInputAction: action,
                    onSubmitted: onSubmitted,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: maxLength,
                    inputFormatters: formatters,
                    style: poppins(32, weight: FontWeight.w500),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      counterText: '',
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: poppins(
                        28,
                        weight: FontWeight.w300,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                if (password)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _hidePass = !_hidePass),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Icon(
                        _hidePass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white70,
                        size: 44,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainButton(double y, String label, VoidCallback onTap) {
    return at(
      240,
      y,
      600,
      110,
      Tap(
        onTap: onTap,
        child: GlassBox(
          radius: 24,
          gradient: kOrange,
          borderWidth: 3,
          borderColor: const Color(0xFFFEC665),
          child: _busy
              ? const Center(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 5,
                    ),
                  ),
                )
              : centerText(label, londrina(42, shadows: kTextShadow)),
        ),
      ),
    );
  }

  Widget _linkButton(
    double x,
    double y,
    double w,
    String label,
    VoidCallback? onTap,
  ) {
    return at(
      x,
      y,
      w,
      84,
      Tap(
        onTap: onTap,
        child: GlassBox(
          radius: 42,
          color: const Color(0x66102A22),
          borderWidth: 2,
          child: centerText(
            label,
            poppins(
              28,
              weight: FontWeight.w600,
              color: onTap == null ? Colors.white54 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(double y, String text, {double h = 130}) => at(
    150,
    y,
    780,
    h,
    Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 780,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: exo(34, weight: 600, shadows: kTextShadow),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop(false);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        at(
          90,
          470,
          900,
          _codeSent ? 900 : (widget.setOnly ? 700 : 790),
          svg('daily_panel.svg'),
        ),
        at(
          150,
          520,
          780,
          100,
          centerText(
            widget.setOnly ? 'Yeni Şifre' : 'Şifreni Sıfırla',
            londrina(68, shadows: kTextShadow),
          ),
        ),
        if (widget.setOnly) ...[
          _message(640, 'Hesabına girildi.\nŞimdi yeni şifreni belirle.'),
          _field(
            800,
            'YENİ ŞİFRE',
            _password,
            password: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _saveNewPassword(),
            maxLength: 72,
          ),
          _mainButton(935, 'ŞİFREYİ KAYDET', _saveNewPassword),
          _linkButton(340, 1070, 400, 'Sonra', close),
        ] else if (!_codeSent) ...[
          _message(
            640,
            'E-posta adresini yaz, sana\nbir doğrulama kodu gönderelim.',
          ),
          _field(
            810,
            'E-POSTA',
            _email,
            type: TextInputType.emailAddress,
            action: TextInputAction.send,
            onSubmitted: (_) => _sendCode(),
          ),
          _mainButton(950, 'KOD GÖNDER', _sendCode),
          _linkButton(340, 1130, 400, 'Vazgeç', close),
        ] else ...[
          _message(
            620,
            '${_email.text.trim()} adresine gelen kodu ve yeni şifreni yaz. '
            'E-postada bağlantı varsa ona bu cihazda dokunman da yeterli.',
          ),
          _field(
            780,
            'KOD',
            _code,
            type: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
          ),
          _field(
            890,
            'YENİ ŞİFRE',
            _password,
            password: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            maxLength: 72,
          ),
          _mainButton(1010, 'ŞİFREYİ DEĞİŞTİR', _confirm),
          _linkButton(
            150,
            1160,
            450,
            _cooldown > 0 ? 'Tekrar gönder ($_cooldown)' : 'Kodu tekrar gönder',
            _cooldown > 0 || _busy ? null : _sendCode,
          ),
          _linkButton(630, 1160, 300, 'Vazgeç', close),
        ],
        at(905, 440, 116.715, 116.715, CloseBtn(onTap: close)),
      ],
    );
  }
}
