/**
 * Afterbell app backend.
 * The Flutter app talks only to this service. It checks and shapes each request,
 * then reads and writes the Afterbell WordPress site through its REST API.
 *
 * Written against the standard Request/Response objects, so it runs in Next.js route handlers
 * and can be tested with plain Node.
 */

type Json = Record<string, unknown>;

interface Route {
  method: 'GET' | 'POST';
  /** App path, e.g. /classes. A WordPress path with :id takes it from the ?id= query value. */
  path: string;
  /** WordPress path under /wp-json/afterbell/v1 */
  wp: string;
  /** Needs a signed-in user. */
  auth?: boolean;
  /** Seconds a public answer may be cached at the edge. */
  cache?: number;
  /** Allowed query or body fields. Anything else is dropped. */
  fields?: string[];
  /** Sends the shared app key to WordPress. */
  key?: boolean;
  /** Counts towards the sign-in rate limit. */
  limited?: boolean;
}

export const ROUTES: Route[] = [
  { method: 'GET', path: '/home', wp: '/app/home', cache: 120 },
  { method: 'GET', path: '/classes', wp: '/app/classes', cache: 60, fields: ['q', 'track', 'subj', 'age', 'format', 'teacher', 'page'] },
  { method: 'GET', path: '/class', wp: '/app/classes/:id', cache: 60 },
  { method: 'GET', path: '/teacher', wp: '/app/teachers/:id', cache: 120 },

  { method: 'POST', path: '/auth/login', wp: '/app/login', fields: ['email', 'password'], key: true, limited: true },
  { method: 'POST', path: '/auth/signup', wp: '/app/signup', fields: ['name', 'email', 'password'], key: true, limited: true },
  { method: 'POST', path: '/auth/logout', wp: '/app/logout', auth: true },

  { method: 'GET', path: '/me', wp: '/app/me', auth: true },
  { method: 'POST', path: '/me/learners', wp: '/app/learners', auth: true, fields: ['op', 'name', 'age', 'grade', 'index'] },
  { method: 'GET', path: '/me/favorites', wp: '/app/favorites', auth: true },
  { method: 'POST', path: '/me/favorites', wp: '/app/favorite', auth: true, fields: ['id'] },

  { method: 'GET', path: '/classrooms', wp: '/app/classrooms', auth: true },
  { method: 'GET', path: '/classroom', wp: '/app/classrooms/:id', auth: true },
  {
    method: 'POST', path: '/live', wp: '/live', auth: true,
    fields: ['do', 'class', 'name', 'since', 'mood', 'type', 'val', 'ref', 'q', 'opts', 'right', 'tuid', 'tname', 'vote', 'reaction', 'comment'],
  },
  { method: 'GET', path: '/teaching', wp: '/app/teaching', auth: true, fields: ['days'] },
];

const MAX_BODY = 8 * 1024;
const TIMEOUT_MS = 15000;

function env(name: string): string {
  const p = (globalThis as { process?: { env?: Record<string, string | undefined> } }).process;
  return (p && p.env && p.env[name]) || '';
}

function cors(): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': env('CORS_ORIGIN') || '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

export function reply(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...cors(), ...extra },
  });
}

function fail(status: number, code: string, message: string): Response {
  return reply({ error: { code, message } }, status);
}

/* Best-effort sign-in limiter. Serverless instances do not share memory, so WordPress also limits attempts per email. */
const hits = new Map<string, { n: number; until: number }>();
function limited(ip: string): boolean {
  const now = Date.now();
  const h = hits.get(ip);
  if (!h || h.until < now) {
    hits.set(ip, { n: 1, until: now + 10 * 60 * 1000 });
    if (hits.size > 5000) hits.clear();
    return false;
  }
  h.n += 1;
  return h.n > 20;
}

async function shortHash(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).slice(0, 8).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function pick(source: Json, fields: string[] | undefined): Json {
  const out: Json = {};
  for (const f of fields || []) {
    const v = source[f];
    if (v === undefined || v === null) continue;
    if (typeof v === 'string') out[f] = v.slice(0, 1000);
    else if (typeof v === 'number' || typeof v === 'boolean') out[f] = v;
    else if (Array.isArray(v)) out[f] = v.slice(0, 6).map((x) => String(x).slice(0, 200));
  }
  return out;
}

export async function handle(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors() });

  const wpBase = env('WP_URL').replace(/\/+$/, '');
  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/api/, '').replace(/\/+$/, '') || '/';

  if (path === '/health') {
    return reply({ ok: true, wordpress: wpBase ? new URL(wpBase).host : null, time: new Date().toISOString() });
  }
  if (!wpBase) return fail(500, 'not_configured', 'The backend is missing its WP_URL setting.');

  const known = ROUTES.filter((r) => r.path === path);
  const route = known.find((r) => r.method === req.method);
  if (!route) return known.length ? fail(405, 'method_not_allowed', 'This action is not available.') : fail(404, 'not_found', 'Not found.');

  let wpPath = route.wp;
  if (wpPath.includes(':id')) {
    const id = url.searchParams.get('id') || '';
    if (!/^\d{1,12}$/.test(id)) return fail(404, 'not_found', 'Not found.'); // ids are numbers only
    wpPath = wpPath.replace(':id', id);
  }

  const bearer = (req.headers.get('authorization') || '').match(/^Bearer\s+(\d{1,12}\.[A-Za-z0-9]{48})$/);
  const token = bearer ? bearer[1] : '';
  if (route.auth && !token) return fail(401, 'signed_out', 'Please log in to continue.');

  if (route.limited) {
    const ip = (req.headers.get('x-forwarded-for') || 'unknown').split(',')[0].trim();
    if (limited(ip)) return fail(429, 'slow_down', 'Too many attempts. Please wait a few minutes and try again.');
  }

  const target = new URL(wpBase + '/wp-json/afterbell/v1' + wpPath);

  const headers: Record<string, string> = { Accept: 'application/json', 'User-Agent': 'afterbell-backend/1.0' };
  if (token) {
    headers['X-Afterbell-Token'] = token;
    // Keeps any page cache in front of WordPress from mixing up two people's answers.
    target.searchParams.set('_u', await shortHash(token));
  }
  if (route.key && env('WP_APP_KEY')) headers['X-Afterbell-Key'] = env('WP_APP_KEY');

  const init: RequestInit = { method: route.method, headers, signal: AbortSignal.timeout(TIMEOUT_MS) };

  if (route.method === 'GET') {
    const q: Json = {};
    url.searchParams.forEach((v, k) => { q[k] = v; });
    for (const [k, v] of Object.entries(pick(q, route.fields))) target.searchParams.set(k, String(v));
    // Public catalog answers are the same for everyone, so Next.js may reuse them for a short time.
    if (route.cache && !token) (init as RequestInit & { next?: { revalidate: number } }).next = { revalidate: route.cache };
    else init.cache = 'no-store';
  } else {
    const raw = await req.text();
    if (raw.length > MAX_BODY) return fail(413, 'too_large', 'That request is too large.');
    let body: Json = {};
    if (raw) {
      try {
        const parsed: unknown = JSON.parse(raw);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) body = parsed as Json;
        else return fail(400, 'bad_request', 'The request could not be read.');
      } catch {
        return fail(400, 'bad_request', 'The request could not be read.');
      }
    }
    headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(pick(body, route.fields));
    init.cache = 'no-store';
  }

  let res: Response;
  try {
    res = await fetch(target, init);
  } catch {
    return fail(502, 'site_unreachable', 'We could not reach Afterbell right now. Please try again.');
  }

  let data: unknown = null;
  try {
    data = await res.json();
  } catch {
    return fail(502, 'bad_answer', 'Afterbell sent an answer we could not read. Please try again.');
  }

  if (!res.ok) {
    const e = (data || {}) as { code?: string; message?: string };
    const status = res.status === 401 || res.status === 403 || res.status === 404 || res.status === 409 || res.status === 429 || res.status === 400 ? res.status : 502;
    // WordPress answers "rest_forbidden" (401) when a token has expired.
    const code = e.code === 'rest_forbidden' || e.code === 'rest_not_logged_in' ? 'signed_out' : String(e.code || 'error').replace(/^ab_/, '');
    if (code === 'signed_out') return fail(401, code, 'Please log in again.');
    // Never pass internal server messages on to the app.
    if (status === 502) return fail(502, 'site_error', 'Afterbell had a problem. Please try again.');
    return fail(status, code, String(e.message || 'Something went wrong. Please try again.'));
  }

  const cacheable = route.method === 'GET' && route.cache && !token;
  return reply(data, 200, cacheable ? { 'Cache-Control': `public, s-maxage=${route.cache}, stale-while-revalidate=300` } : {});
}
