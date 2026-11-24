import 'dart:async';

import '../../services/voice/voice_settings.dart';
import '../../services/voice/codex_conversation.dart';
import '../../services/desktop/autostart.dart';

import 'package:flutter/material.dart';

import '../../l10n/dil.dart';
import '../../services/ai/ai_assistant.dart';
import '../../services/ai/ai_keys.dart';
import '../../services/mcp/mcp_client.dart';
import '../../services/mcp/mcp_servers.dart';
import '../../services/voice/folio_ajan.dart';
import '../desktop/ajan_skins.dart';

const _ground = Color(0xFF060B18);
const _panel = Color(0xFF0C1528);
const _line = Color(0x1F7FB8FF);
const _accent = Color(0xFF38BDF8);
const _muted = Color(0xFF8BA3C7);
const _text = Color(0xFFE6F0FF);

/// Yankı's settings: the voice, the wake word, the look, the keys, and the
/// MCP servers its voice and Claude have.
class YankiSettingsPage extends StatefulWidget {
  const YankiSettingsPage({super.key, required this.ajan});
  final FolioAjan ajan;

  @override
  State<YankiSettingsPage> createState() => _YankiSettingsPageState();
}

class _YankiSettingsPageState extends State<YankiSettingsPage> {
  FolioAjan get ajan => widget.ajan;
  final _city = TextEditingController();
  final _gemini = TextEditingController();
  bool _geminiKept = false;
  List<AiStatus>? _programs;
  final _probes = <String, (int, String?)?>{};
  bool? _autostart;
  CodexCatalog? _catalog;
  String? _catalogError;
  String? _sampling;

  @override
  void initState() {
    super.initState();
    ajan.addListener(_changed);
    Dil.current.addListener(_changed);
    McpServers.instance.addListener(_changed);
    _city.text = ajan.settings.city;
    unawaited(McpServers.instance.load(again: true));
    unawaited(() async {
      final k = await GroqChat.key(ApiService.gemini);
      if (mounted) setState(() => _geminiKept = k != null);
    }());
    unawaited(() async {
      final on = await Autostart.isOn();
      if (mounted) setState(() => _autostart = on);
    }());
    unawaited(_loadCatalog());
    unawaited(() async {
      final s = await AiAssistant.statuses();
      if (mounted) setState(() => _programs = s);
    }());
  }

  @override
  void dispose() {
    ajan.removeListener(_changed);
    Dil.current.removeListener(_changed);
    McpServers.instance.removeListener(_changed);
    _city.dispose();
    _gemini.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Codex's models and voices, asked of Codex itself.
  Future<void> _loadCatalog() async {
    try {
      final c = await ajan.codex.catalog().timeout(const Duration(seconds: 40));
      if (mounted) setState(() => _catalog = c);
    } catch (e) {
      if (mounted) {
        setState(
          () => _catalogError = l('Codex’in listesi alınamadı: {0}', [e]),
        );
      }
    }
  }

  Future<void> _sample(String voice) async {
    if (_sampling != null || ajan.voice.active) return;
    setState(() => _sampling = voice);
    try {
      await ajan.codex.sample(voice);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sampling = null);
    }
  }

  static String _effortName(String e) => switch (e) {
    'minimal' => l('En az'),
    'low' => l('Düşük'),
    'medium' => l('Orta'),
    'high' => l('Yüksek'),
    'xhigh' => l('Çok yüksek'),
    'max' => l('En yüksek'),
    final other => other,
  };

  static String _title(String id) =>
      id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}';

  /// A dropdown of [options] (value → what it shows); a [value] not among
  /// them is shown too, as it is.
  Widget _choice(
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    final all = {...options, if (!options.containsKey(value)) value: value};
    return DropdownButton<String>(
      value: value,
      dropdownColor: _panel,
      underline: const SizedBox.shrink(),
      items: [
        for (final MapEntry(:key, :value) in all.entries)
          DropdownMenuItem(value: key, child: Text(value)),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }

  List<Widget> _models(VoiceSettings s) {
    final c = _catalog;
    final model =
        c?.models.where((m) => m.id == s.codexModel).firstOrNull ??
        c?.models.where((m) => m.isDefault).firstOrNull;
    final efforts = (model?.efforts.isNotEmpty ?? false)
        ? model!.efforts
        : const ['low', 'medium', 'high', 'xhigh'];
    Widget waiting() => c == null && _catalogError == null
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(l('Codex yok'), style: const TextStyle(color: _muted));
    return [
      _row(
        l('Codex modeli'),
        _catalogError ??
            l('Sesin arkasında düşünen model. Boşsa Codex’in varsayılanı.'),
        c == null
            ? waiting()
            : _choice(s.codexModel, {
                '': l('Varsayılan'),
                for (final m in c.models)
                  m.id: m.isDefault ? l('{0} (varsayılan)', [m.name]) : m.name,
              }, (v) => ajan.saveSettings(s.copyWith(codexModel: v))),
      ),
      _row(
        l('Codex düşünmesi'),
        l(
          'Arttıkça cevap gecikir ve kota daha çok harcanır; sesli sohbet '
          'için düşük önerilir.',
        ),
        _choice(s.codexEffort, {
          for (final e in efforts) e: _effortName(e),
        }, (v) => ajan.saveSettings(s.copyWith(codexEffort: v))),
      ),
      _row(
        l('Codex sesi'),
        l('Yankı’nın konuşan sesi. ▶ ile bir cümle dinleyin.'),
        c == null
            ? waiting()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _choice(s.codexVoice, {
                    '': l('Varsayılan'),
                    for (final v in c.voices) v: _title(v),
                  }, (v) => ajan.saveSettings(s.copyWith(codexVoice: v))),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l('Dinle'),
                    onPressed: _sampling != null || ajan.voice.active
                        ? null
                        : () => unawaited(_sample(s.codexVoice)),
                    icon: _sampling != null
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                  ),
                ],
              ),
      ),
      _switch(
        l('Ağır işleri Claude yapsın'),
        l(
          'Taslak, uzun inceleme ve araştırma Claude Code’a gider; kapalıyken '
          'Codex hepsini kendisi yapar.',
        ),
        s.handOn,
        (v) => ajan.saveSettings(s.copyWith(handOn: v)),
      ),
      _row(
        l('Claude modeli'),
        l('Ağır işleri yapan model. Varsayılan: Claude Code’un kendi seçimi.'),
        _choice(s.claudeModel, {
          '': l('Varsayılan'),
          'fable': 'Fable',
          'opus': 'Opus',
          'sonnet': 'Sonnet',
          'haiku': 'Haiku',
        }, (v) => ajan.saveSettings(s.copyWith(claudeModel: v))),
      ),
      _row(
        l('Claude eforu'),
        l(
          'Claude’un ne kadar düşüneceği; yüksek efor daha yavaş ve pahalıdır.',
        ),
        _choice(s.claudeEffort, {
          for (final e in const ['low', 'medium', 'high', 'xhigh', 'max'])
            e: _effortName(e),
        }, (v) => ajan.saveSettings(s.copyWith(claudeEffort: v))),
      ),
      _row(
        l('Gemini sesi'),
        l('Codex yokken konuşan yedek ses.'),
        _choice(s.voice, {
          '': l('Varsayılan'),
          for (final v in const [
            'Puck',
            'Charon',
            'Kore',
            'Fenrir',
            'Aoede',
            'Leda',
            'Orus',
            'Zephyr',
          ])
            v: v,
        }, (v) => ajan.saveSettings(s.copyWith(voice: v))),
      ),
    ];
  }

  Future<void> _probe(McpServerConfig s) async {
    setState(() => _probes[s.id] = null);
    final r = await McpClient.probe(s);
    if (mounted) setState(() => _probes[s.id] = r);
  }

  @override
  Widget build(BuildContext context) {
    final s = ajan.settings;
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _ground,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _panel,
          onSurface: _text,
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _ground,
          title: Text(l('Yankı · Ayarlar')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
          children: [
            _section(l('Genel'), [
              _row(
                l('Dil'),
                l('Ekranların ve Yankı’nın dili.'),
                DropdownButton<String>(
                  value: const {'tr', 'en'}.contains(s.language)
                      ? s.language
                      : 'sistem',
                  dropdownColor: _panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 'sistem',
                      child: Text(l('Sistem dili')),
                    ),
                    const DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                    const DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) => v == null
                      ? null
                      : ajan.saveSettings(s.copyWith(language: v)),
                ),
              ),
            ]),
            _section(l('Ses'), [
              _switch(
                l('Sesli ajan'),
                l('Kapalıyken Yankı konuşmaz ve dinlemez.'),
                s.on,
                (v) => ajan.saveSettings(s.copyWith(on: v)),
              ),
              _switch(
                l('Sesle aç'),
                l(
                  '“Merhaba Yankı” ya da “Yankı açıl” denince açılır. Bu '
                  'bilgisayarda tanınır (Vosk), hiçbir şey dışarı gitmez.',
                ),
                s.wake,
                (v) => ajan.saveSettings(s.copyWith(wake: v)),
              ),
              _switch(
                l('Sesle kapat'),
                l(
                  '“Kapan”, “görüşürüz”, “teşekkürler” denince konuşma biter '
                  've pencere de kapanır (tepsiye ya da dinlemeye döner).',
                ),
                s.voiceClose,
                (v) => ajan.saveSettings(s.copyWith(voiceClose: v)),
              ),
              _switch(
                l('Kulaklık'),
                l(
                  'Yankı konuşurken araya girilebilir; ses mikrofona geri '
                  'dönmez.',
                ),
                s.headphones,
                (v) => ajan.saveSettings(s.copyWith(headphones: v)),
              ),
              _row(
                l('Görünüm'),
                l('Tam ekranın figürü.'),
                DropdownButton<String>(
                  value: AjanSkin.of(s.skin).name,
                  dropdownColor: _panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final k in AjanSkin.values)
                      DropdownMenuItem(value: k.name, child: Text(k.label)),
                  ],
                  onChanged: (v) => v == null ? null : ajan.setSkin(v),
                ),
              ),
              _row(
                l('Şehir'),
                l('Hava durumu için (ör. Kadıköy/İstanbul).'),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(isDense: true),
                    onSubmitted: (v) =>
                        ajan.saveSettings(s.copyWith(city: v.trim())),
                    onTapOutside: (_) {
                      if (_city.text.trim() != s.city) {
                        unawaited(
                          ajan.saveSettings(
                            s.copyWith(city: _city.text.trim()),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ]),
            _section(l('Masaüstü'), [
              _switch(
                l('Sistem tepsisinde kal'),
                l(
                  'Pencere kapanınca Yankı tepside durur; simgeye tıklayınca '
                  'açılır, menüsünden küre, ayarlar ve çıkış seçilir.',
                ),
                s.tray,
                (v) => ajan.saveSettings(s.copyWith(tray: v)),
              ),
              _switch(
                l('Oturum açılınca başla'),
                l(
                  'Pencere açmadan başlar: tepside durur, “Sesle aç” açıksa '
                  'uyandırma sözünü dinler.',
                ),
                _autostart ?? false,
                (v) async {
                  setState(() => _autostart = v);
                  await Autostart.set(v);
                },
              ),
            ]),
            _section(l('Modeller'), _models(s)),
            _section(l('Programlar'), [
              for (final p in _programs ?? const <AiStatus>[])
                _row(
                  p.provider.label,
                  p.provider == AiProvider.codex
                      ? l(
                          'Ana ses (ChatGPT aboneliğiyle). Kurmak için: '
                          'npm i -g @openai/codex, sonra codex login.',
                        )
                      : l(
                          'Ağır işler (Claude Code). Kurmak için: '
                          'npm i -g @anthropic-ai/claude-code, sonra claude.',
                        ),
                  _badge(
                    p.usable
                        ? l('Hazır')
                        : p.path == null
                        ? l('Kurulu değil')
                        : l('Oturum açık değil'),
                    p.usable,
                  ),
                ),
              if (_programs == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              _row(
                l('Gemini anahtarı'),
                _geminiKept
                    ? l(
                        'Anahtar masaüstünün anahtarlığında. Codex yoksa ses '
                        'Gemini Live ile konuşur.',
                      )
                    : l(
                        'Codex yoksa ses Gemini Live ile konuşur; anahtar '
                        'masaüstünün anahtarlığında saklanır.',
                      ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _gemini,
                    obscureText: true,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _geminiKept ? l('•••••••• (kayıtlı)') : 'AIza…',
                    ),
                    onSubmitted: (v) async {
                      final ok = await GroqChat.setKey(ApiService.gemini, v);
                      _gemini.clear();
                      if (!mounted) return;
                      setState(() => _geminiKept = ok && v.trim().isNotEmpty);
                    },
                  ),
                ),
              ),
            ]),
            _section(
              l('MCP sunucuları'),
              [
                for (final m in McpServers.instance.all) _server(m),
                if (McpServers.instance.all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l('Henüz sunucu yok.'),
                      style: const TextStyle(color: _muted),
                    ),
                  ),
              ],
              action: FilledButton.tonalIcon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l('Sunucu ekle')),
              ),
              note: l(
                'Yankı’nın sesi ve Claude bu sunucuların araçlarını '
                'kullanır. Değişiklik yapan bir araç, “onay iste” açıksa, '
                'çalışmadan önce ekranda onayını ister. Claude yalnız '
                'okuyan araçları kullanabilir.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _server(McpServerConfig m) {
    final probe = _probes[m.id];
    final probing = _probes.containsKey(m.id) && probe == null;
    final said = probe == null
        ? null
        : probe.$2 == null
        ? l('{0} araç', [probe.$1])
        : l('Yanıt yok: {0}', [probe.$2]);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0x0A7FB8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(
            m.builtIn ? Icons.verified_outlined : Icons.extension_outlined,
            color: _accent,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.builtIn ? m.name : '${m.name}  ·  ${m.prefix}…',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  m.command.isEmpty
                      ? l(
                          'Bu bilgisayarda bulunamadı. Kuruluysa Yankı’yı '
                          'yeniden açın; olmazsa “Sunucu ekle” ile programın '
                          'yolunu verin.',
                        )
                      : [m.command, ...m.args].join(' '),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.5,
                    color: _muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (said != null || probing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      probing ? l('Deneniyor…') : said!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: probe?.$2 == null
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l('Dene'),
            onPressed: probing || m.command.isEmpty ? null : () => _probe(m),
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
          if (!m.builtIn) ...[
            IconButton(
              tooltip: l('Düzenle'),
              onPressed: () => _edit(m),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l('Sil'),
              onPressed: () => _remove(m),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
          Switch(
            value: m.on && m.command.isNotEmpty,
            onChanged: m.command.isEmpty
                ? null
                : (v) => McpServers.instance.setOn(m.id, v),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(McpServerConfig m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l('{0} silinsin mi?', [m.name])),
        content: Text(l('Yankı bu sunucunun araçlarını artık kullanmaz.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l('Vazgeç')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l('Sil')),
          ),
        ],
      ),
    );
    if (yes == true) await McpServers.instance.remove(m.id);
  }

  Future<void> _edit(McpServerConfig? m) async {
    final got = await showDialog<McpServerConfig>(
      context: context,
      builder: (_) => _ServerDialog(server: m),
    );
    if (got == null) return;
    await McpServers.instance.put(got);
    unawaited(_probe(got));
  }

  Widget _section(
    String title,
    List<Widget> children, {
    Widget? action,
    String? note,
  }) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
            const Spacer(),
            ?action,
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              note,
              style: const TextStyle(fontSize: 12.5, color: _muted),
            ),
          ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  Widget _row(String title, String detail, Widget trailing) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        trailing,
      ],
    ),
  );

  Widget _switch(
    String title,
    String detail,
    bool value,
    ValueChanged<bool> onChanged,
  ) => _row(title, detail, Switch(value: value, onChanged: onChanged));

  Widget _badge(String text, bool good) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: good ? const Color(0x2216A34A) : const Color(0x22F59E0B),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: good ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
      ),
    ),
  );
}

/// A server added or changed: its id, name, command line, environment.
class _ServerDialog extends StatefulWidget {
  const _ServerDialog({this.server});
  final McpServerConfig? server;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _id = TextEditingController(text: widget.server?.id ?? '');
  late final _name = TextEditingController(text: widget.server?.name ?? '');
  late final _command = TextEditingController(
    text: widget.server == null
        ? ''
        : [
            widget.server!.command,
            ...widget.server!.args,
          ].map(_quote).join(' '),
  );
  late final _env = TextEditingController(
    text: [
      for (final e in (widget.server?.env ?? const {}).entries)
        '${e.key}=${e.value}',
    ].join('\n'),
  );
  late bool _approve = widget.server?.approve ?? true;
  String? _error;

  static String _quote(String a) =>
      a.isEmpty || a.contains(RegExp(r'''[\s"']''')) ? '"$a"' : a;

  /// A command line split as a shell would, quotes kept together.
  static List<String> split(String line) {
    final out = <String>[];
    final b = StringBuffer();
    String? q;
    var any = false;
    for (final ch in line.split('')) {
      if (q != null) {
        if (ch == q) {
          q = null;
        } else {
          b.write(ch);
        }
      } else if (ch == '"' || ch == "'") {
        q = ch;
        any = true;
      } else if (ch.trim().isEmpty) {
        if (b.isNotEmpty || any) out.add(b.toString());
        b.clear();
        any = false;
      } else {
        b.write(ch);
      }
    }
    if (b.isNotEmpty || any) out.add(b.toString());
    return out;
  }

  void _save() {
    final id = _id.text.trim().toLowerCase();
    final parts = split(_command.text.trim());
    if (!McpServerConfig.validId(id)) {
      return setState(
        () => _error = l(
          'Kısa ad küçük harfle başlamalı; yalnız a-z, 0-9 ve _ (2-24).',
        ),
      );
    }
    if (id == McpServers.folioId || id == McpServers.lifeosId) {
      return setState(() => _error = l('Bu ad LifeOS’a ayrılmış.'));
    }
    if (widget.server == null &&
        McpServers.instance.all.any((s) => s.id == id)) {
      return setState(() => _error = l('Bu adla bir sunucu var.'));
    }
    if (parts.isEmpty) return setState(() => _error = l('Komut boş.'));
    final env = <String, String>{};
    for (final l in _env.text.split('\n')) {
      final i = l.indexOf('=');
      if (i > 0) env[l.substring(0, i).trim()] = l.substring(i + 1).trim();
    }
    Navigator.pop(
      context,
      McpServerConfig(
        id: id,
        name: _name.text.trim().isEmpty ? id : _name.text.trim(),
        command: parts.first,
        args: parts.skip(1).toList(),
        env: env,
        on: widget.server?.on ?? true,
        approve: _approve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panel,
    title: Text(
      widget.server == null ? l('MCP sunucusu ekle') : l('Sunucuyu düzenle'),
    ),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _id,
            enabled: widget.server == null,
            decoration: InputDecoration(
              labelText: l('Kısa ad'),
              helperText: l('Araçların öneki olur: github → github_…'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l('Görünen ad')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _command,
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
            decoration: InputDecoration(
              labelText: l('Komut'),
              hintText: l(
                'npx -y @modelcontextprotocol/server-filesystem ~/Belgeler',
              ),
              helperText: l(
                'Standart giriş/çıkışla (stdio) konuşan bir MCP sunucusu.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _env,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
            decoration: InputDecoration(
              labelText: l('Ortam değişkenleri (isteğe bağlı)'),
              hintText: 'GITHUB_TOKEN=…',
              helperText: l(
                'Her satıra bir AD=değer. mcp.json dosyasında saklanır.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _approve,
            onChanged: (v) => setState(() => _approve = v),
            title: Text(l('Değişiklik yapan araçlar için onay iste')),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l('Vazgeç')),
      ),
      FilledButton(onPressed: _save, child: Text(l('Kaydet'))),
    ],
  );
}
