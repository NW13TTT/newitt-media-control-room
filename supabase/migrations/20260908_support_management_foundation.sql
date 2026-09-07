-- Additive support-management foundation. Do not modify prior migrations.

alter table public.support_requests
  add column if not exists category text not null default 'OTHER',
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references public.profiles(id) on delete set null,
  add column if not exists closed_at timestamptz,
  add column if not exists closed_by uuid references public.profiles(id) on delete set null;

alter table public.support_requests
  add constraint support_requests_category_valid check (category in ('WEBSITE', 'CONTENT', 'MEDIA', 'ACCOUNT', 'PAYMENTS', 'TECHNICAL', 'OTHER')) not valid;
alter table public.support_requests
  add constraint support_requests_status_valid check (status in ('NEW', 'OPEN', 'IN_PROGRESS', 'WAITING_FOR_CUSTOMER', 'RESOLVED', 'CLOSED')) not valid;

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  support_request_id uuid not null references public.support_requests(id) on delete cascade,
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (char_length(body) between 1 and 10000),
  is_internal boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index support_messages_request_created_idx on public.support_messages (support_request_id, created_at);

create or replace function public.validate_support_message_scope()
returns trigger language plpgsql set search_path = '' as $$
declare request_tenant_id uuid; author_tenant_id uuid; author_role public.app_role;
begin
  if auth.uid() is null then raise exception 'An authenticated profile is required'; end if;
  new.author_id := auth.uid();
  select tenant_id into request_tenant_id from public.support_requests where id = new.support_request_id;
  select tenant_id, role into author_tenant_id, author_role from public.profiles where id = auth.uid();
  if request_tenant_id is null or author_tenant_id is null or new.tenant_id <> request_tenant_id then raise exception 'Support message and request tenant must match'; end if;
  if author_role <> 'MASTER_ADMIN' and request_tenant_id <> author_tenant_id then raise exception 'Support request is not available to this account'; end if;
  if author_role <> 'MASTER_ADMIN' and new.is_internal then raise exception 'Internal support notes require Master Admin'; end if;
  return new;
end;
$$;
create trigger support_messages_validate_scope before insert or update on public.support_messages for each row execute function public.validate_support_message_scope();
create trigger support_messages_set_updated_at before update on public.support_messages for each row execute function public.set_updated_at();
alter table public.support_messages enable row level security;

create policy support_messages_customer_select_visible on public.support_messages
for select to authenticated using (
  not is_internal and exists (select 1 from public.support_requests where support_requests.id = support_messages.support_request_id and support_requests.tenant_id = public.current_tenant_id())
);
create policy support_messages_customer_create_visible on public.support_messages
for insert to authenticated with check (
  not is_internal and tenant_id = public.current_tenant_id() and author_id = auth.uid()
);
create policy support_messages_master_manage on public.support_messages
for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin());

create policy support_requests_master_manage on public.support_requests
for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin());

create or replace function public.enforce_support_request_update_scope()
returns trigger language plpgsql set search_path = '' as $$
declare caller_role public.app_role := public.current_user_role();
begin
  if caller_role <> 'MASTER_ADMIN' then
    if new.resolved_at is distinct from old.resolved_at or new.resolved_by is distinct from old.resolved_by or new.closed_at is distinct from old.closed_at or new.closed_by is distinct from old.closed_by or new.status is distinct from old.status or new.category is distinct from old.category then
      raise exception 'Only Master Admin can change support status or resolution details';
    end if;
  else
    if new.status = 'RESOLVED' and old.status is distinct from 'RESOLVED' then new.resolved_at := pg_catalog.timezone('utc', pg_catalog.now()); new.resolved_by := auth.uid(); end if;
    if new.status = 'CLOSED' and old.status is distinct from 'CLOSED' then new.closed_at := pg_catalog.timezone('utc', pg_catalog.now()); new.closed_by := auth.uid(); end if;
  end if;
  return new;
end;
$$;
create trigger support_requests_enforce_update_scope before update on public.support_requests for each row execute function public.enforce_support_request_update_scope();

create or replace function public.audit_support_message_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare action_name text;
begin
  if public.is_master_admin() then
    action_name := case when new.is_internal then 'SUPPORT_INTERNAL_NOTE_ADDED' else 'SUPPORT_RESPONSE_ADDED' end;
    insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata)
    select auth.uid(), new.tenant_id, request.website_id, action_name, 'support_message', new.id, jsonb_build_object('internal', new.is_internal)
    from public.support_requests request where request.id = new.support_request_id;
  end if;
  return new;
end;
$$;
create trigger support_messages_audit after insert on public.support_messages for each row execute function public.audit_support_message_change();

create or replace function public.audit_support_request_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare action_name text;
begin
  if public.is_master_admin() and new.status is distinct from old.status then
    action_name := case new.status when 'RESOLVED' then 'SUPPORT_RESOLVED' when 'CLOSED' then 'SUPPORT_CLOSED' else 'SUPPORT_STATUS_CHANGED' end;
    insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata)
    values (auth.uid(), new.tenant_id, new.website_id, action_name, 'support_request', new.id, jsonb_build_object('status', new.status));
  end if;
  return new;
end;
$$;
create trigger support_requests_audit after update on public.support_requests for each row execute function public.audit_support_request_change();

revoke execute on function public.validate_support_message_scope() from public, authenticated;
revoke execute on function public.enforce_support_request_update_scope() from public, authenticated;
revoke execute on function public.audit_support_message_change() from public, authenticated;
revoke execute on function public.audit_support_request_change() from public, authenticated;