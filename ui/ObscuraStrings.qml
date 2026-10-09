pragma Singleton

import QtQuick
import Quickshell

// Every word the widget shows, in English and Turkish.
// The language comes from the widget settings (Look tab): auto, en or tr.
// "auto" follows the system language (LANG); anything but Turkish gets English.
Singleton {
    id: root

    readonly property string setting: ObscuraStore.cfg.language || "auto"
    readonly property string lang: setting === "auto" ? ((Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").toLowerCase().indexOf("tr") === 0 ? "tr" : "en") : setting

    // t("key") or t("key", a, b): %1, %2 are replaced.
    function t(key, a, b) {
        const row = dict[key];
        let s = row ? (row[root.lang] || row.en) : key;
        if (a !== undefined)
            s = s.replace("%1", a);
        if (b !== undefined)
            s = s.replace("%2", b);
        return s;
    }

    readonly property var dict: ({
            "pill.record": { en: "Record", tr: "Kayıt" },
            "pill.saved": { en: "Saved", tr: "Kaydedildi" },
            "pill.auth": { en: "Password needed", tr: "Parola gerekli" },
            "pill.opening": { en: "Opening OBS…", tr: "OBS açılıyor…" },
            "pill.serverOff": { en: "OBS server is off", tr: "OBS sunucusu kapalı" },

            "tab.control": { en: "Control", tr: "Kontrol" },
            "tab.record": { en: "Recording", tr: "Kayıt" },
            "tab.look": { en: "Look", tr: "Görünüm" },
            "conn.ok": { en: "OBS · connected", tr: "OBS · bağlı" },
            "conn.serverOff": { en: "server off", tr: "sunucu kapalı" },
            "conn.auth": { en: "password needed", tr: "parola gerekli" },
            "conn.closed": { en: "OBS closed", tr: "OBS kapalı" },

            "st.recording": { en: "Recording", tr: "Kaydediliyor" },
            "st.paused": { en: "Paused", tr: "Duraklatıldı" },
            "st.ready": { en: "Ready", tr: "Hazır" },
            "st.notConnected": { en: "Not connected", tr: "Bağlı değil" },
            "btn.start": { en: "Start recording", tr: "Kaydı başlat" },
            "btn.openObs": { en: "Open OBS", tr: "OBS'i aç" },
            "btn.obsSetup": { en: "OBS needs setup", tr: "OBS ayarı gerekli" },
            "btn.resume": { en: "Resume", tr: "Devam" },
            "btn.pause": { en: "Pause", tr: "Duraklat" },
            "btn.stop": { en: "Stop", tr: "Durdur" },
            "btn.shot": { en: "Shot", tr: "Ekran" },
            "btn.folder": { en: "Folder", tr: "Klasör" },
            "btn.choose": { en: "Choose", tr: "Seç" },
            "btn.cancel": { en: "Cancel", tr: "İptal" },
            "scene": { en: "Scene", tr: "Sahne" },
            "sources": { en: "Audio sources", tr: "Ses kaynakları" },
            "src.none": { en: "No audio sources in OBS.", tr: "OBS'te ses kaynağı yok." },
            "src.later": { en: "Shows up once OBS connects.", tr: "OBS bağlanınca burada görünür." },
            "replay.save": { en: "Save last %1 s", tr: "Son %1 sn'yi kaydet" },
            "replay.off": { en: "Replay off", tr: "Replay kapalı" },

            "rec.folder": { en: "Recording folder", tr: "Kayıt klasörü" },
            "rec.name": { en: "File name", tr: "Dosya adı" },
            "rec.next": { en: "Next file: %1", tr: "Sonraki dosya: %1" },
            "rec.exists": { en: "A file with this name already exists; OBS adds (1) to the new one.", tr: "Bu adla bir dosya zaten var; OBS yenisinin sonuna (1) ekleyerek kaydeder." },
            "rec.overwrite": { en: "A file with this name already exists and will be overwritten.", tr: "Bu adla bir dosya zaten var ve üzerine yazılacak." },
            "rec.tokens": { en: "%CCYY year  %MM month  %DD day  %hh hour  %mm minute  %ss second", tr: "%CCYY yıl  %MM ay  %DD gün  %hh saat  %mm dakika  %ss saniye" },
            "rec.fps": { en: "Frame rate", tr: "Kare hızı" },
            "rec.fpsHint": { en: "Your screen is %1 Hz; higher frame rates repeat the same frame, so they can't be chosen.", tr: "Ekranın %1 Hz; bundan yüksek kare hızı aynı kareyi tekrarlar, bu yüzden seçilemiyor." },
            "rec.res": { en: "Resolution", tr: "Çözünürlük" },
            "opt.native": { en: "Native", tr: "Yerel" },
            "rec.format": { en: "Format", tr: "Biçim" },
            "rec.mkvHint": { en: "MKV keeps the file even if the recording is cut short.", tr: "MKV kayıt yarıda kesilse bile dosyayı korur." },
            "rec.replay": { en: "Replay buffer", tr: "Replay buffer" },
            "rec.on": { en: "On", tr: "Açık" },
            "rec.off": { en: "Off", tr: "Kapalı" },
            "rec.replayDisabled": { en: "Not enabled in OBS settings", tr: "OBS ayarlarında etkin değil" },
            "opt.seconds": { en: "%1 s", tr: "%1 sn" },
            "rec.locked": { en: "While recording, frame rate, resolution and format are locked; folder and name apply from the next recording.", tr: "Kayıt sürerken kare hızı, çözünürlük ve biçim kilitli; klasör ve ad sonraki kayıttan geçerli olur." },

            "browse.empty": { en: "No subfolders.", tr: "Alt klasör yok." },
            "browse.readonly": { en: "Not writable", tr: "Yazılamaz" },
            "browse.use": { en: "Use this folder", tr: "Bu klasörü seç" },

            "look.timerFont": { en: "Timer font", tr: "Süre yazısı" },
            "look.size": { en: "Font size", tr: "Yazı boyutu" },
            "look.after": { en: "When a recording ends", tr: "Kayıt bitince" },
            "look.notify": { en: "Show a notification", tr: "Bildirim göster" },
            "look.copy": { en: "Copy the file path to the clipboard", tr: "Dosya yolunu panoya kopyala" },
            "look.conn": { en: "OBS connection", tr: "OBS bağlantısı" },
            "look.portUsing": { en: "Using port %1.", tr: "Port %1 kullanılıyor." },
            "look.portAuto": { en: "Empty: OBS's own setting is used (WebSocket Server Settings).", tr: "Boş: OBS'in kendi ayarı kullanılır (WebSocket Server Settings)." },
            "look.button": { en: "Button style", tr: "Düğme biçimi" },
            "opt.circle": { en: "Circle", tr: "Daire" },
            "opt.pill": { en: "Pill", tr: "Hap" },
            "opt.icon": { en: "Icon only", tr: "Yalnız simge" },
            "look.language": { en: "Language", tr: "Dil" },
            "opt.auto": { en: "Auto", tr: "Otomatik" },

            "pick.title": { en: "What should be shared?", tr: "Ne paylaşılsın?" },
            "pick.sub": { en: "An app wants to see your screen. Pick one.", tr: "Bir uygulama ekranını görmek istiyor. Birini seç." },
            "pick.screens": { en: "Screens", tr: "Ekranlar" },
            "pick.windows": { en: "Windows (%1)", tr: "Pencereler (%1)" },
            "pick.fullscreen": { en: "Whole screen · %1", tr: "Tüm ekran · %1" },
            "pick.noWindows": { en: "No open windows.", tr: "Açık pencere yok." },
            "pick.remember": { en: "Remember this choice (don't ask again)", tr: "Bu seçimi hatırla (bir daha sorma)" }
        })
}
