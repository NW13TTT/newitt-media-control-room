-- Additive migration only. Do not modify or rerun earlier migrations.
--
-- Beta feature flag. No application code path currently sets
-- media.metadata->>'published', so uploaded media can never reach the public
-- website gates in get_public_website_media and
-- get_public_website_content_payload. This lets a named tenant be opted in to
-- publishing on upload for a controlled live beta, and opted back out with a
-- single update, without changing the publishing architecture.
--
-- The flag is keyed on the tenant UUID, is readable and writable only by
-- MASTER_ADMIN, and is never supplied by or exposed to the client. It changes
-- only the default published state of a tenant's own new media rows. Storage,
-- the private website-media bucket, storage RLS, media RLS, tenant isolation
-- and the public lifecycle gates are untouched.

create table if not exists public.tenant_media_auto_publish (
  tenant_id uuid primary key references public.customer_accounts(id) on delete cascade,
  enabled boolean not null default false,
  note text,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.tenant_media_auto_publish enable row level security;

drop policy if exists tenant_media_auto_publish_master_manage on public.tenant_media_auto_publish;
create policy tenant_media_auto_publish_master_manage
on public.tenant_media_auto_publish
for all to authenticated
using (public.is_master_admin())
with check (public.is_master_admin());

grant select, insert, update, delete on table public.tenant_media_auto_publish to authenticated;

drop trigger if exists tenant_media_auto_publish_set_updated_at on public.tenant_media_auto_publish;
create trigger tenant_media_auto_publish_set_updated_at
before update on public.tenant_media_auto_publish
for each row execute function public.set_updated_at();

-- The owning tenant is resolved from the website row rather than from the
-- inserted tenant_id, so the outcome cannot depend on trigger firing order or
-- on a value supplied by the client. A forged tenant_id is already rejected by
-- validate_website_tenant and by the media RLS check.
create or replace function public.apply_tenant_media_auto_publish()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owning_tenant_id uuid;
begin
  select website.tenant_id into owning_tenant_id
  from public.websites as website
  where website.id = new.website_id;

  if owning_tenant_id is null or owning_tenant_id <> new.tenant_id then
    return new;
  end if;

  if exists (
    select 1
    from public.tenant_media_auto_publish as setting
    where setting.tenant_id = owning_tenant_id
      and setting.enabled
  ) then
    new.metadata := coalesce(new.metadata, '{}'::jsonb)
      || pg_catalog.jsonb_build_object('published', 'true', 'published_by', 'BETA_AUTO_PUBLISH');
  end if;

  return new;
end;
$$;

revoke execute on function public.apply_tenant_media_auto_publish() from public;

drop trigger if exists media_apply_tenant_auto_publish on public.media;
create trigger media_apply_tenant_auto_publish
before insert on public.media
for each row execute function public.apply_tenant_media_auto_publish();
