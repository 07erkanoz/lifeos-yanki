import 'en_ekran.dart';
import 'en_ses.dart';

/// Yankı's texts in English, keyed by their Turkish (lib/l10n/dil.dart):
/// the screens' ([enEkran]) and the voice's ([enSes]).
/// test/dil_test.dart checks that every text passed to l() has its English.
const english = <String, String>{...enEkran, ...enSes};
