import 'dart:io';

import 'package:flutter/foundation.dart';

import 'en.dart';

/// Yankı's language: Turkish, its first language, or English. Every text
/// on screen is written in Turkish and passed through [l]; on English it
/// comes from [english] (Turkish → English). A text with no English shows
/// in Turkish: nothing breaks.
class Dil {
  Dil._();

  /// 'sistem' (the computer's language), 'tr' or 'en': the person's choice
  /// (Ayarlar › Dil).
  static String choice = 'sistem';

  /// The language in use; widgets that show text listen to it.
  static final current = ValueNotifier<String>(_system());

  static bool get en => current.value == 'en';

  /// [choice] set and applied.
  static void set(String value) {
    choice = const {'tr', 'en'}.contains(value) ? value : 'sistem';
    current.value = choice == 'sistem' ? _system() : choice;
  }

  /// tr on a Turkish computer (or one that says nothing), en on any other.
  static String _system([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    for (final key in const ['LANGUAGE', 'LC_ALL', 'LC_MESSAGES', 'LANG']) {
      final v = env[key] ?? '';
      if (v.isEmpty || v == 'C' || v == 'POSIX' || v.startsWith('C.')) {
        continue;
      }
      return v.toLowerCase().startsWith('tr') ? 'tr' : 'en';
    }
    final name = Platform.localeName.toLowerCase();
    return name.isEmpty || name.startsWith('tr') || name.startsWith('c')
        ? 'tr'
        : 'en';
  }

  @visibleForTesting
  static String systemOf(Map<String, String> environment) =>
      _system(environment);
}

/// [tr] in the language in use; `{0}`, `{1}`… are filled from [args] in
/// either language.
String l(String tr, [List<Object?> args = const []]) {
  var out = Dil.en ? (english[tr] ?? tr) : tr;
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return out;
}
