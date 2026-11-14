// Cloudflare Worker: stores, per push token, only random countdown IDs and times and, once a minute,
// sends an APNs push-to-start so iOS starts the Hasta Live Activity.
// Bindings: D1 DB (items and hits tables), KV SCHEDULE (APNs token cache).
// Secrets: APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID.
const BUNDLE_ID = "com.exaltedpixels.Hasta";
const MAX_COUNTDOWNS = 50;
const MAX_BODY = 20_000;
const MAX_POSTS_PER_MINUTE = 20;
const UUID = /^[0-9A-Fa-f-]{36}$/;
const HEX = /^[0-9a-f]{20,400}$/;

export function parseSchedule(body) {
  if (!body || typeof body !== "object") return null;
  const { token, sandbox, countdowns } = body;
  if (!HEX.test(token ?? "") || !Array.isArray(countdowns)) return null;
  const items = countdowns.slice(0, MAX_COUNTDOWNS)
    .filter((c) => c && UUID.test(c.id ?? "") && Number.isFinite(c.fireAt) && Number.isFinite(c.target))
    .map((c) => ({ id: c.id, fireAt: Math.floor(c.fireAt), target: Math.floor(c.target) }));
  return { token, sandbox: !!sandbox, items };
}

// ok: delivered. badToken: forget the device. retry: try again next minute. drop: give up on this item.
export function classifyApns(status, reason) {
  if (status === 200) return "ok";
  if (status === 410 || (status === 400 && (reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic"))) return "badToken";
  if (status === 0 || status === 403 || status === 429 || status >= 500) return "retry";
  return "drop";
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/v1/schedule") return new Response("Not found", { status: 404 });
    if (!(await withinLimit(env, request))) return new Response("Slow down", { status: 429 });
    const text = await request.text();
    if (text.length > MAX_BODY) return new Response("Too large", { status: 413 });
    let body;
    try { body = JSON.parse(text); } catch { return new Response("Bad JSON", { status: 400 }); }
    const parsed = parseSchedule(body);
    if (!parsed) return new Response("Bad request", { status: 400 });

    const hash = await sha256(parsed.token);
    const now = Date.now();
    if (parsed.items.length === 0) {
      await env.DB.prepare("DELETE FROM items WHERE token_hash = ?").bind(hash).run();
      return new Response("ok");
    }
    const upsert = env.DB.prepare(
      `INSERT INTO items (token_hash, token, sandbox, id, fire_at, target, sent, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0, ?7)
       ON CONFLICT (token_hash, id, target) DO UPDATE SET fire_at = excluded.fire_at, token = excluded.token, sandbox = excluded.sandbox, updated = excluded.updated`,
    );
    await env.DB.batch([
      ...parsed.items.map((i) => upsert.bind(hash, parsed.token, parsed.sandbox ? 1 : 0, i.id, i.fireAt, i.target, now)),
      env.DB.prepare("DELETE FROM items WHERE token_hash = ? AND updated < ?").bind(hash, now),
    ]);
    return new Response("ok");
  },

  async scheduled(_event, env) {
    const now = Math.floor(Date.now() / 1000);
    await ensureTables(env);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM hits WHERE minute < ?").bind(Math.floor(now / 60) - 5),
      env.DB.prepare("DELETE FROM items WHERE target < ?").bind(now - 86400),
      env.DB.prepare("DELETE FROM items WHERE updated < ?").bind((now - 40 * 86400) * 1000),
    ]);
    const { results } = await env.DB.prepare(
      "SELECT token_hash, token, sandbox, id, target FROM items WHERE sent = 0 AND fire_at <= ?1 AND target > ?1 LIMIT 200",
    ).bind(now).all();
    if (!results.length) return;

    const jwt = await apnsJWT(env);
    const updates = [];
    for (const row of results) {
      const { status, reason } = await sendStart(jwt, row, now);
      const verdict = classifyApns(status, reason);
      if (verdict !== "ok") console.error("apns", status, reason, verdict);
      if (status === 403) await env.SCHEDULE.delete("jwt");
      if (verdict === "ok" || verdict === "drop") {
        updates.push(env.DB.prepare("UPDATE items SET sent = 1 WHERE token_hash = ? AND id = ? AND target = ?").bind(row.token_hash, row.id, row.target));
      } else if (verdict === "badToken") {
        updates.push(env.DB.prepare("DELETE FROM items WHERE token_hash = ?").bind(row.token_hash));
      }
    }
    if (updates.length) await env.DB.batch(updates);
  },
};

let tablesReady = false;

async function ensureTables(env) {
  if (tablesReady) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS hits (ip_hash TEXT NOT NULL, minute INTEGER NOT NULL, n INTEGER NOT NULL, PRIMARY KEY (ip_hash, minute))").run();
  tablesReady = true;
}

// Counted in D1 so the limit holds across all locations. The built-in rate limit binding did not block in testing.
async function withinLimit(env, request) {
  await ensureTables(env);
  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
  const row = await env.DB.prepare(
    "INSERT INTO hits (ip_hash, minute, n) VALUES (?1, ?2, 1) ON CONFLICT (ip_hash, minute) DO UPDATE SET n = n + 1 RETURNING n",
  ).bind(await sha256(ip), Math.floor(Date.now() / 60000)).first();
  return row.n <= MAX_POSTS_PER_MINUTE;
}

async function sendStart(jwt, row, now) {
  const host = row.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  try {
    const response = await fetch(`https://${host}/3/device/${row.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-push-type": "liveactivity",
        "apns-topic": `${BUNDLE_ID}.push-type.liveactivity`,
        "apns-priority": "10",
      },
      body: JSON.stringify({
        aps: {
          timestamp: now,
          event: "start",
          "attributes-type": "CountdownActivityAttributes",
          attributes: { countdownID: row.id },
          "content-state": { start: now, target: row.target, revision: 0 },
          "stale-date": row.target,
          alert: { title: "Hasta", body: "A countdown is starting soon" },
        },
      }),
    });
    let reason;
    if (response.status !== 200) reason = (await response.json().catch(() => ({}))).reason;
    return { status: response.status, reason };
  } catch {
    return { status: 0 };
  }
}

async function sha256(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function base64url(bytes) {
  return btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Apple rejects a new provider token more than once per 20 minutes, so reuse one for 40.
async function apnsJWT(env) {
  const cached = await env.SCHEDULE.get("jwt");
  if (cached) return cached;
  const pem = env.APNS_KEY_P8.replace(/-----[^-]+-----|\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const enc = new TextEncoder();
  const header = base64url(enc.encode(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID })));
  const claims = base64url(enc.encode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) })));
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(`${header}.${claims}`));
  const jwt = `${header}.${claims}.${base64url(signature)}`;
  await env.SCHEDULE.put("jwt", jwt, { expirationTtl: 2400 });
  return jwt;
}
