import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../l10n/dil.dart';
import 'mcp_servers.dart';

/// One MCP server's tools for Yankı's voice, run over standard input and
/// output. A tool that can change anything runs only after the person's
/// yes ([approve]), when the server asks for it ([McpServerConfig.approve]).
class McpClient {
  McpClient(this.server, {this.approve});

  final McpServerConfig server;

  /// The person's yes to [title] with [detail]; null when it cannot be
  /// asked. Without it nothing that changes anything runs.
  final Future<bool?> Function(String title, String detail)? approve;

  /// Whether [tool] (as the server lists it) can change anything: not
  /// marked read-only, or marked destructive, or one that runs any command
  /// it is given (`*_exec`: LifeOS marks them read-only).
  static bool changes(Map tool) {
    final a = tool['annotations'];
    final name = '${tool['name']}';
    if (name.endsWith('_exec')) return true;
    if (a is! Map) return true;
    return a['readOnlyHint'] != true || a['destructiveHint'] == true;
  }

  final _changing = <String>{};
  final _titles = <String, String>{};

  /// The tools that only read, by their own names: Claude may run them
  /// without asking.
  Set<String> get readOnly => {
    for (final n in _titles.keys)
      if (!_changing.contains(n)) n,
  };

  Process? _process;
  StreamSubscription<String>? _lines;

  /// Every server started and not yet ended, to end them all when Yankı
  /// does ([endAll]).
  static final _running = <Process>{};

  static void endAll() {
    for (final p in _running) {
      p.kill();
    }
    _running.clear();
  }

  final _waiting = <int, Completer<Map<String, Object?>>>{};
  var _next = 0;
  List<Map<String, Object?>>? _tools;
  String? lastError;

  Future<Map<String, Object?>> _rpc(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final process = await _started();
    final id = ++_next;
    final done = _waiting[id] = Completer<Map<String, Object?>>();
    process.stdin.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    try {
      return await done.future.timeout(timeout);
    } finally {
      _waiting.remove(id);
    }
  }

  Future<Process>? _starting;

  Future<Process> _started() async {
    if (_process case final p?) return p;
    return _starting ??= () async {
      try {
        final p = await Process.start(
          server.command,
          server.args,
          environment: server.env.isEmpty ? null : server.env,
        );
        _process = p;
        _running.add(p);
        unawaited(p.exitCode.then((_) => _running.remove(p)));
        final err = StringBuffer();
        p.stderr.transform(utf8.decoder).listen((s) {
          if (err.length < 4000) err.write(s);
        });
        _lines = p.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              try {
                final m = jsonDecode(line);
                if (m is Map && m['id'] is int) {
                  _waiting[m['id']]?.complete(m.cast<String, Object?>());
                }
              } catch (_) {}
            });
        unawaited(
          p.exitCode.then((code) {
            if (identical(_process, p)) {
              final said = err.toString().trim();
              lastError = said.isEmpty ? l('çıktı ({0})', [code]) : said;
              _reset();
            }
          }),
        );
        final id = ++_next;
        final hello = _waiting[id] = Completer<Map<String, Object?>>();
        p.stdin.writeln(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'method': 'initialize',
            'params': {
              'protocolVersion': '2025-06-18',
              'capabilities': {},
              'clientInfo': {'name': 'lifeos-yanki', 'version': '1'},
            },
          }),
        );
        await hello.future.timeout(const Duration(seconds: 20));
        _waiting.remove(id);
        p.stdin.writeln(
          jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
        );
        return p;
      } finally {
        _starting = null;
      }
    }();
  }

  void _reset() {
    _lines?.cancel();
    _lines = null;
    _process = null;
    for (final w in _waiting.values) {
      if (!w.isCompleted) w.completeError(StateError('${server.id} ended'));
    }
    _waiting.clear();
  }

  /// The tools given, as Yankı declares them (with the server's prefix);
  /// none when the server does not answer.
  Future<List<Map<String, Object?>>> declarations() async {
    if (_tools case final t?) return t;
    try {
      final r = await _rpc(
        'tools/list',
        {},
        timeout: const Duration(seconds: 20),
      );
      final listed = (r['result'] as Map?)?['tools'];
      _changing.clear();
      _titles.clear();
      final tools = <Map<String, Object?>>[];
      final asks = server.approve;
      for (final t in listed is List ? listed : const []) {
        if (t is! Map || t['name'] is! String) continue;
        final name = t['name'] as String;
        final changing = changes(t);
        if (changing) _changing.add(name);
        _titles[name] = '${t['title'] ?? name}';
        final said = '${t['description'] ?? ''}';
        tools.add({
          'name': '${server.prefix}$name',
          'title': t['title'] ?? name,
          'description': server.prefix.isEmpty
              ? said
              : changing && asks
              ? '${server.name}: $said Değişiklik yapar: önce kullanıcıya ne '
                    'yapacağını söyle; çalışmadan önce Yankı ekranında '
                    'onayı istenir. Onaylanmazsa yeniden deneme.'
              : '${server.name}: $said',
          'inputSchema':
              t['inputSchema'] ?? {'type': 'object', 'properties': {}},
          'annotations': {
            'readOnlyHint': !changing,
            'destructiveHint':
                (t['annotations'] as Map?)?['destructiveHint'] == true,
            'idempotentHint': !changing,
            'openWorldHint':
                (t['annotations'] as Map?)?['openWorldHint'] == true,
          },
        });
      }
      lastError = null;
      return _tools = tools;
    } catch (e) {
      lastError ??= '$e';
      return const [];
    }
  }

  /// Whether [name] (with the prefix) is one of this server's.
  bool owns(String name) {
    if (!name.startsWith(server.prefix)) return false;
    return _titles.containsKey(name.substring(server.prefix.length));
  }

  /// [name] (with the prefix) asked of the server with [args]: its
  /// answer's text.
  Future<String> call(String name, Map<String, Object?> args) async {
    final bare = name.startsWith(server.prefix)
        ? name.substring(server.prefix.length)
        : name;
    if (_tools == null) await declarations();
    if (!_titles.containsKey(bare)) {
      return jsonEncode({
        'durum': 'yok',
        'aciklama': '${server.name} içinde bu adla bir araç yok.',
      });
    }
    if (server.approve && _changing.contains(bare)) {
      final yes = await approve?.call(
        '${server.name} · ${_titles[bare]!}',
        detail(args),
      );
      if (yes == null) {
        return jsonEncode({
          'durum': 'onay_sorulamadi',
          'aciklama':
              'Bu araç değişiklik yapar ve onay Yankı ekranında istenir; '
              'ekran açık değil. Kullanıcıdan Yankı’yı tam ekran açmasını '
              'iste.',
        });
      }
      if (!yes) {
        return jsonEncode({
          'durum': 'onaylanmadi',
          'aciklama': 'Kullanıcı onaylamadı; hiçbir şey yapılmadı.',
        });
      }
    }
    try {
      final r = await _rpc('tools/call', {'name': bare, 'arguments': args});
      if (r['error'] case final Map e) {
        return jsonEncode({'durum': 'hata', 'aciklama': '${e['message']}'});
      }
      final result = (r['result'] as Map?) ?? const {};
      final text = [
        for (final c in (result['content'] as List?) ?? const [])
          if (c is Map && c['type'] == 'text') '${c['text']}',
      ].join('\n');
      return result['isError'] == true
          ? jsonEncode({'durum': 'hata', 'aciklama': text})
          : text;
    } catch (e) {
      return jsonEncode({
        'durum': 'hata',
        'aciklama': '${server.name} yanıt vermedi.',
      });
    }
  }

  /// [args] as the person reads them: one "key: value" a line.
  static String detail(Map<String, Object?> args) {
    final lines = [
      for (final MapEntry(:key, :value) in args.entries)
        if (value != null && '$value'.isNotEmpty)
          '$key: ${value is String ? value : jsonEncode(value)}',
    ];
    return lines.isEmpty ? l('Ek bilgi yok.') : lines.join('\n');
  }

  /// Started and asked for its tools once: whether it answers, and how
  /// many tools it has (for the settings page).
  static Future<(int, String?)> probe(McpServerConfig server) async {
    final c = McpClient(server);
    try {
      final t = await c.declarations();
      return (t.length, t.isEmpty ? c.lastError : null);
    } finally {
      c.close();
    }
  }

  void close() {
    _process?.kill();
    _reset();
  }
}
