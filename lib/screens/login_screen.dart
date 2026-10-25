import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/ui.dart';
import 'main_screen.dart';

/// Figma: "GİRİŞ YAP" (25:2). E-posta/şifre ile giriş, kayıt ve misafir girişi
/// Supabase'e bağlıdır.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hidePass = true;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _nameRe = RegExp(r'^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$');

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enter() {
    goStage(context, const MainScreen(), replace: true);
  }

  void _guest() {
    GameState.instance.loginAsGuest();
    _enter();
  }

  String? _validate() {
    if (_register && !_nameRe.hasMatch(_username.text.trim())) {
      return 'Kullanıcı adı 3-20 karakter olmalı (harf, rakam, _).';
    }
    if (!_emailRe.hasMatch(_email.text.trim())) return 'Geçerli bir e-posta gir.';
    if (_password.text.length < 6) return 'Şifre en az 6 karakter olmalı.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final problem = _validate();
    if (problem != null) {
      toast(context, problem);
      return;
    }
    setState(() => _busy = true);
    if (_register) {
      final (err, needsConfirm) = await Cloud.signUp(_email.text, _password.text, _username.text.trim());
      if (!mounted) return;
      setState(() => _busy = false);
      if (err != null) {
        toast(context, err);
      } else if (needsConfirm) {
        toast(context, 'Kayıt tamam! Şimdi giriş yapabilirsin.');
        setState(() => _register = false);
      } else {
        GameState.instance.setAccount(_username.text.trim());
        _enter();
      }
    } else {
      final err = await Cloud.signIn(_email.text, _password.text);
      if (!mounted) return;
      setState(() => _busy = false);
      if (err != null) {
        toast(context, err);
      } else {
        GameState.instance.loggedIn = true;
        _enter();
      }
    }
  }

  Future<void> _forgot() async {
    if (!_emailRe.hasMatch(_email.text.trim())) {
      toast(context, 'Önce e-posta adresini yaz.');
      return;
    }
    final err = await Cloud.resetPassword(_email.text);
    if (!mounted) return;
    toast(context, err ?? 'Şifre sıfırlama bağlantısı e-postana gönderildi.');
  }

  Widget _field(
    double y,
    String label,
    TextEditingController c, {
    bool password = false,
    TextInputType? type,
    TextInputAction? action,
    ValueChanged<String>? onSubmitted,
    List<TextInputFormatter>? formatters,
  }) {
    final style = poppins(32, weight: FontWeight.w500, color: Colors.white);
    return at(170, y, 720, 80, GlassBox(
      radius: 50,
      color: const Color(0x66102A22),
      borderWidth: 2.5,
      child: Padding(
        padding: const EdgeInsets.only(left: 38, right: 24),
        child: Center(
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: c,
                obscureText: password && _hidePass,
                keyboardType: type ?? (password ? TextInputType.visiblePassword : TextInputType.text),
                textInputAction: action ?? (password ? TextInputAction.done : TextInputAction.next),
                onSubmitted: onSubmitted ?? (password ? (_) => _submit() : null),
                autocorrect: false,
                enableSuggestions: !password,
                maxLength: password ? 72 : 64,
                inputFormatters: formatters,
                style: style,
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  isCollapsed: true,
                  counterText: '',
                  border: InputBorder.none,
                  hintText: label,
                  hintStyle: poppins(28, weight: FontWeight.w300, color: Colors.white70),
                ),
              ),
            ),
            if (password)
              GestureDetector(
                onTap: () => setState(() => _hidePass = !_hidePass),
                child: Icon(_hidePass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white70, size: 44),
              ),
          ]),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stage(
      background: 'bg_splash.png',
      keyboardShift: true,
      children: [
        // Cam panel
        at(120, 464, 840, 860, const GlassBox(radius: 35, blur: 8.8, borderWidth: 4)),
        at(120, 464, 840, 860, const GlowFrame(radius: 35, color: Colors.white, width: 7, blur: 11.45)),
        at(411.2, 504, 257.528, 268.8, png('logo.png')),
        at(120, 805, 840, 86, centerText(_register ? 'Hesap oluştur' : 'Hesabına giriş yap', londrina(48, shadows: kTextShadow))),
        if (_register) ...[
          _field(905, 'KULLANICI ADI', _username),
          _field(995, 'E-POSTA', _email, type: TextInputType.emailAddress),
          _field(1085, 'ŞİFRE', _password, password: true),
        ] else ...[
          _field(931, 'E-POSTA', _email, type: TextInputType.emailAddress),
          _field(1051, 'ŞİFRE', _password, password: true),
          at(560, 1135, 330, 44, Tap(
            onTap: _forgot,
            child: Align(alignment: Alignment.centerRight, child: Text('Şifremi unuttum', style: poppins(24, weight: FontWeight.w500))),
          )),
        ],
        // GİRİŞ YAP / KAYIT OL (ortalanmış)
        at(290, 1193, 500, 90, const GlassBox(radius: 15, color: Color(0xFFAC594E))),
        at(292.4, 1187, 495.2, 90, Tap(
          onTap: _submit,
          child: GlassBox(
            radius: 10,
            gradient: kOrange,
            borderWidth: 3,
            borderColor: const Color(0xFFFEC665),
            child: _busy
                ? const Center(child: SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 5)))
                : centerText(_register ? 'KAYIT OL' : 'GİRİŞ YAP', londrina(36, shadows: kTextShadow)),
          ),
        )),
        // Alt düğmeler
        at(120, 1384, 384, 72, Tap(
          onTap: () => setState(() => _register = !_register),
          child: GlassBox(radius: 50, color: const Color(0x66102A22), borderWidth: 2, child: centerText(_register ? 'GİRİŞE DÖN' : 'KAYIT OL', poppins(24, weight: FontWeight.w600))),
        )),
        at(552, 1384, 408, 72, Tap(
          onTap: _guest,
          child: GlassBox(
            radius: 50,
            color: const Color(0x66102A22),
            borderWidth: 2,
            child: centerText('MİSAFİR OLARAK DEVAM ET', poppins(22, weight: FontWeight.w600)),
          ),
        )),
        at(120, 1480, 840, 90, Center(
          child: Text(
            'Misafir ilerlemesi bu cihazda saklanır.\nHesap açarsan her cihazda devam edersin.',
            textAlign: TextAlign.center,
            style: poppins(24, weight: FontWeight.w400, color: Colors.white70),
          ),
        )),
      ],
    );
  }
}
