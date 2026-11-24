/// The voice's texts in English (conversation lines, errors).
const enSes = <String, String>{
  'LifeOS Yankı açık görünüyor ama yanıt vermiyor.':
      'LifeOS Yankı seems to be open but is not responding.',
  'Yapay zekâ kapalı.': 'AI is turned off.',
  'Ses bağlantısı koptu.': 'The voice connection dropped.',
  'Codex bulunamadı. Codex CLI’ı kurup terminalde `codex login` '
          'ile ChatGPT hesabınızla giriş yapın, ya da Ayarlar’dan bir Gemini '
          'anahtarı ekleyin.':
      'Codex was not found. Install the Codex CLI and sign in with your '
      'ChatGPT account by running `codex login` in a terminal, or add a '
      'Gemini key in Settings.',
  'Codex’e giriş yapılmamış: terminalde `codex login`. ({0})':
      'Not signed in to Codex: run `codex login` in a terminal. ({0})',
  'Codex sesi açılamadı: {0}': 'Could not start the Codex voice: {0}',
  'Soru gönderilemedi: {0}': 'Could not send the question: {0}',
  'İş uzadı; konuşma kapatıldı.':
      'The task took too long; the conversation was closed.',
  'Claude cevapladı ({0} sn)': 'Claude answered ({0} s)',
  'Ses: {0}': 'Voice: {0}',
  'Konuşma kapatıldı.': 'Conversation closed.',
  'Gemini anahtarı yok. Ayarlar’dan ücretli bir Gemini anahtarı girin.':
      'No Gemini key. Enter a paid Gemini key in Settings.',
  'Oturum yenilenemedi; maliyet artmasın diye konuşma kapandı.':
      'The session could not be renewed; the conversation was closed to '
      'keep costs down.',
  'bağlantı kapandı ({0})': 'connection closed ({0})',
  'bağlantı hatası: {0}': 'connection error: {0}',
};
