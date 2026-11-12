const MAX_BYTES = 50 * 1024 * 1024;
const UUID = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

function imageType(bytes) {
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return "image/jpeg";
  if ([137, 80, 78, 71, 13, 10, 26, 10].every((byte, i) => bytes[i] === byte)) {
    return "image/png";
  }
  if (bytes.length >= 16) {
    const header = new TextDecoder().decode(bytes.subarray(4, 32));
    if (header.startsWith("ftyp") && /heic|heix|hevc|hevx|mif1|msf1/.test(header)) {
      return "image/heif";
    }
  }
  return null;
}

function json(data, status) {
  return Response.json(data, { status, headers: { "Cache-Control": "no-store" } });
}

export async function uploadWebsitePhoto(request, env) {
  if (request.method !== "POST") return json({ error: "Use POST to upload a photo." }, 405);
  if (!env.WEBSITE_MEDIA || !env.IMAGES || !env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
    return json({ error: "Photo uploads are unavailable." }, 503);
  }
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "Sign in to upload." }, 401);
  const websiteId = request.headers.get("X-Website-Id");
  if (!UUID.test(websiteId ?? "")) return json({ error: "Choose a website." }, 400);
  const headers = { Authorization: authorization, apikey: env.SUPABASE_PUBLISHABLE_KEY };
  const supabase = new URL(env.SUPABASE_URL);
  const user = await fetch(new URL("/auth/v1/user", supabase), { headers });
  if (!user.ok) return json({ error: "Sign in again to upload." }, 401);

  // The caller's token applies the websites and media RLS policies.
  const profileLookup = new URL("/rest/v1/rpc/current_tenant_id", supabase);
  const profileResponse = await fetch(profileLookup, { headers });
  if (!profileResponse.ok) return json({ error: "Could not verify your tenant." }, 403);
  const tenantId = await profileResponse.json();
  const lookup = new URL("/rest/v1/websites", supabase);
  lookup.search = new URLSearchParams({ id: "eq." + websiteId, select: "id,tenant_id" });
  const websiteResponse = await fetch(lookup, { headers });
  if (!websiteResponse.ok) return json({ error: "Could not check website access." }, 503);
  const [website] = await websiteResponse.json();
  if (!website || !UUID.test(tenantId ?? "") || website.tenant_id !== tenantId) {
    return json({ error: "You cannot upload to this website." }, 403);
  }

  const length = Number(request.headers.get("Content-Length"));
  if (!Number.isSafeInteger(length) || length < 1 || length > MAX_BYTES || !request.body) {
    return json({ error: "Choose a photo up to 50 MB." }, 413);
  }
  const reader = request.body.getReader();
  const bytes = new Uint8Array(length);
  let offset = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      if (offset + value.length > length) {
        await reader.cancel();
        return json({ error: "The photo is larger than expected." }, 413);
      }
      bytes.set(value, offset);
      offset += value.length;
    }
  } finally {
    reader.releaseLock();
  }
  if (offset !== length || !imageType(bytes)) {
    return json({ error: "Choose a valid JPEG, PNG, HEIC or HEIF photo." }, 415);
  }

  let image;
  try {
    image = await env.IMAGES.input(new Blob([bytes]).stream())
      .output({ format: "image/webp" });
  } catch {
    return json({ error: "The photo could not be decoded. Try exporting it as JPEG." }, 422);
  }
  const path = website.tenant_id + "/" + website.id + "/" + crypto.randomUUID() + ".webp";
  const converted = image.response();
  if (!converted.ok || !converted.body) return json({ error: "Photo conversion failed." }, 422);
  await env.WEBSITE_MEDIA.put(path, converted.body, {
    httpMetadata: { contentType: "image/webp" },
  });

  const record = await fetch(new URL("/rest/v1/media", supabase), {
    method: "POST",
    headers: { ...headers, "Content-Type": "application/json" },
    body: JSON.stringify({
      tenant_id: website.tenant_id,
      website_id: website.id,
      storage_path: path,
      title: (request.headers.get("X-Photo-Name") || "Photo").slice(0, 200),
      metadata: { type: "image/webp", storage_provider: "r2" },
    }),
  });
  if (!record.ok) {
    await env.WEBSITE_MEDIA.delete(path);
    return json({ error: "Could not add the photo to the media library." }, 403);
  }
  return json({ path }, 201);
}
