#!/usr/bin/env bash
# LifeOS Yankı'nın sürüm paketini yapar: dist/LifeOS-Yanki-<sürüm>-Linux-x64.tar.gz
# İçinde: LifeOS-Yanki/ (Flutter paketi) ve LifeOS-Yanki/kurulum/ (masaüstü girdileri, simge, kur.sh).
# PKGBUILD (LifeOSLinux/packaging/lifeos-yanki) bu dosyayı GitHub sürümünden indirir.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
ver="$(sed -n 's/^version: \([0-9.]*\).*/\1/p' pubspec.yaml)"
flutter build linux --release
out="$root/dist"; stage="$out/LifeOS-Yanki"
rm -rf "$stage"; mkdir -p "$stage/kurulum"
cp -a build/linux/x64/release/bundle/. "$stage/"
cp packaging/linux/*.desktop "$stage/kurulum/"
cp assets/branding/lifeos_yanki.png "$stage/kurulum/tr.com.lifeos.Yanki.png"
cp LICENSE README.md "$stage/"
tar -C "$out" -czf "$out/LifeOS-Yanki-$ver-Linux-x64.tar.gz" LifeOS-Yanki
( cd "$out" && sha256sum "LifeOS-Yanki-$ver-Linux-x64.tar.gz" > "LifeOS-Yanki-$ver-Linux-x64.tar.gz.sha256" )
rm -rf "$stage"
cat "$out/LifeOS-Yanki-$ver-Linux-x64.tar.gz.sha256"
