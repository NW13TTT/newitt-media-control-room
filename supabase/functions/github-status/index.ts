import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const headers = { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const reply = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), { status, headers });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") return reply({ error: "Method not allowed." }, 405);
  const authorization = request.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!authorization?.startsWith("Bearer ") || !url || !anonKey || !serviceKey) return reply({ error: "Service unavailable." }, 503);
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data } = await caller.auth.getUser();
  if (!data.user) return reply({ error: "Authentication is required." }, 401);
  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: profile } = await admin.from("profiles").select("id").eq("id", data.user.id).eq("role", "MASTER_ADMIN").maybeSingle();
  if (!profile) return reply({ error: "Master Admin access is required." }, 403);
  const configured = Boolean(Deno.env.get("GITHUB_APP_ID") && Deno.env.get("GITHUB_APP_PRIVATE_KEY"));
  return reply({ status: configured ? "ready_for_installation" : "not_configured", message: configured ? "GitHub App installation is required." : "GitHub App credentials have not been configured." });
});
