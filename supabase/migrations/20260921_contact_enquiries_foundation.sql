create table if not exists public.contact_enquiries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  area text not null,
  name text not null,
  email text not null,
  message text not null,
  status text not null default 'NEW',
  internal_notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint contact_enquiries_status_check check (status in ('NEW', 'READ', 'RESPONDED', 'CLOSED'))
);

create index if not exists contact_enquiries_tenant_created_idx
  on public.contact_enquiries (tenant_id, created_at desc);

create or replace function public.validate_contact_enquiry_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  website_tenant_id uuid;
begin
  select tenant_id into website_tenant_id from public.websites where id = new.website_id;
  if website_tenant_id is null or website_tenant_id <> new.tenant_id then
    raise exception 'Website and enquiry must belong to the same tenant';
  end if;
  return new;
end;
$$;

drop trigger if exists contact_enquiries_validate_tenant on public.contact_enquiries;
create trigger contact_enquiries_validate_tenant
before insert or update on public.contact_enquiries
for each row execute function public.validate_contact_enquiry_tenant();

drop trigger if exists contact_enquiries_set_updated_at on public.contact_enquiries;
create trigger contact_enquiries_set_updated_at
before update on public.contact_enquiries
for each row execute function public.set_updated_at();

alter table public.contact_enquiries enable row level security;

drop policy if exists contact_enquiries_select_scoped on public.contact_enquiries;
create policy contact_enquiries_select_scoped
on public.contact_enquiries for select
using (tenant_id = public.current_tenant_id() or public.is_master_admin());

drop policy if exists contact_enquiries_admin_update on public.contact_enquiries;
create policy contact_enquiries_admin_update
on public.contact_enquiries for update
using (public.is_master_admin() or tenant_id = public.current_tenant_id())
with check (public.is_master_admin() or tenant_id = public.current_tenant_id());
