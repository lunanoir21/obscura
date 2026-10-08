# obscura

Hyprland üzerinde OBS Studio için ince bir kontrol katmanı. Quickshell çubuğunda küçük bir düğme; kayıt sırasında hapa genişler, ayrıntılar için bir panel ve her yerden çalışan bir kısayol sunar.

obscura, zaten kurulu olan OBS'i yerleşik WebSocket sunucusu (obs-websocket v5) üzerinden sürer. Kendisi kodlama yapmaz; sahne, kaynak ve kodlayıcı ayarların OBS'te kalır.

> Durum: erken aşama. Komut satırı çalışıyor; çubuk widget'ı ve panel sırada.

## Tasarım hedefleri

- **Boştayken sıfır maliyet.** Yoklama döngüsü yok; istemci soket üzerinde bekler.
- **Duruma yalan söylemez.** Kayıt noktası yalnız OBS "başladı" dediğinde yanar.
- **Hızlı hata.** OBS kapalıysa komut milisaniyeler içinde net bir mesajla döner.
- **Sıfır yapılandırma.** Port ve parola OBS'in kendi ayarından okunur, geri yazılmaz.

## Kullanım

```sh
obscura doctor   # OBS ve WebSocket sunucusunu denetle
obscura toggle   # başlat, ya da durdur ve kaydedilen dosyayı yaz
obscura status   # kayıt durumu JSON olarak
obscura pause
```

Önce OBS'te sunucuyu aç: Tools > WebSocket Server Settings.

## Lisans

MIT
