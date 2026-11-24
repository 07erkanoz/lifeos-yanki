import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/dil.dart';
import '../../services/voice/folio_ajan.dart';
import '../../services/voice/live_conversation.dart';
import 'ajan_skins.dart';
import 'yanki_figures.dart';

/// The voice's moment, as the figures show it.
AjanMood moodOf(FolioAjan ajan) {
  final s = ajan.voice.state;
  if (ajan.asking || s == LiveState.working || s == LiveState.thinking) {
    return AjanMood.working;
  }
  return switch (s) {
    LiveState.speaking => AjanMood.speaking,
    LiveState.listening || LiveState.waiting => AjanMood.listening,
    _ => AjanMood.idle,
  };
}

String moodWord(FolioAjan ajan) {
  if (!ajan.settings.on) return l('Ses kapalı');
  if (ajan.voice.state == LiveState.connecting) return l('Bağlanıyor');
  return switch (moodOf(ajan)) {
    AjanMood.idle => ajan.voice.active ? l('Hazır') : l('Dokun, konuş'),
    AjanMood.listening => l('Dinliyor'),
    AjanMood.speaking => l('Konuşuyor'),
    AjanMood.working => l('Çalışıyor'),
  };
}

/// Yankı made small: a pill floating over the desktop, always on top. The
/// orb lives and listens; a touch talks or stops; drag it anywhere; the
/// arrow brings back the full screen.
class YankiOrb extends StatefulWidget {
  const YankiOrb({
    super.key,
    required this.ajan,
    required this.onFull,
    required this.onClose,
  });
  final FolioAjan ajan;
  final VoidCallback onFull, onClose;

  static const size = Size(440, 132);

  @override
  State<YankiOrb> createState() => _YankiOrbState();
}

class _YankiOrbState extends State<YankiOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  final _clock = ValueNotifier<double>(0);
  final _motion = AjanMotion();
  double _last = 0;
  bool _hover = false;

  FolioAjan get ajan => widget.ajan;

  @override
  void initState() {
    super.initState();
    ajan.addListener(_changed);
    Dil.current.addListener(_changed);
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    final dt = (t - _last).clamp(0.0, .1);
    _last = t;
    _motion.step(t, dt * 60, moodOf(ajan), ajan.voice.level.value);
    _clock.value = t;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ajan.removeListener(_changed);
    Dil.current.removeListener(_changed);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  String get _line {
    for (final l in ajan.voice.lines.reversed) {
      if (l.text.trim().isNotEmpty) return l.text.trim();
    }
    return ajan.voice.error ?? l('Yankı burada. Konuşmak için küreye dokunun.');
  }

  /// Whether there is anything to read beside the orb.
  bool get _hasWords =>
      ajan.voice.active ||
      ajan.voice.error != null ||
      ajan.asking ||
      ajan.voice.lines.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final mood = moodOf(ajan);
    final glow = switch (mood) {
      AjanMood.speaking => 1.0,
      AjanMood.listening => .75,
      AjanMood.working => .85,
      AjanMood.idle => .45,
    };
    const orb = 116.0;
    final words = _hasWords || _hover;
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFE3F4FF),
          decoration: TextDecoration.none,
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onPanStart: (_) => windowManager.startDragging(),
            onDoubleTap: widget.onFull,
            child: SizedBox(
              width: YankiOrb.size.width,
              height: YankiOrb.size.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The words: a glass card that comes out from behind the orb.
                  Positioned(
                    left: orb * .62,
                    right: 6,
                    top: 18,
                    bottom: 18,
                    child: AnimatedSlide(
                      offset: words ? Offset.zero : const Offset(-.12, 0),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: words ? 1 : 0,
                        duration: const Duration(milliseconds: 320),
                        child: _card(),
                      ),
                    ),
                  ),
                  // The orb, glowing on its own.
                  Positioned(
                    left: 8,
                    top: (YankiOrb.size.height - orb) / 2,
                    width: orb,
                    height: orb,
                    child: GestureDetector(
                      onTap: ajan.settings.on ? ajan.toggleTalk : widget.onFull,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFF0E2E78),
                                Color(0xFF061331),
                                Color(0xFF030919),
                              ],
                              stops: [0, .62, 1],
                            ),
                            border: Border.all(
                              color: const Color(0xFF3CDCFF)
                                  .withValues(alpha: .18 + glow * .35),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E6BFF)
                                    .withValues(alpha: .25 + glow * .35),
                                blurRadius: 14 + glow * 14,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: OrbPainter(_clock, _motion),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() => Container(
    padding: EdgeInsets.fromLTRB(116 * .46, 10, 8, 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xE60A1A3E), Color(0xE6050C22)],
      ),
      border: Border.all(color: const Color(0x333CDCFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  moodWord(ajan).toUpperCase(),
                  key: ValueKey(moodWord(ajan)),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3CDCFF),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .2),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: Text(
                  _line,
                  key: ValueKey(
                    _line.length > 40 ? _line.substring(0, 40) : _line,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFDCEBFA),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _hover ? 1 : 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _icon(Icons.open_in_full_rounded, l('Tam ekran'), widget.onFull),
              _icon(
                Icons.close_rounded,
                l('Gizle (dinlemeye devam)'),
                widget.onClose,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _icon(IconData icon, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: InkResponse(
      onTap: onTap,
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 16, color: const Color(0xFF8DB4D6)),
      ),
    ),
  );
}

/// For tests: the orb's painter without a window.
@visibleForTesting
CustomPainter orbPainter(ValueListenable<double> clock, AjanMotion m) =>
    OrbPainter(clock, m);
