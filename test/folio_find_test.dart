import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_yanki/services/mcp/mcp_servers.dart';

void main() {
  const home = {'HOME': '/home/a', 'PATH': '/usr/bin'};
  String? find(
    Set<String> files, [
    Map<String, List<String>> menus = const {},
  ]) => McpServers.findFolio(
    home,
    runnable: files.contains,
    read: (path) => menus[path],
  );

  test('LifeOS package', () {
    expect(
      find({'/opt/lifeos-folio/lifeos_folio'}),
      '/opt/lifeos-folio/lifeos_folio',
    );
  });

  test('Folio’s own per-user installer (~/.local/share/lifeos-folio)', () {
    expect(
      find({'/home/a/.local/share/lifeos-folio/lifeos_folio'}),
      '/home/a/.local/share/lifeos-folio/lifeos_folio',
    );
  });

  test('wherever Folio’s menu entry points', () {
    expect(
      find(
        {'/srv/folio/lifeos_folio'},
        {
          '/home/a/.local/share/applications/com.erkanoz.evrak_convert.desktop':
              ['[Desktop Entry]', 'Exec="/srv/folio/lifeos_folio" %U'],
        },
      ),
      '/srv/folio/lifeos_folio',
    );
  });

  test('nothing installed', () {
    expect(find({}), isNull);
  });
}
