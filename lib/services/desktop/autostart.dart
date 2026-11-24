import 'dart:io';

import 'package:path/path.dart' as p;

/// Yankı started at login (`lifeos-yanki --arka`): the package puts the
/// entry in /etc/xdg/autostart, and the person's own copy in
/// ~/.config/autostart wins over it, so turning it off writes one with
/// `Hidden=true`.
class Autostart {
  static const _name = 'tr.com.lifeos.Yanki-autostart.desktop';

  static File get _own => File(
    p.join(
      Platform.environment['XDG_CONFIG_HOME'] ??
          p.join(Platform.environment['HOME'] ?? '', '.config'),
      'autostart',
      _name,
    ),
  );

  static Future<bool> isOn() async {
    final own = _own;
    if (await own.exists()) {
      final text = await own.readAsString();
      return !RegExp(
        r'^\s*(Hidden\s*=\s*true|X-GNOME-Autostart-enabled\s*=\s*false)',
        multiLine: true,
        caseSensitive: false,
      ).hasMatch(text);
    }
    return File('/etc/xdg/autostart/$_name').exists();
  }

  static Future<void> set(bool on) async {
    final own = _own;
    await own.parent.create(recursive: true);
    await own.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=LifeOS Yankı (background)\n'
      'Name[tr]=LifeOS Yankı (arka planda)\n'
      'Comment=Waits in the tray and listens for the wake word\n'
      'Comment[tr]=Oturum açılınca tepside durur ve uyandırma sözünü dinler\n'
      'Exec=lifeos-yanki --arka\n'
      'Icon=tr.com.lifeos.Yanki\n'
      'Terminal=false\n'
      'NoDisplay=true\n'
      'X-GNOME-Autostart-enabled=${on ? 'true' : 'false'}\n'
      '${on ? '' : 'Hidden=true\n'}',
      flush: true,
    );
  }
}
