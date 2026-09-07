create table if not exists public.website_feature_inventory (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  feature_key text not null,
  evidence_status text not null default 'NEEDS_REVIEW',
  connected boolean not null default false,
  enabled boolean not null default false,
  evidence text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (website_id, feature_key),
  constraint website_feature_inventory_status_check check (
    evidence_status in ('EXISTING', 'AVAILABLE', 'NEEDS_REVIEW', 'DISABLED', 'PLANNED')
  )
);

create index if not exists website_feature_inventory_scope_idx
  on public.website_feature_inventory (tenant_id, website_id, feature_key);

create or replace function public.validate_feature_inventory_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
declare website_tenant_id uuid;
begin
  select tenant_id into website_tenant_id from public.websites where id = new.website_id;
  if website_tenant_id is null or website_tenant_id <> new.tenant_id then
    raise exception 'Website and feature mapping must belong to the same tenant';
  end if;
  return new;
end;
$$;

drop trigger if exists website_feature_inventory_validate_tenant on public.website_feature_inventory;
create trigger website_feature_inventory_validate_tenant
before insert or update on public.website_feature_inventory
for each row execute function public.validate_feature_inventory_tenant();

drop trigger if exists website_feature_inventory_set_updated_at on public.website_feature_inventory;
create trigger website_feature_inventory_set_updated_at
before update on public.website_feature_inventory
for each row execute function public.set_updated_at();

alter table public.website_feature_inventory enable row level security;

drop policy if exists website_feature_inventory_select_scoped on public.website_feature_inventory;
create policy website_feature_inventory_select_scoped
on public.website_feature_inventory for select
using (tenant_id = public.current_tenant_id() or public.is_master_admin());

drop policy if exists website_feature_inventory_manage_scoped on public.website_feature_inventory;
create policy website_feature_inventory_manage_scoped
on public.website_feature_inventory for all
using (tenant_id = public.current_tenant_id() or public.is_master_admin())
with check (tenant_id = public.current_tenant_id() or public.is_master_admin());
