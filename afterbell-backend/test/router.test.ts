// Runs the router against a small stand-in for the WordPress site.  node --experimental-strip-types test/router.test.ts
import http from 'node:http';
import { handle } from '../lib/router.ts';

const TOKEN = '7.' + 'a'.repeat(48);
const seen: { url: string; method: string; headers: http.IncomingHttpHeaders; body: string }[] = [];

const wp = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    seen.push({ url: req.url || '', method: req.method || '', headers: req.headers, body });
    const send = (status: number, data: unknown) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(data)); };
    const u = new URL(req.url || '', 'http://x');
    const p = u.pathname.replace('/wp-json/afterbell/v1', '');
    if (p === '/app/classes') return send(200, { items: [{ id: 1 }], total: 1, pages: 1 });
    if (p === '/app/classes/12') return send(200, { id: 12, title: 'Math' });
    if (p === '/app/classes/99') return send(404, { code: 'ab_not_found', message: 'Class not found.' });
    if (p === '/app/login') return JSON.parse(body).password === 'right' ? send(200, { token: TOKEN, user: { id: 7 } }) : send(401, { code: 'ab_login', message: 'The email or password is not right.' });
    if (p === '/app/me') return req.headers['x-afterbell-token'] === TOKEN ? send(200, { id: 7 }) : send(401, { code: 'rest_forbidden', message: 'Sorry, you are not allowed to do that.' });
    if (p === '/live') return send(200, { live: true, echo: JSON.parse(body) });
    if (p === '/app/home') { res.writeHead(200); return res.end('<html>broken</html>'); }
    return send(500, { code: 'internal', message: 'secret stack trace' });
  });
});

let failed = 0;
function ok(cond: boolean, name: string) { console.log((cond ? 'PASS ' : 'FAIL ') + name); if (!cond) failed++; }
const api = (path: string, init: RequestInit = {}) => handle(new Request('https://app.example' + path, init));
const post = (path: string, body: unknown, token = '') => api(path, { method: 'POST', body: typeof body === 'string' ? body : JSON.stringify(body), headers: token ? { Authorization: 'Bearer ' + token } : {} });

wp.listen(0, async () => {
  const port = (wp.address() as { port: number }).port;
  process.env.WP_URL = `http://127.0.0.1:${port}/`;
  process.env.WP_APP_KEY = 'k123';

  let r = await api('/api/health'); ok(r.status === 200 && (await r.json()).ok === true, 'health');

  r = await api('/api/classes?q=math&age=9&evil=1&page=2');
  let last = seen[seen.length - 1];
  ok(r.status === 200 && (r.headers.get('cache-control') || '').includes('s-maxage=60'), 'public list is cacheable');
  ok(last.url.includes('q=math') && last.url.includes('age=9') && last.url.includes('page=2') && !last.url.includes('evil'), 'only allowed query fields are forwarded');
  ok(!last.headers['x-afterbell-token'] && !last.headers['x-afterbell-key'], 'no token or key on public reads');

  r = await api('/api/class?id=12'); ok(r.status === 200 && (await r.json()).title === 'Math', 'class detail');
  r = await api('/api/class?id=12', { headers: { Authorization: 'Bearer ' + TOKEN } }); last = seen[seen.length - 1];
  ok(r.headers.get('cache-control') === 'no-store' && last.url.includes('_u=') && last.headers['x-afterbell-token'] === TOKEN, 'signed-in read is private and carries the token');
  r = await api('/api/class?id=99'); let j = await r.json(); ok(r.status === 404 && j.error.code === 'not_found', '404 passes through with a clean code');
  r = await api('/api/class?id=12abc'); ok(r.status === 404, 'non-numeric id is rejected before WordPress');
  r = await api('/api/class?id=../../users'); ok(r.status === 404, 'unknown path is rejected');
  r = await api('/api/unknown'); ok(r.status === 404, 'unknown route');
  r = await post('/api/classes', {}); ok(r.status === 405, 'wrong method');

  r = await post('/api/auth/login', { email: 'a@b.c', password: 'wrong', role: 'administrator' }); j = await r.json(); last = seen[seen.length - 1];
  ok(r.status === 401 && j.error.code === 'login', 'wrong password');
  ok(last.headers['x-afterbell-key'] === 'k123' && !last.body.includes('role'), 'app key sent, extra fields dropped');
  r = await post('/api/auth/login', { email: 'a@b.c', password: 'right' }); j = await r.json(); ok(r.status === 200 && j.token === TOKEN, 'login returns token');
  r = await post('/api/auth/login', '{not json'); ok(r.status === 400, 'bad json');
  r = await post('/api/auth/login', { email: 'x'.repeat(9000) }); ok(r.status === 413, 'oversized body');

  const before = seen.length;
  r = await api('/api/me'); ok(r.status === 401 && seen.length === before, 'no token: refused without calling WordPress');
  r = await api('/api/me', { headers: { Authorization: 'Bearer nonsense' } }); ok(r.status === 401 && seen.length === before, 'malformed token refused');
  r = await api('/api/me', { headers: { Authorization: 'Bearer ' + TOKEN } }); ok(r.status === 200, 'me with token');
  r = await api('/api/me', { headers: { Authorization: 'Bearer 7.' + 'b'.repeat(48) } }); j = await r.json(); ok(r.status === 401 && j.error.code === 'signed_out', 'expired token becomes signed_out');

  r = await post('/api/live', { do: 'act', class: 7, type: 'poll', q: 'Hi', opts: ['a', 'b'], admin: true, nested: { x: 1 } }, TOKEN); j = await r.json();
  ok(r.status === 200 && j.echo.opts.length === 2 && j.echo.admin === undefined && j.echo.nested === undefined && j.echo.class === 7, 'live action forwards only known fields');

  r = await api('/api/home'); ok(r.status === 502, 'non-JSON answer from WordPress becomes 502');
  r = await api('/api/teacher?id=5'); j = await r.json(); ok(r.status === 502 && !JSON.stringify(j).includes('secret'), 'server error becomes 502 without leaking its message');

  r = await api('/api/me', { method: 'OPTIONS' }); ok(r.status === 204 && r.headers.get('access-control-allow-methods') !== null, 'CORS preflight');

  let blocked = false;
  for (let i = 0; i < 25; i++) { r = await post('/api/auth/login', { email: 'a@b.c', password: 'wrong' }); if (r.status === 429) blocked = true; }
  ok(blocked, 'repeated sign-in attempts are slowed down');

  process.env.WP_URL = 'http://127.0.0.1:1'; r = await api('/api/classes'); ok(r.status === 502, 'site down becomes 502');
  wp.close();
  console.log(failed ? `\n${failed} FAILED` : '\nall passed');
  process.exit(failed ? 1 : 0);
});
