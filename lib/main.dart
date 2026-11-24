import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'services/ai/ai_assistant.dart';
import 'services/desktop/desktop_instance.dart';
import 'services/desktop/global_shortcut.dart';
import 'services/desktop/yanki_tray.dart';
import 'services/mcp/mcp_client.dart';
import 'services/voice/ajan_bridge.dart';
import 'services/voice/ajan_approval.dart';
import 'services/voice/ajan_voice.dart' show stopWordHeard;
import 'services/voice/folio_ajan.dart';
import 'services/voice/wake_word.dart';
import 'ui/desktop/ajan_float.dart' show ajanFloatOpen;
import 'ui/desktop/jarvis_view.dart';
import 'ui/desktop/yanki_figures.dart';
import 'ui/desktop/yanki_orb.dart';
import 'ui/settings/yanki_settings.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_controller.dart';

/// LifeOS Yankı: LifeOS's voice assistant, a program of its own (once
/// Folio Ajan, inside LifeOS Folio). Its own window (the full screen, or
/// the small voice window while a conversation goes on beside other
/// work), its own microphone (the wake word) and its own lock. Started with
/// `--arka` it shows nothing and listens.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await runAjanApp(arguments);
}

Future<void> runAjanApp(List<String> arguments) async {
  DesktopInstance? instance;
  try {
    instance = await DesktopInstance.acquire(
      arguments,
      directory: await AjanBridge.folder(),
    );
  } on StateError {
    DesktopInstance.tellStuck(
      'LifeOS Yankı açık görünüyor ama yanıt vermiyor.',
    );
    exit(1);
  }
  if (instance == null) exit(0);
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.setTitle('LifeOS Yankı');
  await windowManager.setMinimumSize(AjanApp.compactSize);
  await AiSettings.load();
  await DotFieldBackdrop.load();
  await AjanBridge.setShown(false);
  runApp(
    AjanApp(
      instance: instance,
      hidden: arguments.contains(AjanBridge.background),
      token: AjanApp.tokenOf(arguments),
    ),
  );
}

enum _Mode { hidden, full, compact }

class AjanApp extends StatefulWidget {
  const AjanApp({
    super.key,
    required this.instance,
    this.hidden = false,
    this.token,
  });

  final DesktopInstance instance;

  /// Started with no window ([AjanBridge.background]).
  final bool hidden;
  final String? token;

  /// The small voice window's size before it fits its card.
  static const compactSize = Size(320, 180);

  static String? tokenOf(List<String> args) {
    for (final a in args) {
      if (a.startsWith(AjanBridge.tokenPrefix)) {
        return a.substring(AjanBridge.tokenPrefix.length);
      }
    }
    return null;
  }

  @override
  State<AjanApp> createState() => _AjanAppState();
}

class _AjanAppState extends State<AjanApp> with WindowListener {
  final appearance = ThemeController();
  final _card = GlobalKey();
  late final StreamSubscription<List<String>> _requests;
  var _mode = _Mode.hidden;
  bool _switching = false;

  FolioAjan get ajan => FolioAjan.instance;

  late final _tray = YankiTray(
    onOpen: () => unawaited(_full(null)),
    onFloat: () => unawaited(_compact()),
    onSettings: () => unawaited(_full(null).then((_) => _openSettings())),
    onWake: (on) => unawaited(
      ajan.saveSettings(
        ajan.settings.copyWith(on: on || ajan.settings.on, wake: on),
      ),
    ),
    onQuit: () => unawaited(_quit()),
  );

  @override
  void initState() {
    super.initState();
    appearance.load();
    // Started at login with no window (--arka): with the wake word off
    // there is nothing to listen for, and Yankı ends.
    unawaited(() async {
      await ajan.loadVoiceSettings();
      await _followTray();
      if (widget.hidden && _mode == _Mode.hidden && !_stays) await _quit();
    }());
    FolioAjan.beforeVoice = WakeWord.instance.pause;
    WakeWord.instance.onWake = _woken;
    ajan.addListener(_followWake);
    AiSettings.on.addListener(_followWake);
    ajanFloatOpen.addListener(_floatChanged);
    stopWordHeard.addListener(_stopWord);
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    _requests = widget.instance.requests.listen(_heard);
    if (!widget.hidden) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_full(widget.token)),
      );
    }
  }

  bool get _wantWake =>
      ajan.available && ajan.settings.on && ajan.settings.wake;

  /// Kept running with no window: listening for the wake word, or in the
  /// tray.
  bool get _stays => _wantWake || (ajan.settings.tray && _tray.shown);

  Future<void> _followTray() async {
    if (ajan.settings.tray) {
      await _tray.show(wake: _wantWake);
    } else {
      await _tray.hide();
    }
  }

  /// "Kapan", "görüşürüz": the window goes too, when the person wants,
  /// once "Konuşma kapatıldı" has been seen.
  void _stopWord() {
    if (!ajan.settings.voiceClose || _mode == _Mode.hidden) return;
    Timer(const Duration(milliseconds: 900), () {
      if (!ajan.voice.active) unawaited(_hide());
    });
  }

  void _followWake() {
    unawaited(_followTray());
    final wake = WakeWord.instance;
    if (!_wantWake) {
      if (wake.on) unawaited(wake.stop());
      return;
    }
    if (ajan.voiceStarting || ajan.voice.active) return;
    if (!wake.on || wake.state.value == WakeState.paused) {
      unawaited(wake.start());
    }
  }

  /// "Ajan açıl": the full screen from nothing; in a window already, the
  /// conversation.
  Future<void> _woken() async {
    if (_mode == _Mode.hidden) return _full(null);
    if (!ajan.voice.active) await ajan.startVoice(handsFree: true);
  }

  void _heard(List<String> args) {
    if (args.contains(AjanBridge.settings)) {
      unawaited(_settingsChanged());
      return;
    }
    if (args.contains(AjanBridge.quit)) {
      unawaited(_quit());
      return;
    }
    if (args.contains(AjanBridge.background)) return;
    unawaited(_full(AjanApp.tokenOf(args)));
  }

  /// The voice's settings changed: read again; with no window and
  /// nothing to listen for, Yankı has nothing to do.
  Future<void> _settingsChanged() async {
    await AiSettings.reload();
    await ajan.loadSettings(quick: true);
    _followWake();
    await _followTray();
    if (_mode == _Mode.hidden && !_stays) await _quit();
  }

  Future<void> _full(String? token) async {
    if (_switching) return;
    _switching = true;
    try {
      final from = _mode;
      setState(() => _mode = _Mode.full);
      ajanFloatOpen.value = false;
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      if (from == _Mode.hidden) {
        // The screen's size before it is shown, full screen once it is (a
        // hidden window's is not changed on Wayland): never small first.
        final display = PlatformDispatcher.instance.displays.first;
        await windowManager.setBounds(
          Offset.zero & (display.size / display.devicePixelRatio),
        );
      }
      // Put behind ([_background]): back from the taskbar.
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.setFullScreen(true);
      try {
        await GlobalShortcut.channel.invokeMethod('activate', token ?? '');
      } catch (_) {}
      await windowManager.focus();
      if (from == _Mode.hidden) await AjanBridge.setShown(true);
    } finally {
      _switching = false;
    }
  }

  /// Out of the way, still at hand: the floating orb over the desktop,
  /// always on top; the conversation goes on in it.
  Future<void> _background() => _compact();

  /// The floating orb.
  Future<void> _compact() async {
    if (_switching || _mode == _Mode.compact) return;
    _switching = true;
    try {
      final from = _mode;
      setState(() => _mode = _Mode.compact);
      ajanFloatOpen.value = true;
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
        for (var i = 0; i < 20 && await windowManager.isFullScreen(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      await windowManager.setSize(YankiOrb.size);
      // Top right, where it is out of the way (X11; Wayland places it).
      final display = PlatformDispatcher.instance.displays.first;
      final screen = display.size / display.devicePixelRatio;
      await windowManager.setPosition(
        Offset(screen.width - YankiOrb.size.width - 24, 48),
      );
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      if (from == _Mode.hidden) {
        await windowManager.show();
        await AjanBridge.setShown(true);
      }
    } finally {
      _switching = false;
    }
  }

  void _floatChanged() {
    if (!ajanFloatOpen.value && _mode == _Mode.compact) unawaited(_hide());
  }

  /// No window; the conversation ends with it. Listening for "Ajan açıl"
  /// goes on, or the program ends when it is not wanted.
  /// [work], but never longer than [most]: closing must not wait on a
  /// voice or a microphone that does not answer.
  static Future<void> _brief(
    Future<void> Function() work, [
    Duration most = const Duration(seconds: 2),
  ]) async {
    try {
      await work().timeout(most);
    } catch (_) {}
  }

  /// No window; the conversation ends with it. The window goes first, at
  /// once; what is let go of after it is given a moment each. Listening
  /// for the wake word goes on, or the program ends when it is not wanted.
  Future<void> _hide() async {
    if (_mode == _Mode.hidden) return;
    setState(() => _mode = _Mode.hidden);
    ajanFloatOpen.value = false;
    AjanApprovals.instance.cancel();
    await _brief(windowManager.hide);
    await _brief(() => windowManager.setAlwaysOnTop(false));
    await _brief(() => windowManager.setSkipTaskbar(false));
    await _brief(() async {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
    });
    await _brief(() => AjanBridge.setShown(false));
    if (ajan.voice.active) {
      await _brief(ajan.voice.stop, const Duration(seconds: 3));
    }
    if (!_stays) return _quit();
    _followWake();
  }

  /// The program ends, whatever does not let go: four seconds at most.
  Future<void> _quit() async {
    Timer(const Duration(seconds: 4), () => exit(0));
    await _brief(windowManager.hide);
    await _brief(() => AjanBridge.setShown(false));
    if (ajan.voice.active) await _brief(ajan.voice.stop);
    await _brief(WakeWord.instance.stop);
    await _brief(_tray.hide);
    McpClient.endAll();
    await _brief(widget.instance.close);
    exit(0);
  }

  final _navigator = GlobalKey<NavigatorState>();

  bool _inSettings = false;

  Future<void> _openSettings() async {
    final nav = _navigator.currentState;
    if (nav == null || _inSettings) return;
    _inSettings = true;
    try {
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => YankiSettingsPage(ajan: ajan)),
      );
    } finally {
      _inSettings = false;
    }
    await _settingsChanged();
  }

  @override
  void onWindowClose() => unawaited(_hide());

  @override
  void dispose() {
    _requests.cancel();
    ajan.removeListener(_followWake);
    AiSettings.on.removeListener(_followWake);
    ajanFloatOpen.removeListener(_floatChanged);
    stopWordHeard.removeListener(_stopWord);
    windowManager.removeListener(this);
    appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appearance,
    builder: (context, _) => MaterialApp(
      title: 'LifeOS Yankı',
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appearance.mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      locale: const Locale('tr', 'TR'),
      home: switch (_mode) {
        _Mode.hidden => const SizedBox.shrink(),
        _Mode.full => JarvisView(
          ajan: ajan,
          onMinimize: () => unawaited(_background()),
          onSettings: () => unawaited(_openSettings()),
          onClose: () => unawaited(_hide()),
        ),
        _Mode.compact => Align(
          alignment: Alignment.topLeft,
          child: YankiOrb(
            key: _card,
            ajan: ajan,
            onFull: () => unawaited(_full(null)),
            onClose: () => unawaited(_hide()),
          ),
        ),
      },
    ),
  );
}
