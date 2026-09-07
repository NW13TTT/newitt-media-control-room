import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Action = "list_users" | "invite_user" | "set_status";

const jsonHeaders = { "Content-Type": "application/json" };
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...corsHeaders },
  });
}

function text(value: unknown, maxLength: number) {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= maxLength
    ? value.trim()
    : null;
}

function safeStatus(user: Record<string, unknown>) {
  const bannedUntil = typeof user.banned_until === "string" ? user.banned_until : null;
  const disabled = bannedUntil !== null && new Date(bannedUntil).getTime() > Date.now();
  const active = user.email_confirmed_at !== null || user.last_sign_in_at !== null;
  return disabled ? "DISABLED" : active ? "ACTIVE" : "INVITED";
}

function safeUser(profile: Record<string, unknown>, authUser: Record<string, unknown>) {
  return {
    email: profile.email,
    displayName: profile.display_name,
    role: profile.role,
    status: safeStatus(authUser),
    createdAt: profile.created_at,
    lastActiveAt: authUser.last_sign_in_at,
  };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ error: "Method not allowed." }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return response({ error: "Authentication is required." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Customer account function is not configured.");
    return response({ error: "Customer account management is temporarily unavailable." }, 503);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch (_) {
    return response({ error: "Invalid request." }, 400);
  }

  const action = text(payload.action, 40) as Action | null;
  const customerId = text(payload.customerId, 80);
  if (!action || !customerId || !["list_users", "invite_user", "set_status"].includes(action)) {
    return response({ error: "Invalid customer account request." }, 400);
  }

  const callerClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authorization } },
  });
  const { data: callerData } = await callerClient.auth.getUser();
  const caller = callerData.user;
  if (!caller) return response({ error: "Authentication is required." }, 401);

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: callerProfile } = await adminClient
    .from("profiles")
    .select("id")
    .eq("id", caller.id)
    .eq("role", "MASTER_ADMIN")
    .maybeSingle();
  if (!callerProfile) return response({ error: "You are not authorised to manage customer users." }, 403);

  const { data: customer } = await adminClient
    .from("customer_accounts")
    .select("id")
    .eq("id", customerId)
    .maybeSingle();
  if (!customer) return response({ error: "Customer account not found." }, 404);

  try {
    if (action === "invite_user") {
      const email = text(payload.email, 254)?.toLowerCase();
      const displayName = text(payload.displayName, 160);
      if (!email || !displayName || !emailPattern.test(email)) {
        return response({ error: "Enter a valid customer email and name." }, 400);
      }

      const { data: existingProfile } = await adminClient
        .from("profiles")
        .select("id")
        .eq("email", email)
        .maybeSingle();
      if (existingProfile) return response({ error: "A customer user with this email already exists." }, 409);

      const { data: invitation, error: invitationError } = await adminClient.auth.admin.inviteUserByEmail(
        email,
        { data: { display_name: displayName } },
      );
      if (invitationError || !invitation.user) {
        return response({ error: "The invitation could not be created." }, 409);
      }

      const { data: profile, error: profileError } = await adminClient
        .from("profiles")
        .insert({
          id: invitation.user.id,
          tenant_id: customerId,
          display_name: displayName,
          email,
          role: "CUSTOMER",
        })
        .select("email, display_name, role, created_at")
        .single();
      if (profileError || !profile) {
        await adminClient.auth.admin.deleteUser(invitation.user.id);
        return response({ error: "The invitation could not be completed." }, 409);
      }

      await adminClient.from("audit_logs").insert({
        actor_id: caller.id,
        tenant_id: customerId,
        action: "CUSTOMER_USER_INVITED",
        resource_type: "customer_user",
        resource_id: invitation.user.id,
        metadata: {},
      });
      return response({ user: safeUser(profile, invitation.user) }, 201);
    }

    const { data: profiles, error: profilesError } = await adminClient
      .from("profiles")
      .select("id, email, display_name, role, created_at")
      .eq("tenant_id", customerId)
      .eq("role", "CUSTOMER")
      .order("created_at");
    if (profilesError) return response({ error: "Customer users could not be loaded." }, 503);

    if (action === "list_users") {
      const users = [];
      for (const profile of profiles ?? []) {
        const { data: authUser, error: authError } = await adminClient.auth.admin.getUserById(profile.id);
        if (!authError && authUser.user) users.push(safeUser(profile, authUser.user));
      }
      return response({ users });
    }

    const email = text(payload.email, 254)?.toLowerCase();
    const disabled = payload.disabled === true;
    const profile = (profiles ?? []).find((item) => item.email === email);
    if (!email || !profile) return response({ error: "Customer user not found." }, 404);

    const { data: updated, error: updateError } = await adminClient.auth.admin.updateUserById(
      profile.id,
      { ban_duration: disabled ? "876000h" : "none" },
    );
    if (updateError || !updated.user) return response({ error: "Customer access could not be updated." }, 503);

    await adminClient.from("audit_logs").insert({
      actor_id: caller.id,
      tenant_id: customerId,
      action: disabled ? "CUSTOMER_USER_DISABLED" : "CUSTOMER_USER_ENABLED",
      resource_type: "customer_user",
      resource_id: profile.id,
      metadata: {},
    });
    return response({ user: safeUser(profile, updated.user) });
  } catch (error) {
    console.error("Customer account management failed.", error);
    return response({ error: "Customer account management is temporarily unavailable." }, 503);
  }
});
