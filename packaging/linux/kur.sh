#!/usr/bin/env bash
# LifeOS Yankı'yı kurar.
#   ./kur.sh            → sistem geneli: /opt/lifeos-yanki, /usr/bin/lifeos-yanki (sudo ister)
#   ./kur.sh --kullanici → yalnız bu kullanıcı: ~/.local/opt/lifeos-yanki, ~/.local/bin
#   ./kur.sh --kaldir [--kullanici] → kaldırır
# Önce: flutter build linux --release
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
bundle="$root/build/linux/x64/release/bundle"
user=0; remove=0
for a in "$@"; do
  case "$a" in
    --kullanici) user=1 ;;
    --kaldir) remove=1 ;;
    *) echo "Bilinmeyen seçenek: $a" >&2; exit 2 ;;
  esac
done
if [ "$user" = 1 ]; then
  opt="$HOME/.local/opt/lifeos-yanki"; bin="$HOME/.local/bin"
  apps="$HOME/.local/share/applications"; icons="$HOME/.local/share/icons/hicolor"
  sudo=""
else
  opt="/opt/lifeos-yanki"; bin="/usr/bin"
  apps="/usr/share/applications"; icons="/usr/share/icons/hicolor"
  sudo="sudo"
fi
autostart="$HOME/.config/autostart/tr.com.lifeos.Yanki-autostart.desktop"
if [ "$remove" = 1 ]; then
  $sudo rm -rf "$opt"
  $sudo rm -f "$bin/lifeos-yanki" "$apps/tr.com.lifeos.Yanki.desktop" \
    "$icons/512x512/apps/tr.com.lifeos.Yanki.png"
  rm -f "$autostart"
  echo "LifeOS Yankı kaldırıldı. Ayarlar ~/.local/share/tr.com.lifeos.Yanki içinde duruyor."
  exit 0
fi
[ -x "$bundle/lifeos-yanki" ] || { echo "Önce derleyin: flutter build linux --release" >&2; exit 1; }
$sudo mkdir -p "$opt" "$bin" "$apps" "$icons/512x512/apps"
$sudo rm -rf "$opt"/*
$sudo cp -a "$bundle"/. "$opt"/
$sudo ln -sf "$opt/lifeos-yanki" "$bin/lifeos-yanki"
$sudo install -m644 "$here/tr.com.lifeos.Yanki.desktop" "$apps/"
$sudo install -m644 "$root/assets/branding/lifeos_yanki.png" \
  "$icons/512x512/apps/tr.com.lifeos.Yanki.png"
mkdir -p "$(dirname "$autostart")"
install -m644 "$here/tr.com.lifeos.Yanki-autostart.desktop" "$autostart"
command -v update-desktop-database >/dev/null && $sudo update-desktop-database "$apps" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null && $sudo gtk-update-icon-cache -q "$icons" 2>/dev/null || true
echo "LifeOS Yankı kuruldu: $bin/lifeos-yanki"
echo "Oturum açılınca arka planda dinler (sesle açma Ayarlar'dan açılınca)."
