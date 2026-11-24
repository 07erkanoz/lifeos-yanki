import 'package:flutter/material.dart';

import '../../services/mcp/mcp_servers.dart';

/// The MCP servers Yankı reaches, quietly, in a corner of the full screen:
/// a lit dot for each one on.
class McpStrip extends StatelessWidget {
  const McpStrip({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: McpServers.instance,
    builder: (context, _) {
      final all = McpServers.instance.all;
      if (all.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'MCP',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              letterSpacing: 2,
              color: Color(0xFF5F86B0),
            ),
          ),
          const SizedBox(height: 6),
          for (final s in all)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.on
                          ? const Color(0xFF3CDCFF)
                          : const Color(0xFF34465F),
                      boxShadow: s.on
                          ? const [
                              BoxShadow(
                                color: Color(0xFF3CDCFF),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.name,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: s.on
                          ? const Color(0xFFB9D3EE)
                          : const Color(0xFF5F7591),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
