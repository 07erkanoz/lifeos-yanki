import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../mcp/mcp_client.dart';
import '../mcp/mcp_servers.dart';

/// The AI programs on this computer Yankı hands work to.
enum AiProvider {
  claude('claude', 'Claude'),
  codex('codex', 'Codex (ChatGPT)');

  const AiProvider(this.command, this.label);
  final String command, label;
}

class AiStatus {
  const AiStatus(this.provider, {this.path, this.signedIn = false});
  final AiProvider provider;
  final String? path;
  final bool signedIn;
  bool get usable => path != null && signedIn;
}

/// How hard the program thinks.
enum AiTier {
  normal('medium'),
  strong('high');

  const AiTier(this.effort);
  final String effort;
}

class AiFailure implements Exception {
  const AiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the program shows while it works.
sealed class AiEvent {
  const AiEvent();
}

/// A tool it calls.
class AiStep extends AiEvent {
  const AiStep(this.id, this.tool, {this.args = const {}, this.done = false});
  final String id, tool;
  final Map<String, Object?> args;
  final bool done;

  String get label {
    final name = tool.replaceAll('_', ' ');
    return done ? '$name tamam' : '$name çalışıyor';
  }
}

/// Claude's conversation for one voice session, gone on with.
class AiThread {
  AiThread(this.place);
  final String place;
  final ids = <AiProvider, String>{};
}

/// Yankı's AI switches. The voice is turned on in its own settings
/// ([VoiceSettings.on]); there is no further consent to give here: Yankı
/// is the person's own program, asking their own subscriptions.
class AiSettings {
  const AiSettings();

  static final on = ValueNotifier<bool>(true);

  bool get enabled => true;
  bool get consented => true;
  bool get lifeosMcp => true;

  static Future<AiSettings> load() async => const AiSettings();
  static Future<AiSettings> reload() async => const AiSettings();
}

/// Claude Code and Codex, as Yankı runs them.
abstract final class AiAssistant {
  static bool get shown => Platform.isLinux;

  static List<String> _searchPath(Map<String, String> env) {
    final home = env['HOME'] ?? '';
    return {
      ...(env['PATH'] ?? '').split(':').where((d) => d.isNotEmpty),
      if (home.isNotEmpty) ...[
        p.join(home, '.local', 'bin'),
        p.join(home, '.npm-global', 'bin'),
        p.join(home, '.claude', 'local'),
        p.join(home, '.bun', 'bin'),
        p.join(home, '.local', 'share', 'pnpm'),
      ],
      '/usr/local/bin',
      '/usr/bin',
    }.toList();
  }

  static String? find(String command) {
    for (final dir in _searchPath(Platform.environment)) {
      final f = File(p.join(dir, command));
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  /// The program's environment: the PATH it is found under made whole.
  static Map<String, String> environment() {
    final env = Map<String, String>.of(Platform.environment);
    env['PATH'] = _searchPath(env).join(':');
    env['NO_COLOR'] = '1';
    return env;
  }

  static void stop(Process process) => process.kill();

  static Future<AiStatus> status(AiProvider provider) async {
    final path = find(provider.command);
    if (path == null) return AiStatus(provider);
    try {
      switch (provider) {
        case AiProvider.claude:
          final r = await Process.run(path, [
            'auth',
            'status',
            '--json',
          ], environment: environment()).timeout(const Duration(seconds: 20));
          final json = jsonDecode('${r.stdout}');
          return AiStatus(
            provider,
            path: path,
            signedIn: json is Map && json['loggedIn'] == true,
          );
        case AiProvider.codex:
          final r = await Process.run(path, [
            'login',
            'status',
          ], environment: environment()).timeout(const Duration(seconds: 20));
          final said = '${r.stdout}\n${r.stderr}'.toLowerCase();
          return AiStatus(
            provider,
            path: path,
            signedIn:
                said.contains('logged in') && !said.contains('not logged'),
          );
      }
    } catch (_) {
      return AiStatus(provider, path: path);
    }
  }

  static Future<List<AiStatus>> statuses() =>
      Future.wait([for (final p in AiProvider.values) status(p)]);

  static const _system =
      'Sen LifeOS Yankı’nın arka plandaki yardımcısısın: kullanıcı sesli '
      'konuşuyor, sesli ajan ağır işleri sana devrediyor. Türkçe, kısa ve '
      'doğru cevap ver; cevabın sesli okunacak. Elindeki MCP araçlarını '
      '(LifeOS Folio, LifeOS Linux ve kullanıcının eklediği sunucular) '
      'gerektiğinde kullan; bilmediğini uydurma, bulamadığını söyle.';

  /// The tools Claude may run without asking: those that only read, of
  /// every server on. Listed once a session; changes need the voice,
  /// which asks the person on screen.
  static Future<List<String>> _allowed() async {
    final servers = await McpServers.instance.load();
    final names = <String>[];
    await Future.wait([
      for (final s in servers)
        if (s.on)
          () async {
            final c = McpClient(s);
            try {
              await c.declarations().timeout(const Duration(seconds: 25));
              for (final t in c.readOnly) {
                names.add('mcp__${s.id}__$t');
              }
            } catch (_) {
            } finally {
              c.close();
            }
          }(),
    ]);
    return names;
  }

  static List<String>? _allowedCache;
  static DateTime? _allowedAt;

  /// [prompt] asked of Claude Code (`claude -p`), with the MCP servers on;
  /// its answer's text.
  static Future<String> ask(
    AiProvider provider,
    String prompt, {
    AiTier? tier,
    void Function(AiEvent event)? onEvent,
    AiThread? thread,
    Future<void>? cancel,
  }) async {
    if (provider != AiProvider.claude) {
      throw AiFailure('${provider.label} burada yalnız sesle kullanılır.');
    }
    final path = find(provider.command);
    if (path == null) throw const AiFailure('Claude Code kurulu değil.');
    final at = _allowedAt;
    if (_allowedCache == null ||
        at == null ||
        DateTime.now().difference(at) > const Duration(minutes: 10)) {
      _allowedCache = await _allowed();
      _allowedAt = DateTime.now();
    }
    final folder = await Directory(
      p.join(
        Directory.systemTemp.path,
        'lifeos-yanki-${thread?.place ?? DateTime.now().millisecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final resume = thread?.ids[provider];
    final process = await Process.start(
      path,
      [
        '-p',
        '--system-prompt',
        _system,
        if (tier != null) ...['--effort', tier.effort],
        '--mcp-config',
        jsonEncode(McpServers.instance.claudeConfig()),
        '--strict-mcp-config',
        if (_allowedCache!.isNotEmpty) ...[
          '--allowedTools',
          _allowedCache!.join(','),
        ],
        '--tools',
        '',
        '--output-format',
        'stream-json',
        '--verbose',
        if (resume != null) ...['--resume', resume],
        if (thread == null) '--no-session-persistence',
        '--disable-slash-commands',
      ],
      workingDirectory: folder.path,
      environment: environment(),
    );
    unawaited(cancel?.then((_) => process.kill()));
    String? result;
    String? failure;
    final err = StringBuffer();
    final reading = Future.wait([
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
            Object? e;
            try {
              e = jsonDecode(line);
            } catch (_) {
              return;
            }
            if (e is! Map) return;
            if (e['session_id'] case final String id when thread != null) {
              thread.ids[provider] = id;
            }
            switch (e['type']) {
              case 'assistant':
                for (final c
                    in ((e['message'] as Map?)?['content'] as List?) ??
                        const []) {
                  if (c is Map && c['type'] == 'tool_use') {
                    final name = '${c['name']}'.replaceFirst(
                      RegExp(r'^mcp__[a-z0-9_]+?__'),
                      '',
                    );
                    onEvent?.call(
                      AiStep(
                        '${c['id']}',
                        name,
                        args:
                            (c['input'] as Map?)?.cast<String, Object?>() ??
                            const {},
                      ),
                    );
                  }
                }
              case 'user':
                for (final c
                    in ((e['message'] as Map?)?['content'] as List?) ??
                        const []) {
                  if (c is Map && c['type'] == 'tool_result') {
                    onEvent?.call(
                      AiStep('${c['tool_use_id']}', '', done: true),
                    );
                  }
                }
              case 'result':
                if (e['is_error'] == true) {
                  failure = '${e['result'] ?? e['subtype'] ?? 'hata'}';
                } else {
                  result = '${e['result'] ?? ''}';
                }
            }
          }),
      process.stderr.transform(utf8.decoder).forEach(err.write),
    ]);
    process.stdin.write(prompt);
    await process.stdin.close();
    final code = await process.exitCode.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    await reading;
    if (result case final r? when r.trim().isNotEmpty) return r.trim();
    if (failure case final f?) throw AiFailure(f);
    final said = err.toString().trim().split('\n').last;
    throw AiFailure(
      code == -1
          ? 'Claude 10 dakikada bitiremedi.'
          : said.isEmpty
          ? 'Claude cevap vermedi.'
          : said,
    );
  }
}

/// Which program answers a written or handed-on question.
abstract final class AiRelay {
  static Future<AiProvider?> usable(AiSettings settings) async {
    final s = await AiAssistant.status(AiProvider.claude);
    return s.usable ? AiProvider.claude : null;
  }
}
