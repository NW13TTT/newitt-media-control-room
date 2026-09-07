-- Additive migration only. Do not modify or rerun 20260903_initial_schema.sql.

do $$
begin
  if not exists (
    select 1 from pg_type where typnamespace = 'public'::regnamespace and typname = 'content_status'
  ) then
    create type public.content_status as enum ('DRAFT', 'PUBLISHED');
  end if;
end;
$$;

alter table public.website_content
  add column if not exists content_status public.content_status not null default 'DRAFT';

create index if not exists website_content_published_website_key_idx
  on public.website_content (website_id, content_key)
  where content_status = 'PUBLISHED';

-- Published payloads are separate from editable tenant content. RLS is enabled
-- without tenant policies, so only the scoped SECURITY DEFINER publisher writes
-- snapshots and no direct client query can read them.
create table if not exists public.published_website_content (
  website_content_id uuid primary key references public.website_content(id) on delete cascade,
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  content_key text not null,
  content jsonb not null,
  published_at timestamptz not null default timezone('utc', now()),
  unique (website_id, content_key)
);

create trigger published_website_content_validate_tenant
before insert or update on public.published_website_content
for each row execute function public.validate_website_tenant();

alter table public.published_website_content enable row level security;

create or replace function public.mark_website_content_draft_on_edit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.content is distinct from old.content then
    new.content_status := 'DRAFT';
  end if;
  return new;
end;
$$;

drop trigger if exists website_content_mark_draft_on_edit on public.website_content;
create trigger website_content_mark_draft_on_edit
before update on public.website_content
for each row execute function public.mark_website_content_draft_on_edit();

-- Content is authored in content. Publishing creates an explicit immutable-at-
-- publish-time snapshot in published_content. Future edits can remain drafts.
create or replace function public.publish_website_content(
  requested_website_id uuid,
  requested_content_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  authenticated_tenant_id uuid := public.current_tenant_id();
begin
  if auth.uid() is null or authenticated_tenant_id is null then
    raise exception 'An authenticated tenant profile is required';
  end if;

  insert into public.published_website_content (
    website_content_id, tenant_id, website_id, content_key, content, published_at
  )
  select
    content_record.id,
    content_record.tenant_id,
    content_record.website_id,
    content_record.content_key,
    content_record.content,
    pg_catalog.timezone('utc', pg_catalog.now())
  from public.website_content as content_record
  where content_record.website_id = requested_website_id
    and content_record.content_key = requested_content_key
    and content_record.tenant_id = authenticated_tenant_id
  on conflict (website_content_id) do update
    set content = excluded.content,
        published_at = excluded.published_at,
        tenant_id = excluded.tenant_id,
        website_id = excluded.website_id,
        content_key = excluded.content_key;

  if not found then
    raise exception 'Website content is not available to the authenticated tenant';
  end if;

  update public.website_content as content_record
     set content_status = 'PUBLISHED'
   where content_record.website_id = requested_website_id
     and content_record.content_key = requested_content_key
     and content_record.tenant_id = authenticated_tenant_id;
end;
$$;

revoke execute on function public.publish_website_content(uuid, text) from public;
grant execute on function public.publish_website_content(uuid, text) to authenticated;

-- This is intentionally the only anonymous access path for website content.
-- It returns no identifiers, tenant information, draft payloads, or other tables.
create or replace function public.get_published_website_content(
  requested_domain text
)
returns table (
  content_key text,
  content jsonb,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    published_record.content_key,
    published_record.content,
    published_record.published_at
  from public.websites as website
  join public.website_content as content_record
    on content_record.website_id = website.id
  join public.published_website_content as published_record
    on published_record.website_content_id = content_record.id
  where website.domain = pg_catalog.lower(pg_catalog.btrim(requested_domain))
    and content_record.content_status = 'PUBLISHED'
  order by content_record.content_key;
$$;

revoke execute on function public.get_published_website_content(text) from public, authenticated;
grant execute on function public.get_published_website_content(text) to anon, authenticated;

insert into storage.buckets (id, name, public)
values ('website-media', 'website-media', false)
on conflict (id) do nothing;

-- A pre-existing public bucket with this reserved name is unsafe for this
-- foundation, so fail rather than silently reuse it.
do $$
begin
  if exists (
    select 1
    from storage.buckets
    where id = 'website-media'
      and (name <> 'website-media' or public)
  ) then
    raise exception 'The website-media bucket must be named website-media and private';
  end if;
end;
$$;

create or replace function public.can_manage_website_media_path(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth.uid() is not null
    and pg_catalog.cardinality(pg_catalog.string_to_array(object_name, '/')) >= 3
    and (pg_catalog.string_to_array(object_name, '/'))[1] = public.current_tenant_id()::text
    and (pg_catalog.string_to_array(object_name, '/'))[2] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and exists (
      select 1
      from public.websites as website
      where website.id = (pg_catalog.string_to_array(object_name, '/'))[2]::uuid
        and website.tenant_id = public.current_tenant_id()
    );
$$;

revoke execute on function public.can_manage_website_media_path(text) from public;
grant execute on function public.can_manage_website_media_path(text) to authenticated;

-- Required object-name format:
-- website-media/<tenant UUID>/<website UUID>/<asset name>
-- Policies use the authenticated profile's database-derived tenant, never a
-- tenant identifier supplied as an authorization input by the Flutter client.
create policy website_media_tenant_read on storage.objects
for select to authenticated
using (
  bucket_id = 'website-media'
  and public.can_manage_website_media_path(name)
);

create policy website_media_tenant_upload on storage.objects
for insert to authenticated
with check (
  bucket_id = 'website-media'
  and public.can_manage_website_media_path(name)
);

create policy website_media_tenant_update on storage.objects
for update to authenticated
using (
  bucket_id = 'website-media'
  and public.can_manage_website_media_path(name)
)
with check (
  bucket_id = 'website-media'
  and public.can_manage_website_media_path(name)
);

create policy website_media_tenant_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'website-media'
  and public.can_manage_website_media_path(name)
);