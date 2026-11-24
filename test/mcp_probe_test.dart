import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_yanki/services/mcp/mcp_client.dart';
import 'package:lifeos_yanki/services/mcp/mcp_servers.dart';

/// Talks to the MCP servers on this computer, where they are installed
/// (`YANKI_MCP=1 flutter test test/mcp_probe_test.dart`).
void main() {
  final live = Platform.environment['YANKI_MCP'] == '1';
  test('LifeOS Linux answers', () async {
    final lifeos = McpServers.which('lifeos');
    if (!live || lifeos == null) return;
    final (n, err) = await McpClient.probe(
      McpServerConfig(
        id: 'lifeos',
        name: 'LifeOS',
        command: lifeos,
        args: const ['mcp', 'sun'],
      ),
    );
    // ignore: avoid_print
    print('lifeos: $n araç ${err ?? ''}');
    expect(n, greaterThan(0));
  });
  test('LifeOS Folio answers', () async {
    final folio = McpServers.folioProgram;
    if (!live || folio == null) return;
    final c = McpClient(
      McpServerConfig(
        id: 'folio',
        name: 'Folio',
        command: folio,
        args: const ['--mcp', '--dis'],
        approve: false,
      ),
    );
    final tools = await c.declarations();
    // ignore: avoid_print
    print('folio: ${tools.length} araç ${c.lastError ?? ''}');
    // ignore: avoid_print
    print([for (final t in tools.take(12)) t['name']]);
    if (tools.any((t) => t['name'] == 'ajanda')) {
      final a = await c.call('ajanda', const {});
      // ignore: avoid_print
      print('ajanda: ${a.length > 200 ? a.substring(0, 200) : a}');
    }
    c.close();
  });
  test('an added server (a command that is not MCP) fails cleanly', () async {
    final (n, err) = await McpClient.probe(
      const McpServerConfig(id: 'yok', name: 'Yok', command: '/bin/false'),
    );
    expect(n, 0);
    expect(err, isNotNull);
  });
}
