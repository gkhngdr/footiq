import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/cloud.dart';
import '../core/game_state.dart';
import '../core/sound.dart';
import '../core/ui.dart';
import '../data/questions.dart';
import '../widgets/common.dart';
import 'invite_dialog.dart';
import 'quiz_screen.dart';

/// "Arkadaşınla Oyna": kodlu özel PVP odası.
/// Oda sahibi kategori seçip oda açar, kodu paylaşır; arkadaşı kodu girince maç
/// iki tarafta da aynı anda başlar. Dostluk maçı enerji harcamaz, kupa vermez.
class FriendRoomScreen extends StatefulWidget {
  const FriendRoomScreen({super.key, this.initialCode});

  /// Paylaşılan bağlantıyla gelindiyse (ör. `?oda=4032`) doğrudan katılmayı dener.
  final String? initialCode;

  static const webUrl = 'https://gkhngdr.github.io/footiq/';

  @override
  State<FriendRoomScreen> createState() => _FriendRoomScreenState();
}

class _FriendRoomScreenState extends State<FriendRoomScreen> {
  final _state = GameState.instance;
  final _codeInput = TextEditingController();

  late bool _joinMode = widget.initialCode != null;
  PvpCategory _category = PvpCategory.benKimim;
  PvpRoomState? _room;
  String? _guestName;
  bool _busy = false;
  bool _started = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode;
    if (code != null) {
      _codeInput.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    final room = _room;
    if (room != null && !_started) {
      Cloud.cancelPvpRoom(roomId: room.id, playerId: _state.playerId);
    }
    _codeInput.dispose();
    super.dispose();
  }

  String _pretty(String code) => 'FQ-$code';

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    final room = await Cloud.createPrivatePvp(
      category: _category,
      playerId: _state.playerId,
      playerName: _state.playerName,
      seed: Random().nextInt(1 << 30),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _room = room;
    });
    if (room == null) {
      toast(context, 'Oda açılamadı. İnternetini kontrol et.');
      return;
    }
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _check());
  }

  Future<void> _check() async {
    final room = _room;
    if (room == null || _started) return;
    final polled = await Cloud.pollPvpRoom(
      roomId: room.id,
      playerId: _state.playerId,
    );
    if (!mounted || polled == null || !polled.isMatched || _started) return;
    _poll?.cancel();
    Sound.matchFound();
    setState(() => _guestName = polled.opponentName(_state.playerId));
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) _start(polled);
  }

  Future<void> _join() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final code = _codeInput.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 4) {
      toast(context, 'Oda kodu 4 haneli olmalı (ör. FQ-4032).');
      return;
    }
    setState(() => _busy = true);
    final (room, err) = await Cloud.joinPrivatePvp(
      code: code,
      playerId: _state.playerId,
      playerName: _state.playerName,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (room == null) {
      toast(context, err ?? 'Odaya katılınamadı.');
      return;
    }
    Sound.matchFound();
    _start(room);
  }

  void _start(PvpRoomState room) {
    if (_started) return;
    _started = true;
    final category = PvpCategory.values.firstWhere(
      (c) => c.name == room.category,
      orElse: () => _category,
    );
    goStage(
      context,
      QuizScreen.pvp(category: category, friendRoom: room),
      replace: true,
    );
  }

  Future<void> _copy() async {
    final room = _room;
    if (room?.code == null) return;
    await Clipboard.setData(ClipboardData(text: _pretty(room!.code!)));
    if (mounted) toast(context, 'Oda kodu kopyalandı!');
  }

  Future<void> _share() async {
    final code = _room?.code;
    if (code == null) return;
    final text =
        'FootIQ\'da benimle düello yap! ⚽\n'
        'Oda kodu: ${_pretty(code)}\n'
        '${FriendRoomScreen.webUrl}?oda=$code';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        toast(context, 'Davet metni kopyalandı, WhatsApp\'a yapıştır.');
      }
    }
  }

  // ------------------------------------------------------------------ UI

  Widget _toggle() {
    Widget tab(String label, bool active, VoidCallback onTap) => Expanded(
      child: Tap(
        onTap: _room != null ? null : onTap,
        child: GlassBox(
          radius: 40,
          gradient: active ? kOrange : null,
          color: const Color(0x00000000),
          child: centerText(label, londrina(38, shadows: kTextShadow)),
        ),
      ),
    );
    return at(
      120,
      300,
      840,
      110,
      GlassBox(
        radius: 48,
        color: const Color(0x99102A22),
        borderWidth: 3,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              tab(
                'ODA KUR',
                !_joinMode,
                () => setState(() => _joinMode = false),
              ),
              const SizedBox(width: 8),
              tab(
                'KODA KATIL',
                _joinMode,
                () => setState(() => _joinMode = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(
    double y,
    String label,
    VoidCallback? onTap, {
    Gradient? gradient,
  }) {
    return at(
      240,
      y,
      600,
      120,
      Tap(
        onTap: onTap,
        child: GlassBox(
          radius: 28,
          gradient: onTap == null ? null : (gradient ?? kOrange),
          color: const Color(0x66111111),
          borderWidth: 3,
          borderColor: const Color(0xFFFEC665),
          child: _busy
              ? const Center(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 5,
                    ),
                  ),
                )
              : centerText(label, londrina(44, shadows: kTextShadow)),
        ),
      ),
    );
  }

  List<Widget> _createForm() => [
    at(
      120,
      460,
      840,
      60,
      centerText('Oyun türünü seç', exo(34, weight: 700, shadows: kTextShadow)),
    ),
    for (final (i, c) in PvpCategory.values.indexed)
      at(
        170,
        540 + i * 135.0,
        740,
        115,
        Tap(
          onTap: () => setState(() => _category = c),
          child: GlassBox(
            radius: 30,
            borderWidth: _category == c ? 6 : 2.5,
            borderColor: _category == c
                ? const Color(0xFFFFE27A)
                : Colors.white,
            gradient: _category == c ? kMint : null,
            color: const Color(0x66102A22),
            child: centerText(c.title, londrina(40, shadows: kTextShadow)),
          ),
        ),
      ),
    _button(980, 'ODAYI AÇ', _create),
    at(
      120,
      1130,
      840,
      120,
      Center(
        child: Text(
          'Dostluk maçı enerji harcamaz ve sezon kupası vermez.\n'
          'Kazanan +500 coin alır.',
          textAlign: TextAlign.center,
          style: exo(28, weight: 600, color: Colors.white70),
        ),
      ),
    ),
  ];

  List<Widget> _lobby(PvpRoomState room) {
    final matched = _guestName != null;
    Widget slot(
      double x,
      String title,
      String subtitle, {
      required bool ready,
    }) => at(
      x,
      1000,
      405,
      250,
      GlassBox(
        radius: 34,
        color: const Color(0x99102A22),
        borderWidth: 3,
        borderColor: ready ? const Color(0xFF63D998) : Colors.white54,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ready
                    ? Icons.check_circle_rounded
                    : Icons.person_add_alt_1_rounded,
                size: 72,
                color: ready ? const Color(0xFF63D998) : Colors.white70,
              ),
              const SizedBox(height: 12),
              FittedBox(
                child: Text(title, style: londrina(34, shadows: kTextShadow)),
              ),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(
                  subtitle,
                  style: exo(24, weight: 600, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return [
      at(
        120,
        460,
        840,
        320,
        GlassBox(
          radius: 40,
          color: const Color(0xCC0D261F),
          borderWidth: 4,
          borderColor: const Color(0x99FFE27A),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SENİN ODA KODUN',
                style: exo(30, weight: 800, color: const Color(0xFFFFE27A)),
              ),
              const SizedBox(height: 10),
              Text(
                _pretty(room.code ?? '----'),
                style: londrina(120, shadows: kTextShadow, spacing: 0.04),
              ),
              Text(
                PvpCategory.values
                    .firstWhere(
                      (c) => c.name == room.category,
                      orElse: () => _category,
                    )
                    .title,
                style: exo(30, weight: 700, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
      at(
        120,
        820,
        405,
        130,
        Tap(
          onTap: _copy,
          child: GlassBox(
            radius: 30,
            color: const Color(0x99102A22),
            borderWidth: 3,
            child: centerText(
              'KODU KOPYALA',
              londrina(36, shadows: kTextShadow),
            ),
          ),
        ),
      ),
      at(
        555,
        820,
        405,
        130,
        Tap(
          onTap: _share,
          child: GlassBox(
            radius: 30,
            gradient: kMint,
            borderWidth: 3,
            child: centerText(
              kIsWeb ? 'PAYLAŞ' : 'WHATSAPP / PAYLAŞ',
              londrina(34, shadows: kTextShadow),
            ),
          ),
        ),
      ),
      slot(120, 'Sen', 'Hazır', ready: true),
      slot(
        555,
        matched ? _guestName! : 'Arkadaşın',
        matched ? 'Katıldı, maç başlıyor!' : 'Kodu girmesi bekleniyor',
        ready: matched,
      ),
      at(
        120,
        1280,
        840,
        110,
        Center(
          child: Text(
            matched ? 'Maç başlıyor…' : 'Arkadaşın kodu girince maç otomatik başlar.\nKod 10 dakika geçerli.',
            textAlign: TextAlign.center,
            style: exo(28, weight: 600, color: Colors.white70),
          ),
        ),
      ),
    ];
  }

  List<Widget> _joinForm() => [
    at(
      120,
      470,
      840,
      60,
      centerText(
        'Arkadaşının verdiği oda kodunu yaz',
        exo(34, weight: 700, shadows: kTextShadow),
      ),
    ),
    at(
      240,
      560,
      600,
      150,
      GlassBox(
        radius: 40,
        color: const Color(0xCC0D261F),
        borderWidth: 4,
        borderColor: const Color(0x99FFE27A),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('FQ-', style: londrina(80, color: Colors.white54)),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _codeInput,
                  onTapOutside: kIsWeb
                      ? null
                      : (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _join(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  style: londrina(80, spacing: 0.08),
                  cursorColor: const Color(0xFFFFE27A),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    counterText: '',
                    border: InputBorder.none,
                    hintText: '0000',
                    hintStyle: londrina(80, color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    _button(780, 'KATIL', _join),
  ];

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Stage(
      background: 'bg_pvp.webp',
      backgroundBlur: 8,
      keyboardShift: true,
      children: [
        at(
          0,
          0,
          kDesignW,
          kDesignH,
          const ColoredBox(color: Color(0x66000000)),
        ),
        at(
          100,
          110,
          800,
          90,
          centerText('ARKADAŞINLA OYNA', londrina(64, shadows: kTextShadow)),
        ),
        at(
          60,
          200,
          960,
          60,
          centerText(
            'Oda kur, kodu paylaş, birlikte oyna!',
            exo(30, weight: 600, color: Colors.white70),
          ),
        ),
        _toggle(),
        if (_joinMode)
          ..._joinForm()
        else if (room != null)
          ..._lobby(room)
        else
          ..._createForm(),
        // Davet Et Kazan buraya taşındı: arkadaş getirme ödülü.
        at(
          120,
          1640,
          840,
          100,
          Tap(
            onTap: () => showInvite(context),
            child: GlassBox(
              radius: 50,
              color: const Color(0x99102A22),
              borderWidth: 2.5,
              borderColor: const Color(0x99FFE27A),
              child: centerText(
                'Davet kodunla arkadaşını getir: ikiniz de +500 coin  ›',
                exo(28, weight: 700, color: const Color(0xFFFFE27A)),
              ),
            ),
          ),
        ),
        // Kapat düğmesi en üstte: başka kutular üstüne binip dokunmayı engellemesin.
        at(
          923,
          80,
          116.715,
          116.715,
          CloseBtn(onTap: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }
}
