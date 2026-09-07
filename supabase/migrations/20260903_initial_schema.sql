create extension if not exists pgcrypto;

create type public.app_role as enum ('MASTER_ADMIN', 'OWNER', 'CUSTOMER');
create type public.website_type as enum ('OWNER', 'CUSTOMER');
create type public.website_health_status as enum ('ONLINE', 'OFFLINE', 'UNKNOWN');
create type public.status_value as enum ('ACTIVE', 'INACTIVE', 'CONNECTED', 'NOT_CONNECTED', 'NOT_CONFIGURED', 'SUCCESSFUL', 'PENDING', 'FAILED', 'UNKNOWN');

create table public.customer_accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  tenant_id uuid not null references public.customer_accounts(id) on delete restrict,
  display_name text not null,
  email text not null,
  role public.app_role not null default 'CUSTOMER',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.websites (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  name text not null,
  domain text not null unique,
  website_type public.website_type not null,
  connection_status public.status_value not null default 'UNKNOWN',
  online_status public.website_health_status not null default 'UNKNOWN',
  ssl_status public.status_value not null default 'UNKNOWN',
  domain_status public.status_value not null default 'UNKNOWN',
  deployment_status public.status_value not null default 'UNKNOWN',
  last_successful_deployment timestamptz,
  critical_error_status public.status_value not null default 'UNKNOWN',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.website_capabilities (
  website_id uuid not null references public.websites(id) on delete cascade,
  capability text not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (website_id, capability)
);

create table public.media (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  storage_path text not null,
  title text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.social_links (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  platform text not null,
  url text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.website_content (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  content_key text not null,
  content jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (website_id, content_key)
);

create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid references public.websites(id) on delete set null,
  requester_id uuid not null references public.profiles(id) on delete restrict,
  subject text not null,
  body text not null,
  status text not null default 'OPEN',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.support_access_grants (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid references public.websites(id) on delete cascade,
  granted_to uuid not null references auth.users(id) on delete cascade,
  granted_by uuid not null references auth.users(id) on delete restrict,
  reason text not null,
  can_view_content boolean not null default false,
  can_view_media boolean not null default false,
  starts_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  constraint support_access_expiry_after_start check (expires_at > starts_at)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  tenant_id uuid references public.customer_accounts(id) on delete set null,
  website_id uuid references public.websites(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.commercial_agreements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  agreement_type text not null,
  status text not null default 'DRAFT',
  terms jsonb not null default '{}'::jsonb,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.validate_website_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  website_tenant_id uuid;
begin
  if new.website_id is not null then
    select tenant_id into website_tenant_id
    from public.websites
    where id = new.website_id;
    if website_tenant_id is null or website_tenant_id <> new.tenant_id then
      raise exception 'Website and record must belong to the same tenant';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.validate_website_type()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.website_type = 'OWNER' and not exists (
    select 1 from public.customer_accounts
    where id = new.tenant_id and slug = 'newitt-media'
  ) then
    raise exception 'Owner websites must belong to the NEWITT Media tenant';
  end if;
  return new;
end;
$$;

create trigger websites_validate_type
before insert or update on public.websites
for each row execute function public.validate_website_type();

create trigger media_validate_tenant
before insert or update on public.media
for each row execute function public.validate_website_tenant();

create trigger social_links_validate_tenant
before insert or update on public.social_links
for each row execute function public.validate_website_tenant();

create trigger website_content_validate_tenant
before insert or update on public.website_content
for each row execute function public.validate_website_tenant();

create trigger support_requests_validate_tenant
before insert or update on public.support_requests
for each row execute function public.validate_website_tenant();

create trigger support_access_grants_validate_tenant
before insert or update on public.support_access_grants
for each row execute function public.validate_website_tenant();

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'customer_accounts', 'profiles', 'websites', 'media', 'social_links',
    'website_content', 'support_requests', 'support_access_grants',
    'commercial_agreements'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      table_name || '_set_updated_at', table_name
    );
  end loop;
end;
$$;

create or replace function public.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role from public.profiles as p where p.id = auth.uid();
$$;

create or replace function public.current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.tenant_id from public.profiles as p where p.id = auth.uid();
$$;

create or replace function public.is_master_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.current_user_role() = 'MASTER_ADMIN', false);
$$;

create or replace function public.has_support_access(
  requested_tenant_id uuid,
  requested_website_id uuid,
  required_content_access boolean,
  required_media_access boolean
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.support_access_grants as grants
    where grants.tenant_id = requested_tenant_id
      and (grants.website_id is null or grants.website_id = requested_website_id)
      and grants.granted_to = auth.uid()
      and grants.starts_at <= pg_catalog.timezone('utc', pg_catalog.now())
      and grants.expires_at > pg_catalog.timezone('utc', pg_catalog.now())
      and grants.revoked_at is null
      and (not required_content_access or grants.can_view_content)
      and (not required_media_access or grants.can_view_media)
  );
$$;

create or replace function public.prevent_profile_scope_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' and (new.role <> old.role or new.tenant_id <> old.tenant_id) then
    raise exception 'Role and tenant scope are managed by the backend';
  end if;
  return new;
end;
$$;

create trigger profiles_prevent_scope_change
before update on public.profiles
for each row execute function public.prevent_profile_scope_change();

create or replace function public.append_audit_log(
  audit_tenant_id uuid,
  audit_website_id uuid,
  audit_action text,
  audit_resource_type text,
  audit_resource_id uuid,
  audit_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_id uuid;
  caller_id uuid := auth.uid();
  caller_role public.app_role;
  caller_tenant_id uuid;
  website_tenant_id uuid;
begin
  select p.role, p.tenant_id
    into caller_role, caller_tenant_id
    from public.profiles as p
   where p.id = caller_id;

  if auth.role() <> 'service_role' then
    if caller_id is null or caller_role is null then
      raise exception 'An authenticated profile is required to append an audit log';
    end if;
    if caller_role <> 'MASTER_ADMIN'
      and audit_tenant_id is distinct from caller_tenant_id then
      raise exception 'Audit tenant must match the authenticated tenant';
    end if;
  end if;

  if audit_tenant_id is not null
    and not exists (
      select 1
        from public.customer_accounts as accounts
       where accounts.id = audit_tenant_id
    ) then
    raise exception 'Audit tenant does not exist';
  end if;

  if audit_website_id is not null then
    select websites.tenant_id
      into website_tenant_id
      from public.websites
     where websites.id = audit_website_id;
    if website_tenant_id is null
      or audit_tenant_id is distinct from website_tenant_id then
      raise exception 'Audit website and tenant must match';
    end if;
  end if;

  insert into public.audit_logs (
    actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata
  ) values (
    auth.uid(), audit_tenant_id, audit_website_id, audit_action,
    audit_resource_type, audit_resource_id, audit_metadata
  ) returning id into created_id;
  return created_id;
end;
$$;

revoke execute on function public.append_audit_log(uuid, uuid, text, text, uuid, jsonb) from public, authenticated;
grant execute on function public.append_audit_log(uuid, uuid, text, text, uuid, jsonb) to service_role;

create or replace function public.audit_support_access_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.append_audit_log(
    new.tenant_id,
    new.website_id,
    case when tg_op = 'INSERT' then 'SUPPORT_ACCESS_GRANTED' else 'SUPPORT_ACCESS_UPDATED' end,
    'support_access_grant',
    new.id,
    jsonb_build_object(
      'granted_to', new.granted_to,
      'expires_at', new.expires_at,
      'revoked_at', new.revoked_at,
      'can_view_content', new.can_view_content,
      'can_view_media', new.can_view_media
    )
  );
  return new;
end;
$$;

create trigger support_access_grants_audit
after insert or update on public.support_access_grants
for each row execute function public.audit_support_access_change();

revoke execute on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;
revoke execute on function public.current_tenant_id() from public;
grant execute on function public.current_tenant_id() to authenticated;
revoke execute on function public.is_master_admin() from public;
grant execute on function public.is_master_admin() to authenticated;
revoke execute on function public.has_support_access(uuid, uuid, boolean, boolean) from public;
grant execute on function public.has_support_access(uuid, uuid, boolean, boolean) to authenticated;
revoke execute on function public.prevent_profile_scope_change() from public, authenticated;
revoke execute on function public.audit_support_access_change() from public, authenticated;

alter table public.customer_accounts enable row level security;
alter table public.profiles enable row level security;
alter table public.websites enable row level security;
alter table public.website_capabilities enable row level security;
alter table public.media enable row level security;
alter table public.social_links enable row level security;
alter table public.website_content enable row level security;
alter table public.support_requests enable row level security;
alter table public.support_access_grants enable row level security;
alter table public.audit_logs enable row level security;
alter table public.commercial_agreements enable row level security;

create policy customer_accounts_select_scoped on public.customer_accounts
for select to authenticated
using (id = public.current_tenant_id() or public.is_master_admin());

create policy customer_accounts_admin_manage on public.customer_accounts
for all to authenticated
using (public.is_master_admin())
with check (public.is_master_admin());

create policy profiles_select_self on public.profiles
for select to authenticated
using (id = auth.uid());

create policy profiles_update_self on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid() and tenant_id = public.current_tenant_id());

create policy websites_select_operational_scope on public.websites
for select to authenticated
using (tenant_id = public.current_tenant_id() or public.is_master_admin());

create policy websites_customer_manage_own on public.websites
for all to authenticated
using (tenant_id = public.current_tenant_id())
with check (tenant_id = public.current_tenant_id());

create policy websites_master_manage on public.websites
for all to authenticated
using (public.is_master_admin())
with check (public.is_master_admin());

create policy website_capabilities_select_scope on public.website_capabilities
for select to authenticated
using (
  exists (
    select 1 from public.websites
    where websites.id = website_capabilities.website_id
      and (websites.tenant_id = public.current_tenant_id() or public.is_master_admin())
  )
);

create policy website_capabilities_customer_manage_own on public.website_capabilities
for all to authenticated
using (
  exists (select 1 from public.websites where websites.id = website_id and websites.tenant_id = public.current_tenant_id())
)
with check (
  exists (select 1 from public.websites where websites.id = website_id and websites.tenant_id = public.current_tenant_id())
);

create policy website_capabilities_master_manage on public.website_capabilities
for all to authenticated
using (public.is_master_admin())
with check (public.is_master_admin());

create policy media_select_private_scope on public.media
for select to authenticated
using (
  tenant_id = public.current_tenant_id()
  or public.has_support_access(tenant_id, website_id, false, true)
);

create policy media_customer_manage_own on public.media
for all to authenticated
using (tenant_id = public.current_tenant_id())
with check (tenant_id = public.current_tenant_id());

create policy social_links_select_private_scope on public.social_links
for select to authenticated
using (
  tenant_id = public.current_tenant_id()
  or public.has_support_access(tenant_id, website_id, true, false)
);

create policy social_links_customer_manage_own on public.social_links
for all to authenticated
using (tenant_id = public.current_tenant_id())
with check (tenant_id = public.current_tenant_id());

create policy website_content_select_private_scope on public.website_content
for select to authenticated
using (
  tenant_id = public.current_tenant_id()
  or public.has_support_access(tenant_id, website_id, true, false)
);

create policy website_content_customer_manage_own on public.website_content
for all to authenticated
using (tenant_id = public.current_tenant_id())
with check (tenant_id = public.current_tenant_id());

create policy support_requests_select_scoped on public.support_requests
for select to authenticated
using (
  tenant_id = public.current_tenant_id()
  or public.has_support_access(tenant_id, website_id, true, false)
);

create policy support_requests_customer_create_own on public.support_requests
for insert to authenticated
with check (tenant_id = public.current_tenant_id() and requester_id = auth.uid());

create policy support_requests_customer_update_own on public.support_requests
for update to authenticated
using (tenant_id = public.current_tenant_id() and requester_id = auth.uid())
with check (tenant_id = public.current_tenant_id() and requester_id = auth.uid());

create policy support_access_grants_select_involved on public.support_access_grants
for select to authenticated
using (granted_to = auth.uid() or granted_by = auth.uid());

create policy support_access_grants_master_manage on public.support_access_grants
for all to authenticated
using (public.is_master_admin())
with check (public.is_master_admin() and granted_by = auth.uid());

create policy audit_logs_select_scoped on public.audit_logs
for select to authenticated
using (tenant_id = public.current_tenant_id() or public.is_master_admin());

create policy commercial_agreements_select_scoped on public.commercial_agreements
for select to authenticated
using (tenant_id = public.current_tenant_id() or public.is_master_admin());

create policy commercial_agreements_master_manage on public.commercial_agreements
for all to authenticated
using (public.is_master_admin())
with check (public.is_master_admin());

revoke insert, update, delete on public.audit_logs from anon, authenticated;
