const publicWebsiteDomains = new Set([
  'newittmedia.co.uk',
  'essexparanormal.com',
]);

type WebsiteRow = {
  name: unknown;
  domain: unknown;
  website_settings: unknown;
};

type ContentRow = {
  content_key: unknown;
  content: unknown;
  updated_at: unknown;
  content_status?: unknown;
};

type PageRow = {
  title: unknown;
  slug: unknown;
  page_type: unknown;
  visibility: unknown;
  sort_order: unknown;
  published: unknown;
};

type SocialLinkRow = { platform: unknown; url: unknown };
type MediaRow = { id: unknown; title: unknown; metadata: unknown; signedUrl?: unknown };

const privateContentKey = /(tenant|website|recipient|internal|audit|credential|secret|password|payment|booking|profile|user)/i;

function string(value: unknown, maximumLength: number): string | null {
  return typeof value === 'string' && value.trim().length > 0 && value.trim().length <= maximumLength
    ? value.trim()
    : null;
}

function strings(value: unknown, maximumItems: number, maximumLength: number): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => string(item, maximumLength))
    .filter((item): item is string => item !== null)
    .slice(0, maximumItems);
}

function publicSettings(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const settings = value as Record<string, unknown>;
  const result: Record<string, unknown> = {};
  const brandName = string(settings.brandName, 120);
  const tagline = string(settings.tagline, 240);
  const contentAreas = strings(settings.contentAreas, 20, 120);
  const contactAreas = strings(settings.contactAreas, 10, 120);
  const socialPlatforms = strings(settings.socialPlatforms, 20, 80);
  if (brandName) result.brandName = brandName;
  if (tagline) result.tagline = tagline;
  if (contentAreas.length > 0) result.contentAreas = contentAreas;
  if (contactAreas.length > 0) result.contactAreas = contactAreas;
  if (socialPlatforms.length > 0) result.socialPlatforms = socialPlatforms;
  return result;
}

function publicContent(value: unknown, depth = 0): unknown {
  if (depth > 5 || value === null || typeof value === 'boolean' || typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') return value.length <= 10000 ? value : value.slice(0, 10000);
  if (Array.isArray(value)) return value.slice(0, 50).map((item) => publicContent(item, depth + 1));
  if (!value || typeof value !== 'object') return null;
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(([key]) => !privateContentKey.test(key))
      .slice(0, 50)
      .map(([key, item]) => [key, publicContent(item, depth + 1)]),
  );
}

export function parsePublicWebsiteContentRequest(input: Record<string, unknown>): string | null {
  if (Object.keys(input).length !== 1 || !Object.hasOwn(input, 'domain')) return null;
  const domain = string(input.domain, 255)?.toLowerCase();
  return domain && publicWebsiteDomains.has(domain) ? domain : null;
}

export function publicWebsiteContentResponse({
  website,
  content,
  pages,
  socialLinks,
  media = [],
}: {
  website: WebsiteRow;
  content: ContentRow[];
  pages: PageRow[];
  socialLinks: SocialLinkRow[];
  media?: MediaRow[];
}) {
  return {
    website: {
      name: string(website.name, 120) ?? 'Website',
      domain: string(website.domain, 255),
      settings: publicSettings(website.website_settings),
    },
    pages: pages
      .filter((page) => page.visibility === true && page.published === true)
      .map((page) => ({
        title: string(page.title, 160),
        slug: string(page.slug, 160),
        pageType: string(page.page_type, 80),
        visibility: true,
        sortOrder: typeof page.sort_order === 'number' ? page.sort_order : 0,
        published: true,
      })),
    content: content
      .filter((entry) => entry.content_status === 'PUBLISHED')
      .map((entry) => ({
        contentKey: string(entry.content_key, 160),
        content: entry.content && typeof entry.content === 'object' && !Array.isArray(entry.content)
          ? publicContent(entry.content)
          : {},
        updatedAt: string(entry.updated_at, 64),
      })),
    socialLinks: socialLinks
      .map((link) => ({
        platform: string(link.platform, 80),
        url: string(link.url, 2048),
      }))
      .filter((link) => link.platform && link.url && /^https:\/\//.test(link.url)),
    media: media
      .filter((item) => typeof item.id === 'string')
      .map((item) => ({
        id: item.id,
        title: string(item.title, 160),
        metadata: publicContent(item.metadata),
        signedUrl: string(item.signedUrl, 4096),
      })),
  };
}