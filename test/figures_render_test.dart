import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_yanki/ui/desktop/ajan_skins.dart';
import 'package:lifeos_yanki/ui/desktop/yanki_figures.dart';

/// Draws each of Yankı's figures in each mood to a PNG, for the eye
/// (`YANKI_SHOTS=<folder> flutter test test/figures_render_test.dart`).
void main() {
  final out = Platform.environment['YANKI_SHOTS'];
  for (final skin in [AjanSkin.yanki, AjanSkin.ag, AjanSkin.dalga]) {
    for (final mood in AjanMood.values) {
      testWidgets('${skin.name} ${mood.name}', (tester) async {
        await tester.runAsync(() async {
          await DotFieldBackdrop.load();
        });
        final clock = ValueNotifier<double>(3.2);
        final m = AjanMotion();
        for (var i = 0; i < 160; i++) {
          final s = .5 + .5 * (i % 23 / 23);
          m.step(3.2 + i / 60, 1, mood, mood == AjanMood.speaking ? s : .3);
        }
        const h = 420.0;
        final w = h * skin.aspect;
        await tester.binding.setSurfaceSize(Size(w, h));
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: Stack(
              textDirection: TextDirection.ltr,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: skin.backdrop(clock)),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: skin.figure(clock, m)),
                ),
              ],
            ),
          ),
        );
        if (out == null) return;
        await tester.runAsync(() async {
          await tester.pump();
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$out/${skin.name}_${mood.name}.png')
              .writeAsBytes(png!.buffer.asUint8List());
        });
      });
    }
  }
  test('figures are built', () {
    expect(EchoPainter, isNotNull);
  });
}
