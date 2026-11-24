// tray_manager's 0.5.x API (Menu, MenuItem, TrayListener) is enough here.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/legacy.dart';

/// Yankı's icon in the system tray (StatusNotifierItem: KDE's panel, or
/// GNOME with the AppIndicator extension): a click opens it, the menu
/// opens, floats, sets the wake word or ends it.
class YankiTray with TrayListener {
  YankiTray({
    required this.onOpen,
    required this.onFloat,
    required this.onSettings,
    required this.onWake,
    required this.onQuit,
  });

  final VoidCallback onOpen, onFloat, onSettings, onQuit;
  final void Function(bool on) onWake;

  bool _shown = false;
  bool _wake = false;

  bool get shown => _shown;

  /// Shown with the wake word's tick as [wake]; nothing when the desktop
  /// has no tray (the window then closes as before).
  Future<void> show({required bool wake}) async {
    if (_shown && wake == _wake) return;
    _wake = wake;
    try {
      if (!_shown) {
        trayManager.addListener(this);
        await trayManager.setIcon('assets/branding/tray.png');
        await trayManager.setToolTip('LifeOS Yankı');
        _shown = true;
      }
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'ac', label: 'Yankı’yı aç'),
            MenuItem(key: 'kure', label: 'Yüzen küre'),
            MenuItem.separator(),
            MenuItem.checkbox(
              key: 'sesle',
              label: '“Merhaba Yankı” ile aç',
              checked: wake,
            ),
            MenuItem(key: 'ayar', label: 'Ayarlar'),
            MenuItem.separator(),
            MenuItem(key: 'cik', label: 'Çık'),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Yankı tepsisi açılamadı: $e');
      await hide();
    }
  }

  Future<void> hide() async {
    if (!_shown) return;
    _shown = false;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() => onOpen();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'ac':
        onOpen();
      case 'kure':
        onFloat();
      case 'sesle':
        onWake(!_wake);
      case 'ayar':
        onSettings();
      case 'cik':
        onQuit();
    }
  }
}
