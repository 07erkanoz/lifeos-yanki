import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Yankı's folder where path_provider cannot be asked: an isolate of its
/// own (the tools) is given the window's.
Directory? supportGiven;

/// Yankı's own folder (`~/.local/share/tr.com.lifeos.Yanki`): its voice
/// settings, its models, its lock. Never Folio's.
Future<Directory> supportDirectory() async {
  if (supportGiven case final given?) return given;
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return dir;
}
