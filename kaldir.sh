#!/bin/bash
# kur.sh ile kurulan DaVinci Resolve'u kaldırır.
# Projelerin ve medya dosyaların silinmez; Resolve veritabanını silmek isteyip
# istemediğin ayrıca sorulur.
set -euo pipefail
KAPSAYICI="davincibox"

sor() { local c; read -r -p "$1 [e/H] " c </dev/tty || c=; [[ "$c" =~ ^[eEyY] ]]; }

sor "DaVinci Resolve ve \"$KAPSAYICI\" kapsayıcısı kaldırılsın mı?" || { echo "Vazgeçildi."; exit 0; }

if podman container exists "$KAPSAYICI" 2>/dev/null; then
    echo "==> Menü kısayolları kaldırılıyor"
    distrobox enter "$KAPSAYICI" -- add-davinci-launcher remove 2>/dev/null || true
    echo "==> Kapsayıcı siliniyor"
    distrobox rm -f "$KAPSAYICI"
else
    echo "\"$KAPSAYICI\" kapsayıcısı bulunamadı, yalnızca kısayollar temizleniyor."
fi
rm -f "$HOME"/.local/share/applications/{DaVinci*,blackmagicraw*,davincibox*}.desktop
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

if [ -d "$HOME/.local/share/DaVinciResolve" ] && \
   sor "Resolve veritabanı ve ayarları (~/.local/share/DaVinciResolve) da silinsin mi? Projeler kaybolur!"; then
    rm -rf "$HOME/.local/share/DaVinciResolve"
fi

if sor "İndirilen davincibox imajı da silinsin mi? (birkaç GB yer açar)"; then
    podman rmi ghcr.io/zelikos/davincibox:latest 2>/dev/null || true
fi
echo "Kaldırıldı."
