create or replace function public.get_public_website_media(
  requested_domain text
)
returns table (
  id uuid,
  title text,
  metadata jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select media.id, media.title, media.metadata
  from public.websites as website
  join public.media as media
    on media.website_id = website.id
   and media.tenant_id = website.tenant_id
  where website.domain = lower(btrim(requested_domain))
    and website.domain in ('newittmedia.co.uk', 'essexparanormal.com')
    and website.site_lifecycle in ('APPROVED', 'PUBLISHED')
    and media.metadata ->> 'published' = 'true'
  order by media.created_at desc;
$$;

revoke execute on function public.get_public_website_media(text) from public;
grant execute on function public.get_public_website_media(text) to anon, authenticated;

create or replace function public.get_public_website_content_payload(
  requested_domain text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'website', jsonb_build_object('name', website.name, 'domain', website.domain, 'website_settings', website.website_settings),
    'content', coalesce((select jsonb_agg(jsonb_build_object('content_key', content.content_key, 'content', content.content, 'updated_at', content.updated_at, 'content_status', content.content_status) order by content.updated_at desc) from public.website_content as content join public.published_website_content as published on published.website_content_id = content.id where content.website_id = website.id and content.tenant_id = website.tenant_id and content.content_status = 'PUBLISHED'), '[]'::jsonb),
    'pages', coalesce((select jsonb_agg(jsonb_build_object('title', page.title, 'slug', page.slug, 'page_type', page.page_type, 'visibility', page.visibility, 'sort_order', page.sort_order, 'published', page.published) order by page.sort_order) from public.website_pages as page where page.website_id = website.id and page.published and page.visibility), '[]'::jsonb),
    'social_links', coalesce((select jsonb_agg(jsonb_build_object('platform', link.platform, 'url', link.url) order by link.platform) from public.social_links as link where link.website_id = website.id and link.tenant_id = website.tenant_id and link.url like 'https://%'), '[]'::jsonb),
    'media', coalesce((select jsonb_agg(jsonb_build_object('id', media.id, 'title', media.title, 'metadata', media.metadata) order by media.created_at desc) from public.media as media where media.website_id = website.id and media.tenant_id = website.tenant_id and media.metadata ->> 'published' = 'true'), '[]'::jsonb)
  )
  from public.websites as website
  where website.domain = lower(btrim(requested_domain))
    and website.domain in ('newittmedia.co.uk', 'essexparanormal.com')
    and website.site_lifecycle in ('APPROVED', 'PUBLISHED')
  limit 1;
$$;