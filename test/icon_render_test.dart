import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_yanki/ui/desktop/ajan_skins.dart';
import 'package:lifeos_yanki/ui/desktop/yanki_figures.dart';

/// Yankı's icon, drawn from its own core
/// (`YANKI_ICON=assets/branding/lifeos_yanki.png flutter test test/icon_render_test.dart`).
void main() {
  testWidgets('icon', (tester) async {
    final out = Platform.environment['YANKI_ICON'];
    final clock = ValueNotifier<double>(2.4);
    final m = AjanMotion();
    for (var i = 0; i < 90; i++) {
      m.step(2.4 + i / 60, 1, AjanMood.speaking, .45);
    }
    await tester.binding.setSurfaceSize(const Size(512, 512));
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFF0E2E78), Color(0xFF061331), Color(0xFF030919)],
              stops: [0, .6, 1],
            ),
          ),
          child: CustomPaint(
            painter: OrbPainter(clock, m),
            size: const Size(512, 512),
          ),
        ),
      ),
    );
    if (out == null) return;
    await tester.runAsync(() async {
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(out).writeAsBytes(png!.buffer.asUint8List());
    });
  });
}
