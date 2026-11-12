// Cloudflare Worker: stores, per push token, only random countdown IDs and times and, once a minute,
// sends an APNs push-to-start so iOS starts the Hasta Live Activity.
// Bindings: KV namespace SCHEDULE. Secrets: APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID.
const BUNDLE_ID = "com.exaltedpixels.Hasta";
const MAX_COUNTDOWNS = 50;
const UUID = /^[0-9A-Fa-f-]{36}$/;
const HEX = /^[0-9a-f]{20,400}$/;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/v1/schedule") return new Response("Not found", { status: 404 });
    let body;
    try { body = await request.json(); } catch { return new Response("Bad JSON", { status: 400 }); }
    const { token, sandbox, countdowns } = body;
    if (!HEX.test(token ?? "") || !Array.isArray(countdowns)) return new Response("Bad request", { status: 400 });
    const key = `dev:${await sha256(token)}`;
    if (countdowns.length === 0) {
      await env.SCHEDULE.delete(key);
      return new Response("ok");
    }
    const items = countdowns.slice(0, MAX_COUNTDOWNS)
      .filter((c) => UUID.test(c.id ?? "") && Number.isFinite(c.fireAt) && Number.isFinite(c.target))
      .map((c) => ({ id: c.id, fireAt: c.fireAt, target: c.target }));
    await env.SCHEDULE.put(key, JSON.stringify({ token, sandbox: !!sandbox, items }), { expirationTtl: 40 * 86400 });
    return new Response("ok");
  },

  async scheduled(_event, env) {
    const now = Date.now() / 1000;
    const jwt = await apnsJWT(env);
    let cursor;
    do {
      const page = await env.SCHEDULE.list({ prefix: "dev:", cursor });
      for (const { name } of page.keys) {
        const device = JSON.parse((await env.SCHEDULE.get(name)) ?? "null");
        if (!device) continue;
        for (const item of device.items) {
          if (now < item.fireAt || now >= item.target) continue;
          const sentKey = `sent:${name}:${item.id}:${item.target}`;
          if (await env.SCHEDULE.get(sentKey)) continue;
          await env.SCHEDULE.put(sentKey, "1", { expirationTtl: 2 * 86400 });
          const status = await sendStart(jwt, device, item, now);
          if (status === 410 || status === 400) await env.SCHEDULE.delete(name);
        }
      }
      cursor = page.list_complete ? undefined : page.cursor;
    } while (cursor);
  },
};

async function sendStart(jwt, device, item, now) {
  const host = device.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const response = await fetch(`https://${host}/3/device/${device.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-push-type": "liveactivity",
      "apns-topic": `${BUNDLE_ID}.push-type.liveactivity`,
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: {
        timestamp: Math.floor(now),
        event: "start",
        "attributes-type": "CountdownActivityAttributes",
        attributes: { countdownID: item.id },
        "content-state": { start: now, target: item.target, revision: 0 },
        "stale-date": Math.floor(item.target),
        alert: { title: "Hasta", body: "A countdown is starting soon" },
      },
    }),
  });
  return response.status;
}

async function sha256(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function base64url(bytes) {
  return btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function apnsJWT(env) {
  const pem = env.APNS_KEY_P8.replace(/-----[^-]+-----|\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const enc = new TextEncoder();
  const header = base64url(enc.encode(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID })));
  const claims = base64url(enc.encode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) })));
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(`${header}.${claims}`));
  return `${header}.${claims}.${base64url(signature)}`;
}
