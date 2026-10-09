// node render.mjs [en|tr]   → frames/*.jpg, then ffmpeg (see render.sh)
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const lang = process.argv[2] || 'en';
const only = process.argv[3] ? process.argv[3].split(',').map(Number) : null; // preview times
const here = path.dirname(fileURLToPath(import.meta.url));
const out = process.env.FRAMES || path.join(here, 'frames-' + lang);
fs.mkdirSync(out, { recursive: true });

// the OBS footage becomes numbered frames the page can show at any instant
const framesDir = path.join(process.env.FRAMES_TMP || os.tmpdir(), 'obscura-film-obs-' + lang);
fs.rmSync(framesDir, { recursive: true, force: true });
fs.mkdirSync(framesDir, { recursive: true });
execFileSync('ffmpeg', ['-loglevel', 'error', '-i', path.join(here, 'clips', 'obs-' + lang + '.mp4'), '-vf', 'fps=30', '-q:v', '3', path.join(framesDir, '%05d.jpg')]);

// frames caught mid-move (see clips/obs-<lang>-fix.json) show the last good frame instead
const fixFile = path.join(here, 'clips', 'obs-' + lang + '-fix.json');
if (fs.existsSync(fixFile)) {
  const { hold } = JSON.parse(fs.readFileSync(fixFile, 'utf8'));
  const name = n => path.join(framesDir, String(n).padStart(5, '0') + '.jpg');
  for (const [bad, good] of Object.entries(hold)) fs.copyFileSync(name(good), name(bad));
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
await page.goto('file://' + path.join(here, 'film.html') + '?lang=' + lang + '&frames=' + encodeURIComponent('file://' + framesDir));
await page.evaluate(() => document.fonts.ready);
const dur = await page.evaluate(() => window.DUR);
const fps = 30;
if (only) {
  for (const t of only) {
    await page.evaluate(t => window.seek(t), t);
    await page.evaluate(() => window.ready());
    await page.screenshot({ path: path.join(out, `at-${t}.jpg`), type: 'jpeg', quality: 92 });
  }
} else {
  const n = Math.round(dur * fps);
  for (let i = 0; i < n; i++) {
    await page.evaluate(t => window.seek(t), i / fps);
    await page.evaluate(() => window.ready());
    await page.screenshot({ path: path.join(out, String(i).padStart(5, '0') + '.jpg'), type: 'jpeg', quality: 90 });
  }
}
await browser.close();
