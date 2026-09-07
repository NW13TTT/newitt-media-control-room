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
    'website', jsonb_build_object(
      'name', website.name,
      'domain', website.domain,
      'website_settings', website.website_settings
    ),
    'content', coalesce((
      select jsonb_agg(jsonb_build_object(
        'content_key', content.content_key,
        'content', content.content,
        'updated_at', content.updated_at,
        'content_status', content.content_status
      ) order by content.updated_at desc)
      from public.website_content as content
      join public.published_website_content as published
        on published.website_content_id = content.id
      where content.website_id = website.id
        and content.tenant_id = website.tenant_id
        and content.content_status = 'PUBLISHED'
    ), '[]'::jsonb),
    'pages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'title', page.title,
        'slug', page.slug,
        'page_type', page.page_type,
        'visibility', page.visibility,
        'sort_order', page.sort_order,
        'published', page.published
      ) order by page.sort_order)
      from public.website_pages as page
      where page.website_id = website.id
        and page.published
        and page.visibility
    ), '[]'::jsonb),
    'social_links', coalesce((
      select jsonb_agg(jsonb_build_object(
        'platform', link.platform,
        'url', link.url
      ) order by link.platform)
      from public.social_links as link
      where link.website_id = website.id
        and link.tenant_id = website.tenant_id
        and link.url like 'https://%'
    ), '[]'::jsonb)
  )
  from public.websites as website
  where website.domain = lower(btrim(requested_domain))
    and website.domain in ('newittmedia.co.uk', 'essexparanormal.com')
    and website.site_lifecycle in ('APPROVED', 'PUBLISHED')
  limit 1;
$$;

revoke execute on function public.get_public_website_content_payload(text) from public;
grant execute on function public.get_public_website_content_payload(text) to anon, authenticated;