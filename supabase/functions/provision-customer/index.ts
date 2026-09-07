import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ProvisionCustomerRequest = {
  organizationName?: unknown;
  accountSlug?: unknown;
  contactName?: unknown;
  contactEmail?: unknown;
  websiteName?: unknown;
  websiteDomain?: unknown;
  websiteSettings?: unknown;
};

const jsonHeaders = { "Content-Type": "application/json" };
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const domainPattern = /^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$/i;

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...corsHeaders },
  });
}

function requestValue(value: unknown, maximumLength: number) {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= maximumLength
    ? value.trim()
    : null;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return response({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return response({ error: "Authentication is required." }, 401);
  }

  let payload: ProvisionCustomerRequest;
  try {
    payload = await request.json();
  } catch (_) {
    return response({ error: "Invalid request." }, 400);
  }

  const organizationName = requestValue(payload.organizationName, 160);
  const accountSlug = requestValue(payload.accountSlug, 80)?.toLowerCase();
  const contactName = requestValue(payload.contactName, 160);
  const contactEmail = requestValue(payload.contactEmail, 254)?.toLowerCase();
  const websiteName = requestValue(payload.websiteName, 160);
  const websiteDomain = requestValue(payload.websiteDomain, 255)?.toLowerCase();
  const websiteSettings = payload.websiteSettings && typeof payload.websiteSettings === "object"
    ? payload.websiteSettings as Record<string, unknown>
    : {};
  if (
    organizationName === null ||
    contactName === null ||
    accountSlug === null ||
    contactEmail === null ||
    !slugPattern.test(accountSlug) ||
    !emailPattern.test(contactEmail) ||
    ((websiteName === null) !== (websiteDomain === null)) ||
    (websiteDomain !== null && !domainPattern.test(websiteDomain))
  ) {
    return response({ error: "Enter valid customer details." }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Provisioning function is not configured.");
    return response({ error: "Provisioning is temporarily unavailable." }, 503);
  }

  const callerClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authorization } },
  });
  const { data: callerData } = await callerClient.auth.getUser();
  const caller = callerData.user;
  if (!caller) {
    return response({ error: "Authentication is required." }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: callerProfile } = await adminClient
    .from("profiles")
    .select("id")
    .eq("id", caller.id)
    .eq("role", "MASTER_ADMIN")
    .maybeSingle();
  if (!callerProfile) {
    return response({ error: "You are not authorised to provision customers." }, 403);
  }

  let tenantId: string | null = null;
  let invitedUserId: string | null = null;
  let websiteId: string | null = null;
  try {
    const { data: customer, error: customerError } = await adminClient
      .from("customer_accounts")
      .insert({ name: organizationName, slug: accountSlug })
      .select("id, name, slug, created_at")
      .single();
    if (customerError || !customer) {
      return response({ error: "A matching customer account already exists or cannot be provisioned." }, 409);
    }
    tenantId = customer.id;

    if (websiteName !== null && websiteDomain !== null) {
      const { data: website, error: websiteError } = await adminClient
        .from("websites")
        .insert({
          tenant_id: tenantId,
          name: websiteName,
          domain: websiteDomain,
          website_type: "CUSTOMER",
          website_settings: websiteSettings,
        })
        .select("id")
        .single();
      if (websiteError || !website) {
        await adminClient.from("customer_accounts").delete().eq("id", tenantId);
        return response({ error: "A matching website already exists or cannot be provisioned." }, 409);
      }
      websiteId = website.id;
    }

    const { data: invitation, error: invitationError } = await adminClient.auth.admin.inviteUserByEmail(
      contactEmail,
      { data: { display_name: contactName } },
    );
    if (invitationError || !invitation.user) {
      await adminClient.from("customer_accounts").delete().eq("id", tenantId);
      return response({ error: "A matching customer account already exists or cannot be provisioned." }, 409);
    }
    invitedUserId = invitation.user.id;

    const { error: profileError } = await adminClient.from("profiles").insert({
      id: invitedUserId,
      tenant_id: tenantId,
      display_name: contactName,
      email: contactEmail,
      role: "CUSTOMER",
    });
    if (profileError) {
      await adminClient.auth.admin.deleteUser(invitedUserId);
      await adminClient.from("customer_accounts").delete().eq("id", tenantId);
      return response({ error: "A matching customer account already exists or cannot be provisioned." }, 409);
    }

    const { error: auditError } = await adminClient.from("audit_logs").insert({
      actor_id: caller.id,
      tenant_id: tenantId,
      action: "CUSTOMER_INVITED",
      resource_type: "customer_account",
      resource_id: tenantId,
      website_id: websiteId,
      metadata: { website_created: websiteId !== null },
    });
    if (auditError) {
      await adminClient.auth.admin.deleteUser(invitedUserId);
      await adminClient.from("customer_accounts").delete().eq("id", tenantId);
      return response({ error: "Provisioning is temporarily unavailable." }, 503);
    }

    return response({
      customer: {
        id: customer.id,
        name: customer.name,
        slug: customer.slug,
        createdAt: customer.created_at,
      },
      invitation: { email: contactEmail },
    }, 201);
  } catch (error) {
    console.error("Customer provisioning failed.", error);
    if (invitedUserId) await adminClient.auth.admin.deleteUser(invitedUserId);
    if (tenantId) await adminClient.from("customer_accounts").delete().eq("id", tenantId);
    return response({ error: "Provisioning is temporarily unavailable." }, 503);
  }
});