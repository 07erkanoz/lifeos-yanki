# LifeOS Yankı

LifeOS'un sesli yapay zekâ ajanı. Yalnız Linux'ta çalışır ve LifeOS Folio'dan bağımsızdır; Folio kuruluysa onun araçlarını MCP üzerinden kullanır.

- **Ses:** Codex (ChatGPT aboneliği, WebRTC realtime, Türkçe) ana sestir. Codex yoksa Gemini Live devreye girer.
- **Ağır işler:** Claude Code (`claude -p`) yapar ve açık MCP sunucularının yalnız okuyan araçlarını kullanır.
- **Uyandırma:** "Merhaba Yankı", "Yankı açıl" ya da "Ajan açıl" denince açılır. Tanıma Vosk ile bu bilgisayarda yapılır; hiçbir ses dışarı gitmez.
- **MCP:** Yerleşik iki sunucu var: LifeOS Folio (`lifeos_folio --mcp --dis`) ve LifeOS Linux (`lifeos mcp sun`). Ayarlar › MCP sunucuları'ndan stdio ile konuşan herhangi bir sunucu eklenebilir. Değişiklik yapan araçlar çalışmadan önce ekranda onay ister.
- **Tepsi:** Pencere kapanınca sistem tepsisinde durur (KDE paneli; GNOME'da AppIndicator eklentisiyle). Simgeye tıklayınca açılır; menüsünden yüzen küre, "Merhaba Yankı" ile açma, ayarlar ve çıkış seçilir. Ayarlar › Masaüstü'nden kapatılabilir; oturum açılınca başlaması da oradan açılıp kapanır.
- **Sesle kapatma:** "Kapan", "görüşürüz", "teşekkürler" denince konuşma biter ve pencere de kapanır (Ayarlar › Ses › Sesle kapat).
- **Görünüm:** Tam ekranda üç seçenek var: *Yankı* (dalga, enerji küresi, ağ), *Ağ* (geodezik küre) ve *Dalga* (ışık halkası). Hepsi sesin gerçek seviye geçmişiyle oynar; arka plan bir GLSL shader'ıdır (`shaders/yanki_nebula.frag`). Küçültünce masaüstünde her zaman üstte duran, sürüklenebilen bir küre olur.

## Derleme ve kurulum

```bash
flutter build linux --release
```

```bash
packaging/linux/kur.sh --kullanici
```

`--kullanici` ile `~/.local` altına kurulur. Sistem geneli için seçeneksiz çalıştırın: `/opt/lifeos-yanki` ve `/usr/bin/lifeos-yanki` olarak kurulur, sudo ister. Kaldırmak için `--kaldir` kullanın.

## Komutlar

| Komut | Ne yapar |
|---|---|
| `lifeos-yanki` | Tam ekranı açar (açıksa öne getirir) |
| `lifeos-yanki --arka` | Pencere açmadan uyandırma sözünü dinler |
| `lifeos-yanki --kapan` | Açık olan Yankı'yı kapatır |

## Veriler

`~/.local/share/tr.com.lifeos.Yanki/`

- `ses.json`: ses ayarları
- `mcp.json`: MCP sunucuları
- `yanki/`: kilit dosyası

Gemini anahtarı dosyada değil, masaüstünün anahtarlığında (`secret-tool`) saklanır.

## Testler

```bash
flutter test
```

```bash
YANKI_MCP=1 flutter test test/mcp_probe_test.dart
```

```bash
YANKI_SHOTS=/tmp/yanki flutter test test/figures_render_test.dart
```

İkincisi bu bilgisayardaki gerçek MCP sunucularıyla konuşur. Üçüncüsü görünümleri PNG olarak çizer.

## Kaynak

Ses katmanı, LifeOS Folio'nun Folio Ajan'ından (`evrak convert/lib/services/voice`) ayrıldı. Folio'ya özel UYAP/UETS PIN köprüsü, dava oturumu ve Folio'nun iç yapay zekâ katmanı çıkarıldı; Folio'nun yerine geçen tek şey onun MCP sunucusudur.
