#!/bin/bash
# Fedora'ya DaVinci Resolve (ücretsiz veya Studio) kurar.
#
# Resolve resmi olarak yalnızca Rocky Linux'u destekler. Bu betik Resolve'u
# davincibox (https://github.com/zelikos/davincibox) kapsayıcısının içine kurar;
# böylece Fedora'nın sistem kütüphaneleriyle çakışma olmaz ve güncellemelerde bozulmaz.
#
# Kullanım:
#   ./kur.sh                    # Kurulum dosyasını İndirilenler'de arar, yoksa tarayıcıyı açar
#   ./kur.sh DOSYA.zip|DOSYA.run  # Belirli bir kurulum dosyasıyla kurar
#   ./kur.sh -h                 # Yardım

set -euo pipefail

KAPSAYICI="davincibox"
IMAJ="ghcr.io/zelikos/davincibox:latest"
INDIRME_SAYFASI="https://www.blackmagicdesign.com/products/davinciresolve"
INDIRILENLER="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"

# ---------- yardımcılar ----------
if [ -t 1 ]; then
    K=$'\e[1;31m'; Y=$'\e[1;32m'; S=$'\e[1;33m'; M=$'\e[1;34m'; N=$'\e[0m'
else
    K=; Y=; S=; M=; N=
fi
adim()  { echo; echo "${M}==>${N} $*"; }
bilgi() { echo "    $*"; }
uyari() { echo "${S}UYARI:${N} $*" >&2; }
hata()  { echo "${K}HATA:${N} $*" >&2; exit 1; }
sor()   { # sor "Soru" -> E/h, varsayılan Evet
    local c; read -r -p "    $1 [E/h] " c </dev/tty || c=
    [[ ! "$c" =~ ^[hHnN] ]]
}

yardim() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

GECICI=""
temizle() { [ -n "$GECICI" ] && rm -rf "$GECICI"; }
trap temizle EXIT

# ---------- 0. ön kontroller ----------
KURULUM_DOSYASI=""
case "${1:-}" in
    -h|--help) yardim ;;
    "") ;;
    *)  [ -f "$1" ] || hata "Dosya bulunamadı: $1"
        KURULUM_DOSYASI="$(readlink -f "$1")" ;;
esac

[ "$EUID" -eq 0 ] && hata "Bu betiği sudo ile değil, normal kullanıcı olarak çalıştır. Gerektiğinde şifre sorulur."
grep -q '^ID=fedora' /etc/os-release 2>/dev/null || uyari "Bu sistem Fedora görünmüyor; yine de devam ediliyor."

echo "${Y}DaVinci Resolve — Fedora kurulumu${N}"

# ---------- 1. ekran kartı ----------
adim "1/6 Ekran kartı kontrol ediliyor"
NVIDIA=false
AMD=false
if lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qi nvidia; then
    NVIDIA=true
    if nvidia-smi >/dev/null 2>&1; then
        bilgi "NVIDIA sürücüsü çalışıyor: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1)"
    else
        uyari "NVIDIA kartı var ama sürücü çalışmıyor. Resolve için NVIDIA sürücüsü şart."
        if sor "RPM Fusion deposunu ekleyip NVIDIA sürücüsünü kurayım mı?"; then
            sudo dnf install -y \
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
            sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
            echo
            echo "${S}Sürücü derleniyor. 5 dakika kadar bekleyip bilgisayarı yeniden başlat,${N}"
            echo "${S}sonra bu betiği tekrar çalıştır.${N}"
            echo "(Güvenli Önyükleme açıksa yeniden başlatırken MOK anahtarını kaydetmen istenebilir.)"
            exit 0
        else
            hata "NVIDIA sürücüsü olmadan devam edilemiyor."
        fi
    fi
elif lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qiE 'amd|ati'; then
    AMD=true
    bilgi "AMD ekran kartı bulundu (OpenCL / ROCm ile çalışır)."
else
    uyari "NVIDIA veya AMD ekran kartı bulunamadı. Resolve yalnızca Intel grafikle çok yavaş çalışabilir."
fi

# ---------- 2. gerekli paketler ----------
adim "2/6 Gerekli paketler (podman, distrobox) kontrol ediliyor"
eksik=()
for p in podman distrobox unzip; do command -v "$p" >/dev/null || eksik+=("$p"); done
if [ ${#eksik[@]} -gt 0 ]; then
    bilgi "Kuruluyor: ${eksik[*]}"
    sudo dnf install -y "${eksik[@]}"
else
    bilgi "Hepsi kurulu."
fi

# ---------- 3. kurulum dosyası ----------
adim "3/6 DaVinci Resolve kurulum dosyası aranıyor"
bul() {
    find "$INDIRILENLER" -maxdepth 1 -type f \
        \( -iname 'DaVinci_Resolve*Linux*.zip' -o -iname 'DaVinci_Resolve*Linux*.run' \) \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
}
if [ -z "$KURULUM_DOSYASI" ]; then
    KURULUM_DOSYASI="$(bul)"
fi
if [ -z "$KURULUM_DOSYASI" ]; then
    bilgi "İndirilenler klasöründe bulunamadı. Tarayıcıda indirme sayfası açılıyor..."
    echo
    echo "    ${Y}Yapman gereken:${N}"
    echo "      1. Sayfada \"Download\" düğmesine bas."
    echo "      2. \"DaVinci Resolve\" (ücretsiz) altında ${Y}Linux${N}'u seç."
    echo "      3. Formu doldur (ya da \"Download only\" bağlantısını kullan)."
    echo "      4. Dosyayı ${Y}$INDIRILENLER${N} klasörüne kaydet."
    echo
    xdg-open "$INDIRME_SAYFASI" >/dev/null 2>&1 || bilgi "Tarayıcı açılamadı, adresi elle aç: $INDIRME_SAYFASI"
    bilgi "İndirmenin bitmesi bekleniyor (iptal için Ctrl+C)..."
    while :; do
        KURULUM_DOSYASI="$(bul)"
        # İndirme sürüyorsa (.crdownload / .part) ya da boyut hâlâ değişiyorsa bekle
        if [ -n "$KURULUM_DOSYASI" ] && \
           ! ls "$INDIRILENLER"/*.crdownload "$INDIRILENLER"/*.part >/dev/null 2>&1; then
            b1=$(stat -c %s "$KURULUM_DOSYASI"); sleep 3; b2=$(stat -c %s "$KURULUM_DOSYASI")
            [ "$b1" = "$b2" ] && break
        fi
        sleep 3
    done
fi
bilgi "Bulundu: $KURULUM_DOSYASI"

GECICI="$(mktemp -d "$HOME/.cache/resolve-kurulum.XXXXXX")"
RUN="$KURULUM_DOSYASI"
if [[ "$KURULUM_DOSYASI" == *.zip ]]; then
    bilgi "Zip açılıyor..."
    unzip -q -o "$KURULUM_DOSYASI" -d "$GECICI/zip"
    RUN="$(find "$GECICI/zip" -name '*.run' | head -1)"
    [ -n "$RUN" ] || hata "Zip içinde .run dosyası yok."
fi
chmod +x "$RUN"

# ---------- 4. kapsayıcı ----------
adim "4/6 davincibox kapsayıcısı hazırlanıyor"
if podman container exists "$KAPSAYICI" 2>/dev/null; then
    uyari "\"$KAPSAYICI\" adında bir kapsayıcı zaten var."
    if sor "Silip temiz kurulum yapayım mı? (Hayır dersen mevcut kapsayıcı kullanılır)"; then
        distrobox enter "$KAPSAYICI" -- add-davinci-launcher remove >/dev/null 2>&1 || true
        distrobox rm -f "$KAPSAYICI"
    fi
fi
if ! podman container exists "$KAPSAYICI" 2>/dev/null; then
    bilgi "İmaj indiriliyor (birkaç GB, ilk seferde biraz sürer)..."
    podman pull "$IMAJ"
    ek=()
    $NVIDIA && ek+=(--nvidia)
    distrobox create -Y -i "$IMAJ" -n "$KAPSAYICI" "${ek[@]}"
fi
bilgi "Kapsayıcı ilk kez başlatılıyor..."
distrobox enter "$KAPSAYICI" -- true

# ---------- 5. Resolve kurulumu ----------
adim "5/6 DaVinci Resolve kuruluyor (birkaç dakika sürer)"
bilgi "Kurulum dosyası açılıyor..."
( cd "$GECICI" && "$RUN" --appimage-extract >/dev/null )
[ -x "$GECICI/squashfs-root/AppRun" ] || hata "Kurulum dosyası açılamadı."
# setup-davinci sonunda "menüye kısayol eklensin mi?" diye soruyor: Evet.
( cd "$GECICI" && echo Y | distrobox enter "$KAPSAYICI" -- setup-davinci squashfs-root/AppRun distrobox )
distrobox enter "$KAPSAYICI" -- test -x /opt/resolve/bin/resolve || hata "Resolve kurulamadı, yukarıdaki çıktıya bak."

# ---------- 6. son ayarlar ----------
adim "6/6 Son ayarlar"
if $AMD; then
    # davincibox, AMD'de OpenCL'i (rusticl) yalnızca "run-davinci -c" ile açıyor
    for f in "$HOME/.local/share/applications/DaVinciResolve.desktop" \
             "$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")/com.blackmagicdesign.resolve.desktop"; do
        [ -f "$f" ] && sed -i 's#/usr/bin/run-davinci /opt/resolve#/usr/bin/run-davinci -c /opt/resolve#' "$f"
    done
    bilgi "AMD için OpenCL (rusticl) kısayollarda açıldı."
fi
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
mkdir -p "$HOME/Videos/Resolve Önbellek"
bilgi "Önbellek klasörü: ~/Videos/Resolve Önbellek"
if $NVIDIA; then
    gpu="$(distrobox enter "$KAPSAYICI" -- nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | tail -1 || true)"
    [ -n "$gpu" ] && bilgi "Kapsayıcı ekran kartını görüyor: $gpu"
fi

echo
echo "${Y}Kurulum tamamlandı!${N}"
cat <<EOF

  DaVinci Resolve uygulama menüsünde. İlk açılışta:
    • Preferences → Memory and GPU → GPU processing mode: $($NVIDIA && echo CUDA || echo OpenCL)
    • Preferences → Media Storage → "~/Videos/Resolve Önbellek" klasörünü ekle

  ${S}Önemli:${N} Ücretsiz Resolve Linux'ta H.264 / H.265 videoları ve AAC sesi açamaz
  (telefon ve OBS kayıtlarının çoğu böyledir). Bunları önce çevirmen gerekir;
  bunun için "resolve-cevirici" projesini kullanabilirsin.

  Kaldırmak için: ./kaldir.sh
EOF
