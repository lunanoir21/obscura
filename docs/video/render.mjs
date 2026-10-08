// node render.mjs [en|tr]   → frames/*.jpg, then ffmpeg (see render.sh)
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const lang = process.argv[2] || 'en';
const only = process.argv[3] ? process.argv[3].split(',').map(Number) : null; // preview times
const here = path.dirname(fileURLToPath(import.meta.url));
const out = process.env.FRAMES || path.join(here, 'frames-' + lang);
fs.mkdirSync(out, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
await page.goto('file://' + path.join(here, 'film.html') + '?lang=' + lang);
await page.evaluate(() => document.fonts.ready);
const dur = await page.evaluate(() => window.DUR);
const fps = 30;
if (only) {
  for (const t of only) {
    await page.evaluate(t => window.seek(t), t);
    await page.screenshot({ path: path.join(out, `at-${t}.jpg`), type: 'jpeg', quality: 92 });
  }
} else {
  const n = Math.round(dur * fps);
  for (let i = 0; i < n; i++) {
    await page.evaluate(t => window.seek(t), i / fps);
    await page.screenshot({ path: path.join(out, String(i).padStart(5, '0') + '.jpg'), type: 'jpeg', quality: 90 });
  }
}
await browser.close();
