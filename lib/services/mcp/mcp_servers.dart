import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../platform/app_directories.dart';

/// One MCP server Yankı runs over standard input and output.
@immutable
class McpServerConfig {
  const McpServerConfig({
    required this.id,
    required this.name,
    required this.command,
    this.args = const [],
    this.env = const {},
    this.on = true,
    this.builtIn = false,
    this.approve = true,
  });

  /// Short, unique, `[a-z0-9_]`: the tools' prefix (`<id>_`) and Claude's
  /// server name (`mcp__<id>__…`).
  final String id;

  /// As the person reads it ("LifeOS Folio").
  final String name;
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final bool on;

  /// Folio and LifeOS: found on this computer, never deleted (turned off).
  final bool builtIn;

  /// A tool that changes anything runs only after the person's yes on
  /// Yankı's screen. Folio guards its own writes (agenda, notes), so it
  /// does not ask again.
  final bool approve;

  /// The prefix the voice sees this server's tools under. Folio's keep
  /// their own names: the voice's rules name them (`ajanda`, `dosya_sec`).
  String get prefix => id == McpServers.folioId ? '' : '${id}_';

  static final _idPattern = RegExp(r'^[a-z][a-z0-9_]{1,23}$');
  static bool validId(String id) => _idPattern.hasMatch(id);

  McpServerConfig copyWith({
    String? name,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    bool? on,
    bool? approve,
  }) => McpServerConfig(
    id: id,
    name: name ?? this.name,
    command: command ?? this.command,
    args: args ?? this.args,
    env: env ?? this.env,
    on: on ?? this.on,
    builtIn: builtIn,
    approve: approve ?? this.approve,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ad': name,
    'komut': command,
    'argumanlar': args,
    if (env.isNotEmpty) 'ortam': env,
    'acik': on,
    'onay': approve,
  };

  static McpServerConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = '${json['id'] ?? ''}';
    final command = '${json['komut'] ?? ''}';
    if (!validId(id) || command.isEmpty) return null;
    return McpServerConfig(
      id: id,
      name: '${json['ad'] ?? id}',
      command: command,
      args: [for (final a in (json['argumanlar'] as List?) ?? const []) '$a'],
      env: {
        for (final e in ((json['ortam'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      on: json['acik'] != false,
      approve: json['onay'] != false,
    );
  }
}

/// The MCP servers Yankı's voice and Claude have: LifeOS Folio's
/// (`lifeos_folio --mcp --dis`) and LifeOS Linux's (`lifeos mcp sun`) when
/// they are installed, and any others the person added. Kept in
/// `mcp.json`; the built-in ones keep only whether they are on.
class McpServers extends ChangeNotifier {
  McpServers._();
  static final instance = McpServers._();

  static const folioId = 'folio', lifeosId = 'lifeos';

  List<McpServerConfig> _servers = const [];
  bool _loaded = false;

  List<McpServerConfig> get all => _servers;
  List<McpServerConfig> get enabled => [
    for (final s in _servers)
      if (s.on) s,
  ];

  static Future<File> Function() file = () async =>
      File(p.join((await supportDirectory()).path, 'mcp.json'));

  /// Folio's program, where it is installed.
  static String? get folioProgram {
    for (final path in const [
      '/opt/lifeos-folio/lifeos_folio',
      '/usr/bin/lifeos-folio',
    ]) {
      if (File(path).existsSync()) return path;
    }
    return which('lifeos_folio') ?? which('lifeos-folio');
  }

  static String? which(String command) {
    for (final dir in (Platform.environment['PATH'] ?? '/usr/bin').split(':')) {
      if (dir.isEmpty) continue;
      final f = File(p.join(dir, command));
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  static List<McpServerConfig> _builtIns() => [
    if (folioProgram case final folio?)
      McpServerConfig(
        id: folioId,
        name: 'LifeOS Folio',
        command: folio,
        args: const ['--mcp', '--dis'],
        builtIn: true,
        approve: false,
      ),
    if (which('lifeos') case final lifeos?)
      McpServerConfig(
        id: lifeosId,
        name: 'LifeOS Linux',
        command: lifeos,
        args: const ['mcp', 'sun'],
        builtIn: true,
      ),
  ];

  Future<List<McpServerConfig>> load({bool again = false}) async {
    if (_loaded && !again) return _servers;
    Map kept = const {};
    try {
      final json = jsonDecode(await (await file()).readAsString());
      if (json is Map) kept = json;
    } catch (_) {}
    final builtInOn = (kept['yerlesik'] as Map?) ?? const {};
    _servers = [
      for (final b in _builtIns()) b.copyWith(on: builtInOn[b.id] != false),
      for (final s in (kept['sunucular'] as List?) ?? const [])
        if (McpServerConfig.fromJson(s) case final c?)
          if (c.id != folioId && c.id != lifeosId) c,
    ];
    _loaded = true;
    notifyListeners();
    return _servers;
  }

  Future<void> _save() async {
    final f = await file();
    await f.parent.create(recursive: true);
    final part = File('${f.path}.part');
    await part.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'yerlesik': {
          for (final s in _servers)
            if (s.builtIn) s.id: s.on,
        },
        'sunucular': [
          for (final s in _servers)
            if (!s.builtIn) s.toJson(),
        ],
      }),
      flush: true,
    );
    await part.rename(f.path);
    notifyListeners();
  }

  /// [server] added, or put in place of the one with its id.
  Future<void> put(McpServerConfig server) async {
    await load();
    final i = _servers.indexWhere((s) => s.id == server.id);
    _servers = [..._servers];
    if (i < 0) {
      _servers.add(server);
    } else {
      _servers[i] = _servers[i].builtIn
          ? _servers[i].copyWith(on: server.on)
          : server;
    }
    await _save();
  }

  Future<void> remove(String id) async {
    await load();
    _servers = [
      for (final s in _servers)
        if (s.id != id || s.builtIn) s,
    ];
    await _save();
  }

  Future<void> setOn(String id, bool on) async {
    await load();
    _servers = [for (final s in _servers) s.id == id ? s.copyWith(on: on) : s];
    await _save();
  }

  /// `--mcp-config` for Claude Code: the servers on.
  Map<String, Object?> claudeConfig() => {
    'mcpServers': {
      for (final s in enabled)
        s.id: {
          'type': 'stdio',
          'command': s.command,
          'args': s.args,
          if (s.env.isNotEmpty) 'env': s.env,
        },
    },
  };
}
