import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { recipientKeyForArea, sendResendNotification } from "./contact_notification.ts";
import { parseContactSubmission, parsePublicContactRequest } from "./contact_submission.ts";
import {
  boundedInteger,
  clientKeyHash,
  configuredOrigins,
  corsHeaders,
  verifiesTurnstile,
} from "./public_contact_security.ts";
import {
  parsePublicWebsiteContentRequest,
  publicWebsiteContentResponse,
} from "./public_website_content.ts";

const validSubmission = {
  domain: 'newittmedia.co.uk',
  area: 'NEWITT Skyline Media',
  name: 'Visitor',
  email: 'visitor@example.com',
  message: 'Hello',
};

Deno.test('accepts only a complete public contact payload', () => {
  assertEquals(parseContactSubmission(validSubmission), validSubmission);
  assertEquals(parseContactSubmission({ ...validSubmission, email: 'invalid' }), null);
  assertEquals(parseContactSubmission({ ...validSubmission, message: '' }), null);
  assertEquals(parsePublicContactRequest({ ...validSubmission, turnstileToken: 'token' }), {
    submission: validSubmission,
    turnstileToken: 'token',
  });
  assertEquals(parsePublicContactRequest(validSubmission), null);
});

Deno.test('rejects recipient, tenant, and website fields from the browser', () => {
  const parsed = parsePublicContactRequest({
    ...validSubmission,
    turnstileToken: 'token',
    recipient: 'not-used@example.com',
    tenant_id: 'not-used',
    website_id: 'not-used',
  });
  assertEquals(parsed, null);
});

Deno.test('allows only explicit configured HTTPS origins', () => {
  const origins = configuredOrigins('https://staging.newittmedia.co.uk, https://www.newittmedia.co.uk, *');
  assertEquals(corsHeaders('https://staging.newittmedia.co.uk', origins), {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': 'https://staging.newittmedia.co.uk',
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  });
  assertEquals(corsHeaders('https://untrusted.example', origins), null);
});

Deno.test('accepts only the NEWITT domain for public website content', () => {
  assertEquals(parsePublicWebsiteContentRequest({ domain: 'newittmedia.co.uk' }), 'newittmedia.co.uk');
  assertEquals(parsePublicWebsiteContentRequest({ domain: 'essexparanormal.com' }), null);
  assertEquals(parsePublicWebsiteContentRequest({ domain: 'newittmedia.co.uk', tenant_id: 'override' }), null);
});

Deno.test('returns only published public content without private website fields', () => {
  const response = publicWebsiteContentResponse({
    website: {
      name: 'NEWITT Media',
      domain: 'newittmedia.co.uk',
      website_settings: {
        tagline: 'Approved tagline',
        contactAreas: ['NEWITT Skyline Media'],
        internalNotes: 'private',
        tenant_id: 'private',
      },
    },
    content: [
      { content_key: 'published', content: { title: 'Approved', internalNotes: 'private' }, updated_at: '2026-09-05', content_status: 'PUBLISHED' },
      { content_key: 'draft', content: { title: 'Draft' }, updated_at: '2026-09-05', content_status: 'DRAFT' },
    ],
    pages: [
      { title: 'Home', slug: 'home', page_type: 'HOME', visibility: true, sort_order: 1, published: true },
      { title: 'Hidden', slug: 'hidden', page_type: 'PAGE', visibility: false, sort_order: 2, published: true },
    ],
    socialLinks: [{ platform: 'TikTok', url: 'https://example.com' }],
  });
  assertEquals(response.website.settings, {
    tagline: 'Approved tagline',
    contactAreas: ['NEWITT Skyline Media'],
  });
  assertEquals(response.content.map((entry) => entry.contentKey), ['published']);
  assertEquals(response.content[0].content, { title: 'Approved' });
  assertEquals(response.pages.map((entry) => entry.slug), ['home']);
  assertEquals('tenant_id' in response.website, false);
  assertEquals('internalNotes' in response.website.settings, false);
});

Deno.test('verifies a mocked Turnstile response and expected hostname', async () => {
  const fetcher: typeof fetch = async () => new Response(
    JSON.stringify({ success: true, hostname: 'staging.newittmedia.co.uk' }),
  );
  assertEquals(await verifiesTurnstile({
    token: 'test-token',
    secret: 'test-secret',
    expectedHostname: 'staging.newittmedia.co.uk',
    ip: '203.0.113.8',
    fetcher,
  }), true);
  assertEquals(await verifiesTurnstile({
    token: 'test-token',
    secret: 'test-secret',
    expectedHostname: 'www.newittmedia.co.uk',
    ip: '203.0.113.8',
    fetcher,
  }), false);
});

Deno.test('derives a stable salted client key and bounds rate-limit settings', async () => {
  assertEquals(
    await clientKeyHash('203.0.113.8', 'staging-salt'),
    await clientKeyHash('203.0.113.8', 'staging-salt'),
  );
  assertEquals(boundedInteger('6', 5, 1, 20), 6);
  assertEquals(boundedInteger('500', 5, 1, 20), 5);
});

Deno.test('maps only approved NEWITT areas to server-side secret names', () => {
  assertEquals(recipientKeyForArea('NEWITT Skyline Media'), 'NEWITT_CONTACT_RECIPIENT_SKYLINE');
  assertEquals(recipientKeyForArea("NEWITT's Paranormal Adventures"), 'NEWITT_CONTACT_RECIPIENT_PARANORMAL');
  assertEquals(recipientKeyForArea('NEWITT Media Photography'), 'NEWITT_CONTACT_RECIPIENT_PHOTOGRAPHY');
  assertEquals(recipientKeyForArea('Unapproved area'), null);
});

Deno.test('leaves delivery pending without server-side email configuration', async () => {
  const result = await sendResendNotification({
    apiKey: undefined,
    from: undefined,
    recipient: undefined,
    subject: 'Test',
    text: 'Test',
  });
  assertEquals(result, { kind: 'pending' });
});

Deno.test('records mocked provider success without exposing the recipient', async () => {
  const result = await sendResendNotification({
    apiKey: 'test-key',
    from: 'sender@example.com',
    recipient: 'recipient@example.com',
    subject: 'Test',
    text: 'Test',
    fetcher: async () => new Response(JSON.stringify({ id: 'provider-id' }), { status: 200 }),
  });
  assertEquals(result, { kind: 'sent', providerMessageId: 'provider-id' });
});

Deno.test('classifies mocked provider failure without returning provider details', async () => {
  const result = await sendResendNotification({
    apiKey: 'test-key',
    from: 'sender@example.com',
    recipient: 'recipient@example.com',
    subject: 'Test',
    text: 'Test',
    fetcher: async () => new Response('unavailable', { status: 503 }),
  });
  assertEquals(result, { kind: 'failed', failureCode: 'RESEND_503' });
});