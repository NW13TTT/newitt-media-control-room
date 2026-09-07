import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  recipientKeyForArea,
  recipientKeyForContact,
  sendResendNotification,
} from "../_shared/contact_notification.ts";
import { parsePublicContactRequest } from "../_shared/contact_submission.ts";
import {
  boundedInteger,
  clientIp,
  clientKeyHash,
  configuredOrigins,
  corsHeaders,
  verifiesTurnstile,
} from "../_shared/public_contact_security.ts";

const publicContactDomains = new Set(["newittmedia.co.uk", "essexparanormal.com"]);

function reply(body: Record<string, unknown>, headers: HeadersInit, status = 200) {
  return new Response(JSON.stringify(body), { status, headers });
}

async function dispatchNotification(
  admin: ReturnType<typeof createClient>,
  notificationId: string,
  recipientKey: string,
) {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("RESEND_FROM_EMAIL");
  const recipient = Deno.env.get(recipientKey);
  if (!apiKey || !from || !recipient) return;

  const { data: claims, error: claimError } = await admin.rpc(
    "claim_contact_enquiry_notification",
    { p_notification_id: notificationId },
  );
  const claim = claims?.[0];
  if (claimError || !claim) return;

  const result = await sendResendNotification({
    apiKey,
    from,
    recipient,
    subject: `New ${claim.area} enquiry`,
    text: `Name: ${claim.name}\nEmail: ${claim.email}\n\n${claim.message}`,
  });
  if (result.kind === "pending") return;

  await admin.rpc("complete_contact_enquiry_notification", {
    p_notification_id: claim.notification_id,
    p_processing_token: claim.processing_token,
    p_sent: result.kind === "sent",
    p_provider_message_id: result.kind === "sent" ? result.providerMessageId : null,
    p_failure_code: result.kind === "failed" ? result.failureCode : null,
  });
}

Deno.serve(async (request) => {
  const headers = corsHeaders(
    request.headers.get("origin"),
    configuredOrigins(Deno.env.get("NEWITT_CONTACT_ALLOWED_ORIGINS")),
  );
  if (!headers) {
    return new Response(JSON.stringify({ error: "Contact service unavailable." }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") return reply({ error: "Method not allowed." }, headers, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const rateLimitSalt = Deno.env.get("CONTACT_RATE_LIMIT_SALT");
  const sourceIp = clientIp(request);
  if (!url || !key || !rateLimitSalt || !sourceIp) {
    return reply({ error: "Contact service unavailable." }, headers, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return reply({ error: "Invalid request." }, headers, 400);
  }
  const publicRequest = parsePublicContactRequest(body);
  if (!publicRequest) {
    return reply({ error: "Complete the contact form with valid details." }, headers, 400);
  }
  const { submission, turnstileToken } = publicRequest;
  const { domain, area, name, email, message } = submission;
  if (!publicContactDomains.has(domain)) {
    return reply({ error: "Contact form unavailable." }, headers, 404);
  }

  const isEssex = domain === "essexparanormal.com";
  const turnstileSecret = Deno.env.get(
    isEssex ? "ESSEX_TURNSTILE_SECRET_KEY" : "TURNSTILE_SECRET_KEY",
  );
  const turnstileHostname = Deno.env.get(
    isEssex ? "ESSEX_TURNSTILE_EXPECTED_HOSTNAME" : "TURNSTILE_EXPECTED_HOSTNAME",
  );
  if (!turnstileSecret || !turnstileHostname) {
    return reply({ error: "Contact service unavailable." }, headers, 503);
  }
  const turnstilePassed = await verifiesTurnstile({
    token: turnstileToken,
    secret: turnstileSecret,
    expectedHostname: turnstileHostname,
    ip: sourceIp,
  });
  if (!turnstilePassed) {
    return reply({ error: "Unable to verify your submission. Please try again." }, headers, 400);
  }

  const admin = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: website } = await admin
    .from("websites")
    .select("id, tenant_id, website_settings")
    .eq("domain", domain)
    .maybeSingle();
  if (!website) return reply({ error: "Contact form unavailable." }, headers, 404);

  const settings = (website.website_settings ?? {}) as Record<string, unknown>;
  const configuredAreas = Array.isArray(settings.contactAreas)
    ? settings.contactAreas.filter((item): item is string => typeof item === "string")
    : [];
  const recipientKey = recipientKeyForContact(domain, area);
  if (
    (configuredAreas.length > 0 && !configuredAreas.includes(area)) ||
    !recipientKey
  ) {
    return reply({ error: "Select a valid enquiry area." }, headers, 400);
  }

  const { data: rateLimitAccepted, error: rateLimitError } = await admin.rpc(
    "consume_contact_submission_rate_limit",
    {
      p_tenant_id: website.tenant_id,
      p_website_id: website.id,
      p_client_key_hash: await clientKeyHash(sourceIp, rateLimitSalt),
      p_limit: boundedInteger(Deno.env.get("CONTACT_RATE_LIMIT_MAX"), 5, 1, 20),
      p_window_seconds: boundedInteger(
        Deno.env.get("CONTACT_RATE_LIMIT_WINDOW_SECONDS"),
        3600,
        60,
        86400,
      ),
    },
  );
  if (rateLimitError) {
    console.error("Contact submission rate limiting failed.");
    return reply({ error: "Contact service unavailable." }, headers, 503);
  }
  if (rateLimitAccepted !== true) {
    return reply({ error: "Please try again later." }, headers, 429);
  }

  const { data: created, error } = await admin.rpc(
    "create_contact_enquiry_with_notification",
    {
      p_tenant_id: website.tenant_id,
      p_website_id: website.id,
      p_area: area,
      p_name: name,
      p_email: email,
      p_message: message,
      p_recipient_key: recipientKey,
    },
  );
  const notificationId = created?.[0]?.notification_id;
  if (error || typeof notificationId !== "string") {
    console.error("Contact enquiry persistence failed.");
    return reply({ error: "Your enquiry could not be sent. Please try again." }, headers, 503);
  }

  await dispatchNotification(admin, notificationId, recipientKey);
  return reply({ status: "received" }, headers, 201);
});
