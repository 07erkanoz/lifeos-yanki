import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../platform/app_directories.dart';

import '../ai/ai_assistant.dart';
import 'live_conversation.dart';

/// Folio Ajan's voice, as this computer's lawyer set it: off until they
/// turn it on. Kept on this computer only (a microphone and a loudspeaker
/// are the computer's, not the lawyer's other devices').
class VoiceSettings {
  const VoiceSettings({
    this.on = false,
    this.headphones = false,
    this.voice = '',
    this.codexVoice = '',
    this.codexModel = '',
    this.codexEffort = 'low',
    this.handOn = true,
    this.wake = false,
    this.skin = 'yanki',
    this.city = '',
    this.tray = true,
    this.voiceClose = true,
    this.language = 'sistem',
  });

  /// Yankı's language: 'sistem' (the computer's), 'tr' or 'en'.
  final String language;

  /// Yankı stays in the system tray when its window closes, even with the
  /// wake word off; its menu opens it again.
  final bool tray;

  /// "Kapan", "görüşürüz"…: the window goes with the conversation (to the
  /// tray, or listening for the wake word).
  final bool voiceClose;

  /// The person's city, for the weather ("Kadıköy/İstanbul").
  final String city;

  /// How Folio Ajan's full screen looks: kure, reaktor, hologram, aura,
  /// kehribar (22 Kasım 2026: the lawyer wanted to choose).
  final String skin;

  /// "Ajan açıl" opens Folio Ajan: listened for on this computer (Vosk),
  /// nothing leaves it.
  final bool wake;

  /// Codex's agent may hand heavy work to Folio's AI program (Claude Code,
  /// as the AI settings say); off, Codex does everything itself.
  final bool handOn;

  /// Codex's voice, model and reasoning; Codex's own when empty.
  final String codexVoice, codexModel, codexEffort;

  final bool on;

  /// Live may be spoken over: nothing comes back through the microphone.
  final bool headphones;

  /// One of Gemini's ready voices; Live's own when empty.
  final String voice;

  static VoiceSettings fromJson(Object? json) => json is Map
      ? VoiceSettings(
          on: json['acik'] == true,
          headphones: json['kulaklik'] == true,
          voice: '${json['ses'] ?? ''}',
          codexVoice: '${json['codex_ses'] ?? ''}',
          codexModel: '${json['codex_model'] ?? ''}',
          codexEffort: '${json['codex_dusunme'] ?? 'low'}',
          handOn: json['agir_isler_programa'] != false,
          wake: json['sesle_ac'] == true,
          skin: '${json['gorunum'] ?? 'yanki'}',
          city: '${json['sehir'] ?? ''}',
          tray: json['tepside'] != false,
          voiceClose: json['sesle_kapat'] != false,
          language: '${json['dil'] ?? 'sistem'}',
        )
      : const VoiceSettings();

  Map<String, Object?> toJson() => {
    'acik': on,
    'kulaklik': headphones,
    'ses': voice,
    'codex_ses': codexVoice,
    'codex_model': codexModel,
    'codex_dusunme': codexEffort,
    'agir_isler_programa': handOn,
    'sesle_ac': wake,
    'gorunum': skin,
    'sehir': city,
    'tepside': tray,
    'sesle_kapat': voiceClose,
    'dil': language,
  };

  VoiceSettings copyWith({
    bool? on,
    bool? headphones,
    String? voice,
    String? codexVoice,
    String? codexModel,
    String? codexEffort,
    bool? handOn,
    bool? wake,
    String? skin,
    String? city,
    bool? tray,
    bool? voiceClose,
    String? language,
  }) => VoiceSettings(
    on: on ?? this.on,
    headphones: headphones ?? this.headphones,
    voice: voice ?? this.voice,
    codexVoice: codexVoice ?? this.codexVoice,
    codexModel: codexModel ?? this.codexModel,
    codexEffort: codexEffort ?? this.codexEffort,
    handOn: handOn ?? this.handOn,
    wake: wake ?? this.wake,
    skin: skin ?? this.skin,
    city: city ?? this.city,
    tray: tray ?? this.tray,
    voiceClose: voiceClose ?? this.voiceClose,
    language: language ?? this.language,
  );

  static Future<File> Function() file = () async =>
      File(p.join((await supportDirectory()).path, 'ses.json'));

  static Future<VoiceSettings> load() async {
    try {
      return fromJson(jsonDecode(await (await file()).readAsString()));
    } catch (_) {
      return const VoiceSettings();
    }
  }

  Future<void> save() async {
    final f = await file();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(toJson()), flush: true);
  }
}

/// What Live hands on, asked of the lawyer's AI program with Folio's tools,
/// under the same switches as every other AI feature: off, or with no
/// consent, nothing is asked.
Future<String> askFolio(
  String question, {
  void Function(AiEvent event)? onEvent,
  AiProvider? only,
  AiThread? thread,
}) async {
  final settings = await AiSettings.load();
  if (!settings.enabled || !settings.consented) {
    return 'Yapay zekâ kapalı.';
  }
  final provider = only ?? await AiRelay.usable(settings);
  if (provider == null) {
    return 'Claude Code kurulu ya da oturum açık değil; bu işi kendin yap.';
  }
  return AiAssistant.ask(
    provider,
    spokenPrompt(question, DateTime.now()),
    tier: AiTier.normal,
    onEvent: onEvent,
    thread: thread,
  );
}

/// The question the voice hands on, as the program is asked it: today and
/// the two weeks ahead named, for "bu hafta" and "önümüzdeki günler" to be
/// read from the agenda and not guessed; the lawyer's own words above the
/// voice's retelling of them; an answer to be read aloud as it is.
String spokenPrompt(String question, DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  String iso(DateTime d) => d.toIso8601String().substring(0, 10);
  final until = day.add(const Duration(days: 13));
  return 'Bu soru sesli soruldu; cevabın avukata olduğu gibi sesli '
      'okunacak. Türkçe, kısa ve net cevap ver, “siz” diye hitap et; '
      'biçimlendirme, tablo ya da madde işareti kullanma. Bugün '
      '${ajanToday(now)}. Ajandaya bakarken bugünden ${iso(until)} gününe '
      'kadar iki haftayı oku (${iso(day)} – ${iso(until)}). Avukatın kendi '
      'sözü esastır: içinde yanlış bir varsayım varsa (gün, tarih, mahkeme) '
      'açıkça düzelt, örneğin “Salı değil, 27 Kasım Cuma”.\n\n$question';
}

/// Claude on this computer, for Folio Ajan's heavy work: Claude Code if it
/// is signed in, else Claude's API with a key; none, neither is.
Future<AiProvider?> usableClaude() async {
  try {
    final usable = {
      for (final s in await AiAssistant.statuses())
        if (s.usable) s.provider,
    };
    return usable.contains(AiProvider.claude) ? AiProvider.claude : null;
  } catch (_) {
    return null;
  }
}
