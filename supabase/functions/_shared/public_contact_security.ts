export function configuredOrigins(value: string | undefined): Set<string> {
  return new Set(
    (value ?? '')
      .split(',')
      .map((origin) => origin.trim())
      .filter((origin) => origin.startsWith('https://') && !origin.includes('*')),
  );
}

export function corsHeaders(origin: string | null, allowedOrigins: Set<string>): HeadersInit | null {
  if (!origin || !allowedOrigins.has(origin)) return null;
  return {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  };
}

export function clientIp(request: Request): string | null {
  const cloudflareIp = request.headers.get('cf-connecting-ip')?.trim();
  if (cloudflareIp) return cloudflareIp;
  return request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || null;
}

export async function clientKeyHash(ip: string, salt: string): Promise<string> {
  const bytes = new TextEncoder().encode(`${salt}:${ip}`);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

export function boundedInteger(value: string | undefined, fallback: number, min: number, max: number): number {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isInteger(parsed) && parsed >= min && parsed <= max ? parsed : fallback;
}

export async function verifiesTurnstile({
  token,
  secret,
  expectedHostname,
  ip,
  fetcher = fetch,
}: {
  token: string;
  secret: string | undefined;
  expectedHostname: string | undefined;
  ip: string;
  fetcher?: typeof fetch;
}): Promise<boolean> {
  if (!secret || !expectedHostname) return false;
  try {
    const body = new URLSearchParams({ secret, response: token, remoteip: ip });
    const response = await fetcher('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    const result = await response.json() as { success?: unknown; hostname?: unknown };
    return result.success === true && result.hostname === expectedHostname;
  } catch (_) {
    return false;
  }
}