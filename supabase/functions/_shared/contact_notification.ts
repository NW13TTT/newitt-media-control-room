export const recipientSecretByArea: Record<string, string> = {
  'NEWITT Skyline Media': 'NEWITT_CONTACT_RECIPIENT_SKYLINE',
  "NEWITT's Paranormal Adventures": 'NEWITT_CONTACT_RECIPIENT_PARANORMAL',
  'NEWITT Media Photography': 'NEWITT_CONTACT_RECIPIENT_PHOTOGRAPHY',
};

export function recipientKeyForContact(domain: string, area: string): string | null {
  if (domain === 'essexparanormal.com') {
    return ['General enquiry', 'Investigation enquiry', 'Media enquiry'].includes(area)
      ? 'ESSEX_CONTACT_RECIPIENT'
      : null;
  }
  return recipientKeyForArea(area);
}

export type NotificationResult =
  | { kind: 'sent'; providerMessageId: string | null }
  | { kind: 'pending' }
  | { kind: 'failed'; failureCode: string };

export function recipientKeyForArea(area: string): string | null {
  return recipientSecretByArea[area] ?? null;
}

export async function sendResendNotification({
  apiKey,
  from,
  recipient,
  subject,
  text,
  fetcher = fetch,
}: {
  apiKey: string | undefined;
  from: string | undefined;
  recipient: string | undefined;
  subject: string;
  text: string;
  fetcher?: typeof fetch;
}): Promise<NotificationResult> {
  if (!apiKey || !from || !recipient) return { kind: 'pending' };

  try {
    const response = await fetcher('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from, to: [recipient], subject, text }),
    });
    if (!response.ok) return { kind: 'failed', failureCode: `RESEND_${response.status}` };
    const body = await response.json().catch(() => ({})) as { id?: unknown };
    return {
      kind: 'sent',
      providerMessageId: typeof body.id === 'string' ? body.id : null,
    };
  } catch (_) {
    return { kind: 'failed', failureCode: 'RESEND_NETWORK' };
  }
}