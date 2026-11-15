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

function photoName(request) {
  try {
    return decodeURIComponent(request.headers.get("X-Photo-Name") || "Photo");
  } catch {
    return "Photo";
  }
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
  const profileResponse = await fetch(profileLookup, {
    method: "POST",
    headers: { ...headers, "Content-Type": "application/json" },
    body: "{}",
  });
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

  const declaredLength = request.headers.get("Content-Length");
  const length = declaredLength === null ? null : Number(declaredLength);
  if (!request.body || (length !== null &&
      (!Number.isSafeInteger(length) || length < 1 || length > MAX_BYTES))) {
    return json({ error: "Choose a photo up to 50 MB." }, 413);
  }
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > MAX_BYTES || (length !== null && size > length)) {
        await reader.cancel();
        return json({ error: "The photo is larger than expected." }, 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const photo = new Blob(chunks);
  const header = new Uint8Array(await photo.slice(0, 32).arrayBuffer());
  if ((length !== null && size !== length) || !imageType(header)) {
    return json({ error: "Choose a valid JPEG, PNG, HEIC or HEIF photo." }, 415);
  }

  let image;
  try {
    image = await env.IMAGES.input(photo.stream())
      .output({ format: "image/webp" });
  } catch {
    return json({ error: "The photo could not be decoded. Try exporting it as JPEG." }, 422);
  }
  const mediaId = crypto.randomUUID();
  const path = website.tenant_id + "/" + website.id + "/" + mediaId + ".webp";
  const converted = image.response();
  if (!converted.ok || !converted.body) return json({ error: "Photo conversion failed." }, 422);
  await env.WEBSITE_MEDIA.put(path, converted.body, {
    httpMetadata: { contentType: "image/webp" },
  });

  const record = await fetch(new URL("/rest/v1/media", supabase), {
    method: "POST",
    headers: { ...headers, "Content-Type": "application/json" },
    body: JSON.stringify({
      id: mediaId,
      tenant_id: website.tenant_id,
      website_id: website.id,
      storage_path: path,
      title: photoName(request),
      metadata: { type: "image/webp", storage_provider: "r2" },
    }),
  });
  if (!record.ok) {
    await env.WEBSITE_MEDIA.delete(path);
    return json({ error: "Could not add the photo to the media library." }, 403);
  }
  return json({ path }, 201);
}

export async function websitePhoto(request, env, mediaId) {
  if (!env.WEBSITE_MEDIA || !env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
    return json({ error: "Photos are unavailable." }, 503);
  }
  if (!UUID.test(mediaId)) return json({ error: "Photo not found." }, 404);
  const url = new URL(request.url);
  const domain = url.searchParams.get("domain");
  const authorization = request.headers.get("Authorization");
  const headers = { apikey: env.SUPABASE_PUBLISHABLE_KEY };
  if (domain === null && !authorization?.startsWith("Bearer ")) {
    return json({ error: "Sign in to access this photo." }, 401);
  }
  if (domain !== null && request.method !== "GET") {
    return json({ error: "Method not allowed." }, 405);
  }
  if (!["GET", "DELETE"].includes(request.method)) {
    return json({ error: "Method not allowed." }, 405);
  }

  const supabase = new URL(env.SUPABASE_URL);
  const lookup = new URL("/rest/v1/media", supabase);
  lookup.search = new URLSearchParams({
    id: "eq." + mediaId, select: "storage_path,tenant_id,website_id,metadata",
  });
  let media;
  if (domain !== null) {
    const published = await fetch(new URL("/rest/v1/rpc/get_published_r2_photo", supabase), {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ requested_domain: domain, requested_media_id: mediaId }),
    });
    if (!published.ok) return json({ error: "Photo unavailable." }, 503);
    media = await published.json();
  } else {
    headers.Authorization = authorization;
    const response = await fetch(lookup, { headers });
    if (response.status === 401) return json({ error: "Sign in again." }, 401);
    if (!response.ok) return json({ error: "Photo unavailable." }, 503);
    [media] = await response.json();
  }
  const path = media?.storage_path?.split("/");
  if (media?.metadata?.storage_provider !== "r2" || path?.length !== 3 ||
      path[0] !== media.tenant_id || path[1] !== media.website_id ||
      path[2] !== mediaId + ".webp") {
    return json({ error: "Photo not found." }, 404);
  }
  if (request.method === "DELETE") {
    const tenant = await fetch(new URL("/rest/v1/rpc/current_tenant_id", supabase), {
      method: "POST", headers: { ...headers, "Content-Type": "application/json" }, body: "{}",
    });
    if (!tenant.ok || await tenant.json() !== media.tenant_id) {
      return json({ error: "Photo not found." }, 404);
    }
    // Keep the row available for retry if object removal fails.
    await env.WEBSITE_MEDIA.delete(media.storage_path);
    lookup.searchParams.set("select", "id");
    headers.Prefer = "return=representation";
    lookup.searchParams.set("storage_path", "eq." + media.storage_path);
    const deleted = await fetch(lookup, { method: "DELETE", headers });
    return deleted.ok && (await deleted.json()).length === 1 ? new Response(null, { status: 204 })
      : json({ error: "Refresh the library and retry removal." }, 503);
  }
  const object = await env.WEBSITE_MEDIA.get(media.storage_path);
  if (!object) return json({ error: "Photo not found." }, 404);
  return new Response(object.body, {
    headers: {
      "Content-Type": "image/webp",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
