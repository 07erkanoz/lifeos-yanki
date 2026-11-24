import 'dart:async';
import 'dart:convert';

import '../mcp/mcp_client.dart';
import '../mcp/mcp_servers.dart';
import 'ajan_approval.dart';
import 'ajan_bridge.dart';
import 'general_tools.dart';

/// Tools as the voice's model sees them: declared, called, closed.
abstract class ToolHost {
  Future<List<Map<String, Object?>>> tools();

  /// The tool's answer as text, as the model reads it.
  Future<String> call(String name, Map<String, Object?> args);
  Future<void> close();
}

/// Yankı's tools in a spoken conversation: what is not any program's
/// ([AjanGeneralTools]: the rates, the weather, the news, music) and every
/// MCP server turned on ([McpServers]): LifeOS Folio's, LifeOS Linux's and
/// those the person added. One that changes anything asks first, on
/// Yankı's screen ([AjanApprovals]).
class AjanToolHost implements ToolHost {
  AjanToolHost(this._clients, {AjanGeneralTools? general})
    : _general = general ?? AjanGeneralTools();

  static Future<AjanToolHost> open() async {
    final servers = await McpServers.instance.load(again: true);
    return AjanToolHost([
      for (final s in servers)
        if (s.on) McpClient(s, approve: AjanApprovals.instance.request),
    ]);
  }

  /// What is asked of UYAP: done by the open Folio, started for it.
  static const _uyap = {'uyap_guncelle', 'evrak_indir'};

  final List<McpClient> _clients;
  final AjanGeneralTools _general;

  @override
  Future<List<Map<String, Object?>>> tools() async {
    final listed = await Future.wait([
      for (final c in _clients)
        c.declarations().timeout(
          const Duration(seconds: 25),
          onTimeout: () => const [],
        ),
    ]);
    return [...AjanGeneralTools.declarations, for (final l in listed) ...l];
  }

  @override
  Future<String> call(String name, Map<String, Object?> args) async {
    if (AjanGeneralTools.names.contains(name)) {
      return jsonEncode(await _general.call(name, args));
    }
    for (final c in _clients) {
      if (!c.owns(name)) continue;
      if (c.server.id == McpServers.folioId && _uyap.contains(name)) {
        // The request waits in Folio's folder; Folio does it once open.
        unawaited(AjanBridge.wakeFolio());
      }
      return c.call(name, args);
    }
    return jsonEncode({'durum': 'yok', 'aciklama': 'Bu adla bir araç yok.'});
  }

  @override
  Future<void> close() async {
    for (final c in _clients) {
      c.close();
    }
  }
}
