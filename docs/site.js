(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const store = {
    get: k => { try { return localStorage.getItem(k); } catch { return null; } },
    set: (k, v) => { try { localStorage.setItem(k, v); } catch {} },
  };

  /* ── theme ── */
  const root = document.documentElement;
  const savedTheme = store.get("obscura-theme");
  if (savedTheme) root.dataset.theme = savedTheme;
  $("#theme").addEventListener("click", () => {
    root.dataset.theme = root.dataset.theme === "dark" ? "light" : "dark";
    store.set("obscura-theme", root.dataset.theme);
    shotsFor(root.dataset.theme, root.lang);
  });

  /* ── screenshots follow the theme and the language ── */
  function shotsFor(theme, lang) {
    $$("img[data-shot], .gallery img").forEach(img => {
      if (!img.dataset.shot) img.dataset.shot = (img.getAttribute("src").match(/([a-z-]+)\.png$/) || [])[1] || "";
      if (!img.dataset.shot) return;
      img.src = "screenshots/" + (lang === "tr" ? "tr/" : "") + (theme === "light" ? "light/" : "") + img.dataset.shot + ".png";
    });
  }

  /* ── the redrawn panel and picker: Turkish in the markup, English by default ── */
  const MOCK = {
    "Kontrol": "Control", "Kayıt": "Recording", "Görünüm": "Look", "OBS · bağlı": "OBS · connected", "Hazır": "Ready",
    "Kaydı başlat": "Start recording", "Sahne": "Scene", "Ses kaynakları": "Audio sources", "Masaüstü Ses": "Desktop Audio",
    "Son 30 sn'yi kaydet": "Save last 30 s", "Ekran": "Shot", "Klasör": "Folder", "Kayıt klasörü": "Recording folder", "Seç": "Choose",
    "Dosya adı": "File name", "Sonraki dosya: 2026-10-09 22-20-14.mkv": "Next file: 2026-10-09 22-20-14.mkv",
    "Bu adla bir dosya zaten var; OBS yenisinin sonuna (1) ekleyerek kaydeder.": "A file with this name already exists; OBS adds (1) to the new one.",
    "Kare hızı": "Frame rate", "Çözünürlük": "Resolution", "Yerel": "Native", "Biçim": "Format", "Süre yazısı": "Timer font", "Yazı boyutu": "Font size",
    "Kayıt bitince": "When a recording ends", "Bildirim göster": "Show a notification", "Dosya yolunu panoya kopyala": "Copy the file path to the clipboard",
    "Düğme biçimi": "Button style", "Daire": "Circle", "Hap": "Pill", "Yalnız simge": "Icon only",
    "Ne paylaşılsın?": "What should be shared?", "Bir uygulama ekranını görmek istiyor. Birini seç.": "An app wants to see your screen. Pick one.",
    "Ekranlar": "Screens", "Pencereler (6)": "Windows (6)", "Tüm ekran · eDP-1": "Whole screen · eDP-1", "Bu seçimi hatırla (bir daha sorma)": "Remember this choice (don't ask again)",
    "İptal": "Cancel", "OBS bağlantısı": "OBS connection"
  };
  const SCENES = { "Sahne": "Desktop", "Oyun": "Game", "Kamera": "Camera" };
  const mockNodes = [];
  $$(".opanel, .pick-card").forEach(root => {
    const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    for (let n; (n = w.nextNode());) {
      const tr = n.nodeValue.trim();
      if (!tr || n.parentElement.closest("[data-i18n]")) continue;
      const inChips = n.parentElement.closest(".chips");
      const en = inChips ? SCENES[tr] : MOCK[tr];
      if (en) mockNodes.push({ n, tr, en, pad: n.nodeValue.replace(tr, "\u0000") });
    }
  });
  function mockFor(lang) {
    mockNodes.forEach(m => { m.n.nodeValue = m.pad.replace("\u0000", lang === "tr" ? m.tr : m.en); });
  }
  shotsFor(root.dataset.theme, "en");

  /* ── language ── */
  const TR = {
    "nav.how": "Nasıl çalışır", "nav.panel": "Panel", "nav.picker": "Seçici", "nav.install": "Kurulum",
    "hero.eyebrow": "OBS Studio · Quickshell · Hyprland için",
    "hero.h1a": "Kayıt almak,", "hero.h1b": "tek bir sessiz düğme.",
    "hero.lede": "Çubuğunda küçük bir daire; kayıt sırasında hapa açılır. Ayrıntılar için bir panel, her yerden çalışan bir kısayol. Kaydı OBS yapmaya devam eder; obscura yalnızca kumandayı tutar.",
    "hero.more": "Kurulum adımları →",
    "demo.saved": "Kaydedildi", "demo.idle": "Boşta", "demo.rec": "Kayıtta", "demo.pause": "Duraklatıldı", "demo.savedBtn": "Kaydedildi", "demo.auto": "Otomatik",
    "f.cpu": "boştayken CPU. Yoklama döngüsü yok; istemci soket üzerinde bekler.",
    "f.size": "release ikilisi. Rust, tek süreç, çalışma zamanı yok.",
    "f.ram": "OBS'i izleyen sürecin bellek kullanımı.",
    "f.cfg": "gereken yapılandırma dosyası. Port ve parola OBS'in kendisinden okunur.",
    "how.label": "Nasıl çalışır", "how.h": "Bir kumanda; yeni bir kaydedici değil.",
    "how.1h": "İşi OBS yapar", "how.1p": "obscura, elindeki OBS'i yerleşik WebSocket sunucusu üzerinden sürer. Sahnelerin, kaynakların ve kodlayıcı ayarların OBS'te kalır; hiçbir şey yeniden yazılmaz.",
    "how.2h": "Tek ince katman", "how.2p": "Küçük bir Rust ikilisi OBS'i izler ve durumu JSON satırları olarak yazar. Quickshell modülü bunları okuyup hapı çizer. Biri ölürse diğeri etkilenmez.",
    "how.3h": "Asla tahmin etmez", "how.3p": "Kırmızı nokta yalnızca OBS kaydın başladığını söylediğinde yanar. OBS kapalıysa, sunucu kapalıysa ya da parola yanlışsa hap numara yapmaz, söyler.",
    "panel.label": "Panel", "panel.h": "Elinin gittiği her şey, fazlası değil.",
    "panel.l1": "Başlat, duraklat, durdur; sahne değiştir; ses kaynaklarını canlı seviye çubuklarıyla sessize al.",
    "panel.l2": "Kayıt klasörünü gezerek seç, dosya adı kalıbını ayarla, sonraki dosyanın adını gör. Ad zaten alınmışsa uyarı çıkar.",
    "panel.l3": "Kare hızı seçenekleri ekranına uyar: 144 Hz ekran 120 ve 144 sunar, 60 Hz ekran 120 sunmaz.",
    "panel.l4": "Çözünürlük, biçim ve replay süresi OBS'te anında değişir. Kayıt sürerken OBS'in değiştirmeye izin vermedikleri kilitlenir.",
    "panel.l5": "Süre yazısı, boyutu, düğme biçimi, bildirimler ve OBS portu senin elinde.",
    "panel.note": "Panel İngilizce ve Türkçe konuşur, sistem diline uyar (Görünüm → Dil).",
    "feat.label": "Ayrıntılar", "feat.h": "Küçük şeyler, özenle.",
    "feat.1h": "Her yerden kısayol", "feat.1p": "<code>obscura toggle</code> çubuk kapalıyken de çalışır. OBS de kapalıysa onu arka planda açar ve kaydı başlatır.",
    "feat.2h": "Tıklayınca açılır", "feat.2p": "OBS kapalıyken hapa tıkla; simge durumunda başlar. İkinci bir kopya hiç başlatılmaz.",
    "feat.3h": "Kayıttan sonra", "feat.3p": "Bildirim, isteğe bağlı olarak yolun panoya kopyalanması ve <code>~/.config/obscura/hooks/saved.d/</code> içine attığın her çalıştırılabilir dosya.",
    "feat.4h": "Seviye çubukları", "feat.4p": "OBS saniyede 50 civarı seviye olayı gönderir. obscura bunu on iki kadara indirir ve yalnız panel açıkken.",
    "feat.5h": "Çubuğa nazik", "feat.5p": "Sürekli solma yerine yanıp sönme, animasyon sırasında boyutu değişmeyen pencere ve yalnız açıkken var olan panel.",
    "feat.6h": "Kendi yazı tipin", "feat.6p": "Süre Space Mono ya da nokta matris Doto olabilir; 10 ile 32 px arası her boyutta.",
    "pick.label": "Ekran paylaşımı seçici", "pick.h": "OBS'in sorduğu diyalog, senin tarzında.",
    "pick.p1": "Wayland'de OBS hangi ekranı ya da pencereyi yakalayacağını masaüstü portalına sorar; stok diyalog masaüstünde hiçbir şeye benzemez. obscura bu soruyu kendisi yanıtlayabilir, Quickshell kurulumunun çizdiği bir kartla.",
    "pick.p2": "İsteğe bağlı ve güvenli: widget çalışmıyorsa stok diyalog açılır. Tek dikkat: portal soruyu kimin sorduğunu söylemez, bu yüzden tarayıcı ve Discord dahil her uygulamanın paylaşım isteği bu kartı kullanır.",
    "inst.label": "Kurulum", "inst.h": "Kaynaktan, beş dakikada.",
    "inst.1h": "OBS'in WebSocket sunucusunu aç", "inst.1p": "OBS'te: Tools → WebSocket Server Settings → Enable. OBS 28 ya da daha yenisi gerekir.",
    "inst.2h": "Derle",
    "inst.3h": "Çubuğuna ekle", "inst.3p": "Modülü Quickshell yapılandırmana koy ve hapı istediğin yere yerleştir. <code>pal</code> renk nesnen, <code>u</code> ölçek birimin.",
    "inst.4h": "Bir tuşa bağla",
    "shots.label": "Ekran görüntüleri", "shots.h": "Gerçek widget, iki temada.",
    "shots.c1": "Kayıtta", "shots.c2": "Kaydedildi", "shots.c3": "OBS sunucusu kapalıyken", "shots.c4": "Kontrol", "shots.c5": "Kayıt ayarları, ad alınmış uyarısıyla", "shots.c6": "Klasör seçici", "shots.c7": "Görünüm ve kancalar", "shots.c8": "Ekran paylaşımı seçici: ekranlar", "shots.c9": "Ekran paylaşımı seçici: pencereler",
    "shots.note": "Widget'ın kendi koduyla, uydurma bir dünyada çizildi; burada gerçek bir masaüstünden hiçbir şey yok.",
    "film.cap": "Kurulumun tamamı, baştan sona: OBS, derleme, çubuk, kısayol (82 sn, sessiz).",
    "inst.note": "Hyprland, OBS Studio 32 ve Quickshell 0.3 üzerinde derlenip denendi. Diğer kurulumlar denenmedi.",
    "foot.tag": "— camera obscura: ışığın bir görüntü oluşturmak için geçtiği karanlık oda.",
    "tab.control": "Kontrol", "tab.record": "Kayıt", "tab.look": "Görünüm",
  };
  const enCache = new Map();
  $$("[data-i18n]").forEach(el => enCache.set(el, el.innerHTML));
  function setLang(l) {
    root.lang = l;
    $$("[data-i18n]").forEach(el => {
      const k = el.dataset.i18n;
      el.innerHTML = l === "tr" && TR[k] ? TR[k] : enCache.get(el);
    });
    const film = $("#film");
    if (film) {
      const wasPaused = film.paused, at = film.currentTime;
      film.poster = "video/poster-" + l + ".jpg";
      film.querySelector("source").src = "video/obscura-install-" + l + ".mp4";
      film.load();
      if (at > 0) film.addEventListener("loadedmetadata", () => { film.currentTime = at; if (!wasPaused) film.play(); }, { once: true });
    }
    shotsFor(root.dataset.theme, l);
    mockFor(l);
    $("#lang").textContent = l === "tr" ? "EN" : "TR";
    store.set("obscura-lang", l);
  }
  $("#lang").addEventListener("click", () => setLang(root.lang === "tr" ? "en" : "tr"));
  mockFor("en");
  const savedLang = store.get("obscura-lang") || ((navigator.language || "").startsWith("tr") ? "tr" : "en");
  if (savedLang === "tr") setLang("tr");

  /* ── copy ── */
  $("#copy").addEventListener("click", async e => {
    const b = e.currentTarget;
    try { await navigator.clipboard.writeText($("#cmd code").textContent); b.textContent = "✓"; }
    catch { b.textContent = "—"; }
    setTimeout(() => (b.textContent = "Copy"), 1400);
  });

  /* ── pill demo ── */
  const pill = $("#opill"), c1 = $("#clock"), c2 = $("#clock2"), pt = $("#pt");
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let secs = 0, tick = null, auto = !reduce, timer = null, mode = "idle";
  const fmt = n => String(Math.floor(n / 60)).padStart(2, "0") + ":" + String(n % 60).padStart(2, "0");
  function render() { c1.textContent = c2.textContent = fmt(secs); }
  function set(m, fromAuto) {
    if (!fromAuto) { auto = false; $("#auto").classList.remove("on"); clearTimeout(timer); }
    mode = m;
    pill.dataset.mode = m;
    $$(".steps [data-set]").forEach(b => b.classList.toggle("on", b.dataset.set === m));
    clearInterval(tick);
    if (m === "rec") { if (!secs) secs = 0; tick = setInterval(() => { secs++; render(); }, 1000); }
    if (m === "idle") secs = 0;
    render();
  }
  const script = [["idle", 2200], ["rec", 5200], ["pause", 2600], ["rec", 2600], ["saved", 2400]];
  let i = 0;
  function run() {
    if (!auto) return;
    const [m, ms] = script[i % script.length];
    if (m === "idle") secs = 0;
    set(m, true);
    i++;
    timer = setTimeout(run, ms);
  }
  $$(".steps [data-set]").forEach(b => b.addEventListener("click", () => set(b.dataset.set, false)));
  $("#auto").addEventListener("click", e => {
    auto = !auto;
    e.currentTarget.classList.toggle("on", auto);
    if (auto) { i = 0; run(); } else clearTimeout(timer);
  });
  pill.addEventListener("click", () => set(mode === "idle" ? "rec" : mode === "rec" ? "saved" : "idle", false));
  render();
  if (auto) timer = setTimeout(run, 900);

  /* ── panel tabs + meters ── */
  $$(".tabs [data-tab]").forEach(b => b.addEventListener("click", () => {
    $$(".tabs [data-tab]").forEach(x => x.classList.toggle("on", x === b));
    $$(".tabpane").forEach(p => p.classList.toggle("on", p.dataset.pane === b.dataset.tab));
  }));
  const lv = $$(".lvl u");
  let metersOn = false;
  new IntersectionObserver(es => { metersOn = es[0].isIntersecting; }, { threshold: 0.3 }).observe($("#opanel"));
  if (!reduce) setInterval(() => {
    if (!metersOn) return;
    lv.forEach((u, k) => { u.style.width = Math.round((k ? 8 + Math.random() * 30 : 25 + Math.random() * 55)) + "%"; });
  }, 140);

  /* ── reveal ── */
  $$(".sec > *, .band .facts, .stage").forEach(el => el.classList.add("rv"));
  const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }), { threshold: 0.08 });
  $$(".rv").forEach(el => io.observe(el));
})();
