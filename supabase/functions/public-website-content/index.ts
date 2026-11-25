import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  parsePublicWebsiteContentRequest,
  publicWebsiteContentResponse,
} from "../_shared/public_website_content.ts";
import {
  configuredOrigins,
  corsHeaders,
} from "../_shared/public_contact_security.ts";

function reply(body: Record<string, unknown>, headers: HeadersInit, status = 200) {
  return new Response(JSON.stringify(body), { status, headers });
}

async function signedPublishedMedia(
  serviceRoleKey: string | undefined,
  url: string,
  media: unknown,
  domain: string,
) {
  if (!serviceRoleKey || !Array.isArray(media) || media.length === 0) return [];
  const ids = media
    .map((item) => item && typeof item === "object" ? (item as Record<string, unknown>).id : null)
    .filter((id): id is string => typeof id === "string");
  if (ids.length === 0) return [];

  const storage = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: website } = await storage.from("websites")
    .select("id, tenant_id")
    .eq("domain", domain)
    .in("site_lifecycle", ["APPROVED", "PUBLISHED"])
    .maybeSingle();
  if (!website) return [];
  const { data } = await storage
    .from("media")
    .select("id, storage_path, title, metadata")
    .in("id", ids)
    .eq("website_id", website.id)
    .eq("tenant_id", website.tenant_id)
    .eq("metadata->>published", "true");
  if (!data) return [];

  return Promise.all(data.map(async (item) => {
    const metadata = item.metadata && typeof item.metadata === "object" ? item.metadata : {};
    const type = typeof (metadata as Record<string, unknown>).type === "string"
      ? (metadata as Record<string, unknown>).type
      : "";
    if (!/^(image|video|audio)\//.test(type)) return { id: item.id, title: item.title, metadata };
    const path = item.storage_path?.split("/") ?? [];
    if ((metadata as Record<string, unknown>).storage_provider === "r2" ||
        path[0] !== website.tenant_id || path[1] !== website.id ||
        path.length < 3 || path.some((part: string) => !part || part === "." || part === "..")) {
      return { id: item.id, title: item.title, metadata, signedUrl: null };
    }
    const bucket = storage.storage.from("website-media");
    const canOptimise = /^image\/(jpeg|png|webp)$/.test(type);
    const { data: resized } = canOptimise
      ? await bucket.createSignedUrl(item.storage_path, 900, {
          transform: { width: 1440, resize: "contain", quality: 82 },
        })
      : { data: null };
    const signed = resized ?? (await bucket.createSignedUrl(item.storage_path, 900)).data;
    return {
      id: item.id,
      title: item.title,
      metadata,
      signedUrl: signed?.signedUrl ?? null,
    };
  }));
}

Deno.serve(async (request) => {
  const headers = corsHeaders(
    request.headers.get("origin"),
    configuredOrigins(Deno.env.get("NEWITT_PUBLIC_CONTENT_ALLOWED_ORIGINS")),
  );
  if (!headers) {
    return new Response(JSON.stringify({ error: "Website content unavailable." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") return reply({ error: "Method not allowed." }, headers, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key) return reply({ error: "Website content unavailable." }, headers, 503);

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return reply({ error: "Invalid request." }, headers, 400);
  }
  const domain = parsePublicWebsiteContentRequest(body);
  if (!domain) return reply({ error: "Website content unavailable." }, headers, 404);

  const admin = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: payload, error } = await admin.rpc(
    "get_public_website_content_payload",
    { requested_domain: domain },
  );
  if (error || !payload || typeof payload !== "object") {
    return reply({ error: "Website content unavailable." }, headers, 404);
  }
  const content = payload as Record<string, unknown>;
  const signedMedia = await signedPublishedMedia(
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    url,
    content.media,
    domain,
  );
  return reply(publicWebsiteContentResponse({
    website: content.website ?? {},
    content: Array.isArray(content.content) ? content.content : [],
    pages: Array.isArray(content.pages) ? content.pages : [],
    socialLinks: Array.isArray(content.social_links)
      ? content.social_links
      : [],
    media: signedMedia,
  }), headers);
});
