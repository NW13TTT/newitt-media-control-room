import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const bucket = "website-media";
const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const reply = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

const retryReply = () =>
  reply(
    {
      status: "reconciliation_required",
      message: "Media removal could not be completed. Refresh the library before retrying.",
    },
    503,
  );

function validPath(path: string, tenantId: string, websiteId: string) {
  const segments = path.split("/");
  return (
    segments.length >= 3 &&
    segments[0] === tenantId &&
    segments[1] === websiteId &&
    segments.every((segment) => segment.length > 0 && segment !== "." && segment !== "..")
  );
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") return reply({ error: "Method not allowed." }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return reply({ error: "Authentication is required." }, 401);
  }

  let mediaId: unknown;
  try {
    ({ mediaId } = await request.json());
  } catch (_) {
    return reply({ error: "Invalid request." }, 400);
  }
  if (typeof mediaId !== "string" || !uuidPattern.test(mediaId)) {
    return reply({ error: "Invalid request." }, 400);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !serviceRoleKey || !anonKey) return reply({ error: "Service unavailable." }, 503);

  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData } = await callerClient.auth.getUser();
  if (!userData.user) return reply({ error: "Authentication is required." }, 401);

  const admin = createClient(url, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: profile } = await admin
    .from("profiles")
    .select("id, tenant_id, role")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (!profile) return reply({ error: "You are not authorised to remove this media." }, 403);
  if (profile.role === "MASTER_ADMIN") return reply({ error: "You are not authorised to remove this media." }, 403);

  const { data: media } = await admin
    .from("media")
    .select("id, tenant_id, website_id, storage_path")
    .eq("id", mediaId)
    .maybeSingle();
  if (!media) return reply({ error: "Media was not found." }, 404);

  const { data: website } = await admin
    .from("websites")
    .select("id, tenant_id")
    .eq("id", media.website_id)
    .maybeSingle();
  if (
    !website ||
    media.tenant_id !== profile.tenant_id ||
    website.tenant_id !== profile.tenant_id ||
    !validPath(media.storage_path, profile.tenant_id, media.website_id)
  ) return reply({ error: "You are not authorised to remove this media." }, 403);

  try {
    const { error: storageError } = await admin.storage.from(bucket).remove([media.storage_path]);
    // Supabase Storage delete is idempotent: absent objects do not require a separate error path.
    if (storageError) return retryReply();

    const { error: databaseError } = await admin.from("media").delete().eq("id", media.id);
    if (databaseError) {
      await admin.from("audit_logs").insert({
        actor_id: profile.id,
        tenant_id: profile.tenant_id,
        website_id: media.website_id,
        action: "MEDIA_STORAGE_DELETED_DATABASE_PENDING",
        resource_type: "media",
        resource_id: media.id,
        metadata: { storage_deleted: true },
      });
      return retryReply();
    }
    await admin.from("audit_logs").insert({
      actor_id: profile.id,
      tenant_id: profile.tenant_id,
      website_id: media.website_id,
      action: "MEDIA_DELETED",
      resource_type: "media",
      resource_id: media.id,
      metadata: { storage_deleted: true },
    });
    return reply({ status: "deleted", mediaId: media.id });
  } catch (_) {
    return reply({ status: "unknown_state", message: "Media removal status is unknown. Refresh the library before retrying." }, 503);
  }
});