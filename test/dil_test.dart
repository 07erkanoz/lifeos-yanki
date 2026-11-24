import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_yanki/l10n/dil.dart';
import 'package:lifeos_yanki/l10n/en.dart';

/// Every text passed to l('…') in lib/, adjacent literals joined as Dart
/// joins them.
Set<String> _texts() {
  final call = RegExp(r"""\bl\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)""");
  final part = RegExp(r"""'((?:[^'\\]|\\.)*)'""");
  final found = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    for (final m in call.allMatches(f.readAsStringSync())) {
      found.add(
        part
            .allMatches(m.group(1)!)
            .map((p) => p.group(1)!.replaceAll(r"\'", "'"))
            .join(),
      );
    }
  }
  return found;
}

void main() {
  test('every text on screen has its English', () {
    final texts = _texts();
    expect(texts.length, greaterThan(100));
    final missing = [
      for (final t in texts)
        if (!english.containsKey(t)) t,
    ];
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('the English keeps every {n} the Turkish has', () {
    final hole = RegExp(r'\{\d+\}');
    for (final MapEntry(:key, :value) in english.entries) {
      expect(
        hole.allMatches(value).map((m) => m[0]).toSet(),
        hole.allMatches(key).map((m) => m[0]).toSet(),
        reason: key,
      );
    }
  });

  test('the language follows the computer, Turkish when it says nothing', () {
    expect(Dil.systemOf({'LANG': 'tr_TR.UTF-8'}), 'tr');
    expect(Dil.systemOf({'LANG': 'en_US.UTF-8'}), 'en');
    expect(Dil.systemOf({'LANG': 'de_DE.UTF-8'}), 'en');
    expect(Dil.systemOf({'LANGUAGE': 'tr:en', 'LANG': 'en_US.UTF-8'}), 'tr');
  });

  test('l fills its holes in both languages', () {
    Dil.set('tr');
    expect(l('Onay: {0}', ['X']), 'Onay: X');
    Dil.set('en');
    expect(l('Onay: {0}', ['X']), english['Onay: {0}']!.replaceAll('{0}', 'X'));
    Dil.set('sistem');
  });
}
