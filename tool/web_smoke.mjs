// Web runtime smoke: serve a built Flutter web app, drive headless Chrome
// over the DevTools protocol, prove that the theme choice persists across
// a page reload (drift on web through sqlite3.wasm + drift_worker.js).
//   node tool/web_smoke.mjs <build/web dir> [chrome binary]
// Exit 0 proven; 3 not performed (no Chrome); 1 assertion failed.
import { createServer } from 'node:http';
import { readFile, stat, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { join, extname } from 'node:path';

const dir = process.argv[2];
const chrome = process.argv[3] || process.env.CHROME_BIN ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css', '.png': 'image/png', '.ico': 'image/x-icon', '.otf': 'font/otf', '.ttf': 'font/ttf' };
const server = createServer(async (req, res) => {
  const path = req.url.split('?')[0];
  const file = join(dir, path === '/' ? 'index.html' : path);
  try {
    await stat(file);
    res.writeHead(200, { 'content-type': types[extname(file)] || 'application/octet-stream' });
    res.end(await readFile(file));
  } catch {
    res.writeHead(404); res.end();
  }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const port = server.address().port;
try { await stat(chrome); } catch { console.error(`web smoke not performed: Chrome not found at ${chrome} (set CHROME_BIN)`); process.exit(3); }
const profileDir = join(process.env.TMPDIR || '/tmp', 'web-smoke-profile-' + process.pid);
const proc = spawn(chrome, ['--headless=new', '--remote-debugging-port=0', '--no-first-run', '--user-data-dir=' + profileDir, 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
process.on('exit', () => { try { proc.kill(); } catch {} });
// Chrome keeps writing to --user-data-dir for a moment after SIGTERM (shutdown
// flush); removing the dir before it actually exits races that write and the
// dir reappears. Wait for the real exit (falling back to SIGKILL) before rm.
const killAndWait = async (child) => {
  if (child.exitCode !== null || child.signalCode !== null) return;
  const exited = new Promise(r => child.once('exit', r));
  child.kill();
  let timer;
  const timeout = new Promise(r => { timer = setTimeout(() => r(true), 5000); });
  const timedOut = await Promise.race([exited.then(() => false), timeout]);
  clearTimeout(timer);
  if (timedOut && child.exitCode === null && child.signalCode === null) {
    try { child.kill('SIGKILL'); } catch { /* already gone */ }
    await exited;
  }
};
try {
  let wsUrl = '';
  for await (const chunk of proc.stderr) { const m = String(chunk).match(/DevTools listening on (ws:\/\/\S+)/); if (m) { wsUrl = m[1]; break; } }
  const ws = new WebSocket(wsUrl); await new Promise(r => ws.onopen = r);
  let id = 0; const pending = new Map();
  ws.onmessage = e => { const msg = JSON.parse(e.data); if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); } };
  const send = (method, params = {}, sessionId) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params, sessionId })); });
  const { result: { targetId } } = await send('Target.createTarget', { url: 'about:blank' });
  const { result: { sessionId } } = await send('Target.attachToTarget', { targetId, flatten: true });
  const evalJs = async (expression) => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sessionId)).result.result.value;
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: 'light' }] }, sessionId);
  await send('Page.navigate', { url: `http://127.0.0.1:${port}/` }, sessionId);
  const waitFor = async (js, label) => { for (let i = 0; i < 60; i++) { if (await evalJs(js)) return; await sleep(500); } throw new Error(`timeout waiting for ${label}`); };
  const enableSemantics = `(() => { const p = document.querySelector('flt-semantics-placeholder'); if (p) p.click(); return true; })()`;
  const tile = (label) => `[...document.querySelectorAll('flt-semantics [role="button"], flt-semantics [aria-label]')].find(e => (e.getAttribute('aria-label') || e.textContent || '').includes('${label}'))`;
  await waitFor(`document.querySelector('flt-semantics-placeholder') !== null || document.querySelector('flt-semantics') !== null`, 'flutter');
  await evalJs(enableSemantics);
  await waitFor(`${tile('Dark')} !== undefined`, 'the Dark tile');
  await evalJs(`${tile('Dark')}.click()`);
  await waitFor(`${tile('Dark')}?.getAttribute('aria-current') === 'true'`, 'Dark selected');
  await send('Page.reload', {}, sessionId);
  await waitFor(`document.querySelector('flt-semantics-placeholder') !== null || document.querySelector('flt-semantics') !== null`, 'flutter after reload');
  await evalJs(enableSemantics);
  await waitFor(`${tile('Dark')}?.getAttribute('aria-current') === 'true'`, 'Dark selected after reload');
  console.log('web smoke OK: dark theme persisted across reload');
} finally {
  await killAndWait(proc);
  server.close();
  await rm(profileDir, { recursive: true, force: true });
}
