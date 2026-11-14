create or replace function public.get_published_r2_photo(
  requested_domain text,
  requested_media_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'storage_path', media.storage_path,
    'tenant_id', media.tenant_id,
    'website_id', media.website_id,
    'metadata', jsonb_build_object('storage_provider', 'r2')
  )
  from public.media as media
  join public.websites as website
    on website.id = media.website_id and website.tenant_id = media.tenant_id
  where media.id = requested_media_id
    and website.domain = lower(btrim(requested_domain))
    and website.site_lifecycle in ('APPROVED', 'PUBLISHED')
    and media.metadata ->> 'storage_provider' = 'r2'
    and exists (
      select 1
      from jsonb_array_elements(
        public.get_public_website_content_payload(requested_domain) -> 'media'
      ) as published(item)
      where published.item ->> 'id' = requested_media_id::text
    );
$$;

revoke execute on function public.get_published_r2_photo(text, uuid) from public;
grant execute on function public.get_published_r2_photo(text, uuid) to anon;
