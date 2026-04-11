/**
 * PixelPal API — Cloudflare Workers + D1
 *
 * Three endpoints:
 * 1. POST /api/device    — register anonymous device
 * 2. PUT  /api/sync      — upload character discovery data
 * 3. GET  /api/sync      — download character discovery data
 *
 * No auth beyond device_id. No personal data. No analytics.
 */

interface Env {
  DB: D1Database;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers for macOS app
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, PUT, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Health check
      if (path === "/api/ping") {
        return json({ status: "ok" }, corsHeaders);
      }

      // Register device (anonymous)
      if (path === "/api/device" && request.method === "POST") {
        return await handleDeviceRegister(env, corsHeaders);
      }

      // Upload discoveries
      if (path === "/api/sync" && request.method === "PUT") {
        return await handleSyncUpload(request, env, corsHeaders);
      }

      // Download discoveries
      if (path === "/api/sync" && request.method === "GET") {
        return await handleSyncDownload(url, env, corsHeaders);
      }

      return json({ error: "not_found" }, corsHeaders, 404);
    } catch (e) {
      console.error(e);
      return json({ error: "internal_error" }, corsHeaders, 500);
    }
  },
};

async function handleDeviceRegister(
  env: Env,
  headers: Record<string, string>
): Promise<Response> {
  const deviceId = crypto.randomUUID();
  const now = new Date().toISOString();

  await env.DB.prepare(
    "INSERT INTO devices (device_id, created_at, last_sync) VALUES (?, ?, ?)"
  )
    .bind(deviceId, now, now)
    .run();

  return json({ device_id: deviceId }, headers);
}

async function handleSyncUpload(
  request: Request,
  env: Env,
  headers: Record<string, string>
): Promise<Response> {
  const body = (await request.json()) as {
    device_id: string;
    characters: string;
  };

  if (!body.device_id || !body.characters) {
    return json({ error: "invalid_request" }, headers, 400);
  }

  const now = new Date().toISOString();

  // Upsert: update if exists, insert if not
  await env.DB.prepare(
    `INSERT INTO sync_data (device_id, characters, updated_at)
     VALUES (?, ?, ?)
     ON CONFLICT(device_id) DO UPDATE SET characters = ?, updated_at = ?`
  )
    .bind(body.device_id, body.characters, now, body.characters, now)
    .run();

  // Update last_sync on device
  await env.DB.prepare(
    "UPDATE devices SET last_sync = ? WHERE device_id = ?"
  )
    .bind(now, body.device_id)
    .run();

  return json({ status: "ok" }, headers);
}

async function handleSyncDownload(
  url: URL,
  env: Env,
  headers: Record<string, string>
): Promise<Response> {
  const deviceId = url.searchParams.get("device_id");
  if (!deviceId) {
    return json({ error: "missing_device_id" }, headers, 400);
  }

  const result = await env.DB.prepare(
    "SELECT characters FROM sync_data WHERE device_id = ?"
  )
    .bind(deviceId)
    .first<{ characters: string }>();

  if (!result) {
    return json({ characters: [] }, headers);
  }

  try {
    const characters = JSON.parse(result.characters);
    return json({ characters }, headers);
  } catch {
    return json({ characters: [] }, headers);
  }
}

function json(
  data: unknown,
  extraHeaders: Record<string, string>,
  status = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}
