const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export type ContactSubmission = {
  domain: string;
  area: string;
  name: string;
  email: string;
  message: string;
};

export type PublicContactRequest = {
  submission: ContactSubmission;
  turnstileToken: string;
};

const allowedPublicKeys = new Set([
  'domain',
  'area',
  'name',
  'email',
  'message',
  'turnstileToken',
]);

function value(input: unknown, max: number): string | null {
  return typeof input === 'string' && input.trim().length > 0 && input.trim().length <= max
    ? input.trim()
    : null;
}

export function parseContactSubmission(input: Record<string, unknown>): ContactSubmission | null {
  const domain = value(input.domain, 255)?.toLowerCase();
  const area = value(input.area, 120);
  const name = value(input.name, 160);
  const email = value(input.email, 254)?.toLowerCase();
  const message = value(input.message, 5000);
  if (!domain || !area || !name || !email || !message || !emailPattern.test(email)) {
    return null;
  }
  return { domain, area, name, email, message };
}

export function parsePublicContactRequest(input: Record<string, unknown>): PublicContactRequest | null {
  if (Object.keys(input).some((key) => !allowedPublicKeys.has(key))) return null;
  const submission = parseContactSubmission(input);
  const turnstileToken = value(input.turnstileToken, 2048);
  return submission && turnstileToken ? { submission, turnstileToken } : null;
}