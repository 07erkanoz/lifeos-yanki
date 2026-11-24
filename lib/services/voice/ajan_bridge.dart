import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../desktop/desktop_instance.dart';
import '../mcp/mcp_servers.dart';
import '../platform/app_directories.dart';

/// Yankı's word with itself and with LifeOS Folio. A second `lifeos-yanki`
/// tells the first what it was started for over the loopback socket its
/// [DesktopInstance] holds, and ends.
abstract final class AjanBridge {
  /// The full screen.
  static const show = '--goster';

  /// Started with no window: listening for the wake word only.
  static const background = '--arka';

  /// The voice's settings changed: read again.
  static const settings = '--ayar';

  /// An activation token from the desktop, for the window to come forward.
  static const tokenPrefix = '--etkin=';

  /// Yankı ends.
  static const quit = '--kapan';

  /// Yankı's own folder: its lock and what it says of itself.
  static Future<Directory> folder() async {
    final dir = Directory(p.join((await supportDirectory()).path, 'yanki'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _state() async =>
      File(p.join((await folder()).path, 'durum.json'));

  /// Whether Yankı's window is on screen.
  static Future<void> setShown(bool shown) async {
    try {
      final file = await _state();
      final part = File('${file.path}.part');
      await part.writeAsString(
        jsonEncode({'gorunur': shown, 'pid': pid}),
        flush: true,
      );
      await part.rename(file.path);
    } catch (_) {}
  }

  /// [args] told to the running Yankı; false when it is not running.
  static Future<bool> toAjan(List<String> args) async =>
      DesktopInstance.send(args, directory: await folder());

  /// LifeOS Folio in its tray, for what only the open Folio does (UYAP,
  /// UETS): the person is talking to Yankı, Folio's window is not shown.
  static Future<void> wakeFolio() async {
    final folio = McpServers.folioProgram;
    if (folio == null) return;
    try {
      await Process.start(folio, const [
        background,
      ], mode: ProcessStartMode.detached);
    } catch (_) {}
  }

  /// LifeOS Folio's window, where it is installed.
  static Future<void> openFolio() async {
    final folio = McpServers.folioProgram;
    if (folio == null) return;
    try {
      await Process.start(folio, const [], mode: ProcessStartMode.detached);
    } catch (_) {}
  }
}
