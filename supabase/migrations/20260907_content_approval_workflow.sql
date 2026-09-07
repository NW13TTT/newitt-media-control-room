-- Additive approval workflow. Requires 20260906_content_approval_status.sql.

alter table public.website_content
  add column if not exists approval_requested_at timestamptz,
  add column if not exists approval_requested_by uuid references public.profiles(id) on delete set null,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references public.profiles(id) on delete set null,
  add column if not exists rejected_at timestamptz,
  add column if not exists rejected_by uuid references public.profiles(id) on delete set null,
  add column if not exists rejection_reason text;

alter table public.website_content add constraint website_content_pending_approval_integrity check (content_status <> 'PENDING_APPROVAL' or (approval_requested_at is not null and approval_requested_by is not null));
alter table public.website_content add constraint website_content_rejection_reason_length check (rejection_reason is null or char_length(rejection_reason) <= 1000);

create table public.content_approval_grants (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  granted_by uuid not null references public.profiles(id) on delete restrict,
  granted_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  unique (website_id, profile_id)
);

create or replace function public.validate_content_approval_grant_scope()
returns trigger language plpgsql set search_path = '' as $$
declare profile_tenant_id uuid; website_tenant_id uuid;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null then raise exception 'An authenticated administrator is required'; end if;
    new.granted_by := auth.uid();
  end if;
  select tenant_id into profile_tenant_id from public.profiles where id = new.profile_id;
  select tenant_id into website_tenant_id from public.websites where id = new.website_id;
  if profile_tenant_id is null or website_tenant_id is null or new.tenant_id <> profile_tenant_id or new.tenant_id <> website_tenant_id then raise exception 'Approval grant profile, website, and tenant must match'; end if;
  if not exists (select 1 from public.website_capabilities where website_id = new.website_id and capability = 'contentApproval') then raise exception 'Website approval capability is required'; end if;
  return new;
end;
$$;
create trigger content_approval_grants_validate_scope before insert or update on public.content_approval_grants for each row execute function public.validate_content_approval_grant_scope();
alter table public.content_approval_grants enable row level security;
create policy content_approval_grants_select_self on public.content_approval_grants for select to authenticated using (profile_id = auth.uid());
create policy content_approval_grants_master_manage on public.content_approval_grants for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin() and granted_by = auth.uid());

drop policy if exists website_content_customer_manage_own on public.website_content;
create policy website_content_customer_insert_draft on public.website_content for insert to authenticated with check (tenant_id = public.current_tenant_id() and content_status = 'DRAFT');
create policy website_content_customer_update_draft on public.website_content for update to authenticated using (tenant_id = public.current_tenant_id() and content_status in ('DRAFT', 'PUBLISHED')) with check (tenant_id = public.current_tenant_id() and content_status = 'DRAFT');
create policy website_content_customer_delete_draft on public.website_content for delete to authenticated using (tenant_id = public.current_tenant_id() and content_status = 'DRAFT');

create or replace function public.mark_website_content_draft_on_edit()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.content_status = 'PUBLISHED' and new.content_status = 'DRAFT' and new.content is not distinct from old.content then raise exception 'Published content must be edited before it returns to draft'; end if;
  if new.content is distinct from old.content then
    new.content_status := 'DRAFT'; new.approval_requested_at := null; new.approval_requested_by := null;
    new.approved_at := null; new.approved_by := null; new.rejected_at := null; new.rejected_by := null; new.rejection_reason := null;
  end if;
  return new;
end;
$$;

create or replace function public.submit_website_content_for_approval(requested_website_id uuid, requested_content_key text)
returns void language plpgsql security definer set search_path = '' as $$
declare caller_id uuid := auth.uid(); caller_tenant_id uuid := public.current_tenant_id(); content_id uuid;
begin
  if caller_id is null or caller_tenant_id is null then raise exception 'An authenticated tenant profile is required'; end if;
  if not exists (select 1 from public.website_capabilities where website_id = requested_website_id and capability = 'contentApproval') then raise exception 'Content approval is not enabled for this website'; end if;
  update public.website_content set content_status = 'PENDING_APPROVAL', approval_requested_at = pg_catalog.timezone('utc', pg_catalog.now()), approval_requested_by = caller_id, approved_at = null, approved_by = null, rejected_at = null, rejected_by = null, rejection_reason = null where website_id = requested_website_id and content_key = requested_content_key and tenant_id = caller_tenant_id and content_status = 'DRAFT' returning id into content_id;
  if content_id is null then raise exception 'Draft content is not available for approval'; end if;
  insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata) values (caller_id, caller_tenant_id, requested_website_id, 'CONTENT_APPROVAL_REQUESTED', 'website_content', content_id, jsonb_build_object('content_key', requested_content_key));
end;
$$;

create or replace function public.approve_website_content(requested_website_id uuid, requested_content_key text)
returns void language plpgsql security definer set search_path = '' as $$
declare caller_id uuid := auth.uid(); caller_tenant_id uuid := public.current_tenant_id(); content_record public.website_content%rowtype;
begin
  if caller_id is null or caller_tenant_id is null or not exists (select 1 from public.content_approval_grants where profile_id = caller_id and tenant_id = caller_tenant_id and website_id = requested_website_id and revoked_at is null) then raise exception 'Approval is not available to this account'; end if;
  select * into content_record from public.website_content where website_id = requested_website_id and content_key = requested_content_key and tenant_id = caller_tenant_id and content_status = 'PENDING_APPROVAL';
  if content_record.id is null then raise exception 'Pending content is not available for approval'; end if;
  if content_record.approval_requested_by = caller_id then raise exception 'A requester cannot approve their own content'; end if;
  if not exists (select 1 from public.website_capabilities where website_id = requested_website_id and capability = 'contentApproval') then raise exception 'Content approval is not enabled for this website'; end if;
  insert into public.published_website_content (website_content_id, tenant_id, website_id, content_key, content, published_at) values (content_record.id, content_record.tenant_id, content_record.website_id, content_record.content_key, content_record.content, pg_catalog.timezone('utc', pg_catalog.now())) on conflict (website_content_id) do update set content = excluded.content, published_at = excluded.published_at;
  update public.website_content set content_status = 'PUBLISHED', approved_at = pg_catalog.timezone('utc', pg_catalog.now()), approved_by = caller_id where id = content_record.id;
  insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata) values (caller_id, caller_tenant_id, requested_website_id, 'CONTENT_APPROVED_AND_PUBLISHED', 'website_content', content_record.id, jsonb_build_object('content_key', requested_content_key));
end;
$$;

create or replace function public.reject_website_content(requested_website_id uuid, requested_content_key text, requested_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare caller_id uuid := auth.uid(); caller_tenant_id uuid := public.current_tenant_id(); content_id uuid;
begin
  if caller_id is null or caller_tenant_id is null or not exists (select 1 from public.content_approval_grants where profile_id = caller_id and tenant_id = caller_tenant_id and website_id = requested_website_id and revoked_at is null) then raise exception 'Approval is not available to this account'; end if;
  if not exists (select 1 from public.website_capabilities where website_id = requested_website_id and capability = 'contentApproval') then raise exception 'Content approval is not enabled for this website'; end if;
  if requested_reason is not null and char_length(requested_reason) > 1000 then raise exception 'Rejection reason is too long'; end if;
  update public.website_content set content_status = 'DRAFT', rejected_at = pg_catalog.timezone('utc', pg_catalog.now()), rejected_by = caller_id, rejection_reason = nullif(btrim(requested_reason), '') where website_id = requested_website_id and content_key = requested_content_key and tenant_id = caller_tenant_id and content_status = 'PENDING_APPROVAL' returning id into content_id;
  if content_id is null then raise exception 'Pending content is not available for rejection'; end if;
  insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata) values (caller_id, caller_tenant_id, requested_website_id, 'CONTENT_APPROVAL_REJECTED', 'website_content', content_id, jsonb_build_object('content_key', requested_content_key, 'reason_provided', requested_reason is not null));
end;
$$;

revoke execute on function public.publish_website_content(uuid, text) from public, anon, authenticated;
revoke execute on function public.submit_website_content_for_approval(uuid, text) from public;
grant execute on function public.submit_website_content_for_approval(uuid, text) to authenticated;
revoke execute on function public.approve_website_content(uuid, text) from public;
grant execute on function public.approve_website_content(uuid, text) to authenticated;
revoke execute on function public.reject_website_content(uuid, text, text) from public;
grant execute on function public.reject_website_content(uuid, text, text) to authenticated;