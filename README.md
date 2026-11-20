# Fedora için DaVinci Resolve Kurulumu

Fedora'ya **DaVinci Resolve**'u (ücretsiz veya Studio) tek komutla kuran betik.

Resolve resmi olarak yalnızca Rocky Linux'u destekler; Fedora'ya doğrudan kurulduğunda
kütüphane çakışmaları yüzünden genellikle açılmaz ya da her güncellemede bozulur. Bu betik
Resolve'u [davincibox](https://github.com/zelikos/davincibox) kapsayıcısının içine kurar.
Program normal bir uygulama gibi menüden açılır, ama sistemden yalıtılmış çalışır.

## Ne yapar?

1. **Ekran kartını kontrol eder.** NVIDIA kartı var ama sürücü kurulu değilse RPM Fusion'dan sürücüyü kurmayı önerir.
2. **Gerekli paketleri kurar:** `podman`, `distrobox`, `unzip`.
3. **Kurulum dosyasını bulur.** İndirilenler klasöründe yoksa **tarayıcıda Blackmagic indirme sayfasını açar**, ne yapman gerektiğini anlatır ve indirmenin bitmesini kendisi bekler.
4. **davincibox kapsayıcısını oluşturur.** NVIDIA varsa kartı kapsayıcıya bağlar.
5. **Resolve'u kapsayıcıya kurar** ve uygulama menüsüne kısayol ekler.
6. **Son ayarları yapar:** önbellek klasörü oluşturur ve kapsayıcının ekran kartını gördüğünü doğrular.

## Kullanım

```bash
git clone https://github.com/abdullahnil/fedora-davinci-resolve.git
cd fedora-davinci-resolve
./kur.sh
```

Kurulum dosyası zaten elindeyse yolunu verebilirsin:

```bash
./kur.sh ~/Downloads/DaVinci_Resolve_21.2_Linux.zip
```

`sudo` ile çalıştırma. Gerektiğinde şifreyi betik kendisi sorar.

## Kaldırma

```bash
./kaldir.sh
```

Kapsayıcıyı ve kısayolları siler. Resolve veritabanını ve indirilen imajı silmeden önce ayrıca sorar.

## Önemli: video biçimleri

Ücretsiz Resolve Linux'ta **H.264 / H.265 (HEVC) video** ve **AAC ses** açamaz. Telefon,
OBS ve kamera kayıtlarının çoğu bu biçimlerdedir: Resolve'a eklediğinde ya görüntü gelmez ya da ses gelmez.

Çözüm, videoları Resolve'un açabildiği bir biçime (AV1 + PCM ya da DNxHR) çevirmektir.
Bunun için **resolve-cevirici** projesini kullanabilirsin. Dosyaya sağ tıklayıp çevirmen yeterli.

## İlk açılışta önerilen ayarlar

| Ayar | Değer |
|---|---|
| Preferences → Memory and GPU → GPU processing mode | NVIDIA: **CUDA**, AMD: **OpenCL** |
| Preferences → Media Storage | `~/Videos/Resolve Önbellek` |

## Sorun giderme

| Belirti | Çözüm |
|---|---|
| Resolve açılmıyor (NVIDIA) | `nvidia-smi` çalışıyor mu kontrol et. Sürücü yeni kurulduysa yeniden başlat. |
| "GPU not supported" hatası | Kapsayıcıyı NVIDIA desteğiyle yeniden kurmak için `./kur.sh` çalıştır ve silip yeniden kurmayı seç. |
| Kurulum sırasında takıldı | Ctrl+C ile durdur, `./kur.sh` ile tekrar başlat. Mevcut kapsayıcıyı kullanmayı seçebilirsin. |

## Gereksinimler

- Fedora Workstation (40 ve üzeri ile denendi)
- NVIDIA (önerilen) ya da AMD ekran kartı
- ~10 GB boş disk alanı

## Lisans

MIT. DaVinci Resolve, Blackmagic Design'ın ürünüdür; bu proje Blackmagic Design ile ilişkili değildir
ve Resolve'u dağıtmaz, yalnızca resmi indirmeyi kurar.
