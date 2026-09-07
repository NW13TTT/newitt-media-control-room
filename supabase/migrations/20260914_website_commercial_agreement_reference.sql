-- Optional central-data relationship only; no payment dependency is created.
alter table public.websites
  add column if not exists commercial_agreement_id uuid
  references public.commercial_agreements(id) on delete set null;

create or replace function public.validate_site_scope()
returns trigger language plpgsql set search_path = '' as $$
declare agreement_tenant_id uuid;
begin
  if auth.uid() is null then raise exception 'An authenticated profile is required'; end if;
  if tg_op = 'INSERT' then new.created_by := auth.uid(); end if;
  new.updated_by := auth.uid();
  if new.commercial_agreement_id is not null then
    select tenant_id into agreement_tenant_id from public.commercial_agreements where id = new.commercial_agreement_id;
    if agreement_tenant_id is null or agreement_tenant_id <> new.tenant_id then raise exception 'Website agreement must belong to the same tenant'; end if;
  end if;
  if not public.is_master_admin() then
    if tg_op = 'INSERT' then raise exception 'Only Master Admin can create websites'; end if;
    if new.site_lifecycle is distinct from old.site_lifecycle or new.template_id is distinct from old.template_id or new.expires_at is distinct from old.expires_at or new.published_at is distinct from old.published_at or new.archived_at is distinct from old.archived_at or new.tenant_id is distinct from old.tenant_id or new.commercial_agreement_id is distinct from old.commercial_agreement_id then raise exception 'Website lifecycle is managed by Master Admin'; end if;
  end if;
  if new.expires_at is not null and new.expires_at <= timezone('utc',now()) and new.site_lifecycle not in ('EXPIRED','ARCHIVED') then new.site_lifecycle := 'EXPIRED'; end if;
  if new.site_lifecycle='PUBLISHED' then new.published_at := coalesce(new.published_at,timezone('utc',now())); end if;
  if new.site_lifecycle='ARCHIVED' then new.archived_at := coalesce(new.archived_at,timezone('utc',now())); end if;
  return new;
end;
$$;
revoke execute on function public.validate_site_scope() from public, authenticated;