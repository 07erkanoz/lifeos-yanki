import 'dart:io';

/// The API services Yankı asks itself, with the person's own key.
enum ApiService { gemini }

/// Keys kept in the desktop's keyring (libsecret, `secret-tool`), never in
/// a file; `GEMINI_API_KEY` in the environment stands in for one.
abstract final class GroqChat {
  static const _service = 'lifeos-yanki';

  static Future<String?> key(ApiService service) async {
    final env = Platform.environment['${service.name.toUpperCase()}_API_KEY'];
    if (env != null && env.trim().isNotEmpty) return env.trim();
    try {
      final r = await Process.run('secret-tool', [
        'lookup',
        'service',
        _service,
        'anahtar',
        service.name,
      ]).timeout(const Duration(seconds: 5));
      final k = '${r.stdout}'.trim();
      return r.exitCode == 0 && k.isNotEmpty ? k : null;
    } catch (_) {
      return null;
    }
  }

  /// [value] kept for [service]; empty, forgotten.
  static Future<bool> setKey(ApiService service, String value) async {
    try {
      if (value.trim().isEmpty) {
        final r = await Process.run('secret-tool', [
          'clear',
          'service',
          _service,
          'anahtar',
          service.name,
        ]);
        return r.exitCode == 0;
      }
      final p = await Process.start('secret-tool', [
        'store',
        '--label=LifeOS Yankı · ${service.name}',
        'service',
        _service,
        'anahtar',
        service.name,
      ]);
      p.stdin.write(value.trim());
      await p.stdin.close();
      return await p.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

/// What the voice spent; Yankı keeps no account of it.
abstract final class AiUsage {
  static Future<void> add(
    ApiService service, {
    int input = 0,
    int output = 0,
  }) async {}
}
