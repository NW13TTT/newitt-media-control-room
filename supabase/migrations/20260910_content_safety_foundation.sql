-- Content Safety foundation. Safety data is tenant-owned and publication remains
-- controlled by the existing publishing and approval workflows.

create type public.content_safety_decision as enum ('SAFE', 'REVIEW', 'BLOCKED');
create type public.content_safety_severity as enum ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
create type public.content_safety_finding_status as enum ('OPEN', 'REVIEWING', 'RESOLVED', 'DISMISSED');
create type public.content_safety_category as enum (
  'VIOLENCE', 'HATE_DISCRIMINATION', 'SEXUAL_CONTENT', 'CHILD_SAFETY',
  'HARASSMENT_ABUSE', 'ILLEGAL_ACTIVITY', 'DANGEROUS_INSTRUCTIONS',
  'SELF_HARM', 'PRIVACY_PERSONAL_INFORMATION', 'FRAUD_DECEPTION',
  'DEFAMATION_UNSUPPORTED_ALLEGATIONS', 'COPYRIGHT_INTELLECTUAL_PROPERTY',
  'SPAM_MALICIOUS_CONTENT', 'MISLEADING_CLAIMS', 'OTHER'
);

create table public.content_safety_reviews (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_content_id uuid not null unique references public.website_content(id) on delete cascade,
  decision public.content_safety_decision not null default 'SAFE',
  explanation text,
  recommended_action text,
  source text not null default 'MANUAL' check (source in ('MANUAL', 'AI_ASSISTED', 'SYSTEM')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null
);

create table public.content_safety_findings (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.content_safety_reviews(id) on delete cascade,
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  category public.content_safety_category not null,
  severity public.content_safety_severity not null,
  status public.content_safety_finding_status not null default 'OPEN',
  explanation text not null,
  recommended_action text,
  requires_review boolean not null default false,
  reviewer_source text not null default 'MANUAL' check (reviewer_source in ('MANUAL', 'AI_ASSISTED', 'SYSTEM')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null
);
create index content_safety_reviews_tenant_idx on public.content_safety_reviews (tenant_id, decision);
create index content_safety_findings_review_idx on public.content_safety_findings (review_id, status, severity);

create or replace function public.validate_content_safety_review_scope()
returns trigger language plpgsql set search_path = '' as $$
declare content_tenant_id uuid;
begin
  if auth.uid() is null or not public.is_master_admin() then
    raise exception 'Only Master Admin can manage content safety reviews';
  end if;
  select tenant_id into content_tenant_id from public.website_content where id = new.website_content_id;
  if content_tenant_id is null then
    raise exception 'Safety review content is not available';
  end if;
  new.tenant_id := content_tenant_id;
  new.reviewed_by := auth.uid();
  if new.decision = 'SAFE' then
    new.resolved_at := coalesce(new.resolved_at, pg_catalog.timezone('utc', pg_catalog.now()));
    new.resolved_by := coalesce(new.resolved_by, auth.uid());
  elsif new.decision in ('REVIEW', 'BLOCKED') then
    new.resolved_at := null;
    new.resolved_by := null;
  end if;
  return new;
end;
$$;
create trigger content_safety_reviews_validate_scope before insert or update on public.content_safety_reviews for each row execute function public.validate_content_safety_review_scope();
create trigger content_safety_reviews_set_updated_at before update on public.content_safety_reviews for each row execute function public.set_updated_at();

create or replace function public.validate_content_safety_finding_scope()
returns trigger language plpgsql set search_path = '' as $$
declare review_tenant_id uuid;
begin
  if auth.uid() is null or not public.is_master_admin() then
    raise exception 'Only Master Admin can manage content safety findings';
  end if;
  select tenant_id into review_tenant_id from public.content_safety_reviews where id = new.review_id;
  if review_tenant_id is null then
    raise exception 'Safety finding review is not available';
  end if;
  new.tenant_id := review_tenant_id;
  if new.status in ('RESOLVED', 'DISMISSED') then
    new.resolved_at := coalesce(new.resolved_at, pg_catalog.timezone('utc', pg_catalog.now()));
    new.resolved_by := coalesce(new.resolved_by, auth.uid());
  else
    new.resolved_at := null;
    new.resolved_by := null;
  end if;
  return new;
end;
$$;
create trigger content_safety_findings_validate_scope before insert or update on public.content_safety_findings for each row execute function public.validate_content_safety_finding_scope();
create trigger content_safety_findings_set_updated_at before update on public.content_safety_findings for each row execute function public.set_updated_at();

alter table public.content_safety_reviews enable row level security;
alter table public.content_safety_findings enable row level security;
create policy content_safety_reviews_customer_select on public.content_safety_reviews for select to authenticated using (tenant_id = public.current_tenant_id());
create policy content_safety_reviews_master_manage on public.content_safety_reviews for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin());
create policy content_safety_findings_customer_select on public.content_safety_findings for select to authenticated using (tenant_id = public.current_tenant_id());
create policy content_safety_findings_master_manage on public.content_safety_findings for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin());

create or replace function public.audit_content_safety_review_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata)
  select auth.uid(), new.tenant_id, content.website_id,
    case when tg_op = 'INSERT' then 'CONTENT_SAFETY_REVIEW_CREATED' else 'CONTENT_SAFETY_DECISION_CHANGED' end,
    'content_safety_review', new.id,
    jsonb_build_object('decision', new.decision, 'source', new.source)
  from public.website_content content where content.id = new.website_content_id;
  return new;
end;
$$;
create trigger content_safety_reviews_audit after insert or update on public.content_safety_reviews for each row execute function public.audit_content_safety_review_change();

create or replace function public.audit_content_safety_finding_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata)
  select auth.uid(), new.tenant_id, content.website_id,
    case when new.status = 'RESOLVED' then 'CONTENT_SAFETY_FINDING_RESOLVED'
         when new.status = 'DISMISSED' then 'CONTENT_SAFETY_FINDING_DISMISSED'
         when tg_op = 'INSERT' then 'CONTENT_SAFETY_FINDING_CREATED'
         else 'CONTENT_SAFETY_FINDING_UPDATED' end,
    'content_safety_finding', new.id,
    jsonb_build_object('category', new.category, 'severity', new.severity, 'status', new.status)
  from public.content_safety_reviews review
  join public.website_content content on content.id = review.website_content_id
  where review.id = new.review_id;
  return new;
end;
$$;
create trigger content_safety_findings_audit after insert or update on public.content_safety_findings for each row execute function public.audit_content_safety_finding_change();

create or replace function public.content_safety_blocks_publication(content_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.content_safety_reviews review
    where review.website_content_id = content_id and review.decision = 'BLOCKED'
  ) or exists (
    select 1 from public.content_safety_findings finding
    join public.content_safety_reviews review on review.id = finding.review_id
    where review.website_content_id = content_id
      and finding.status not in ('RESOLVED', 'DISMISSED')
      and (finding.severity = 'CRITICAL' or (finding.severity = 'HIGH' and finding.requires_review))
  );
$$;

create or replace function public.publish_website_content(requested_website_id uuid, requested_content_key text)
returns void language plpgsql security definer set search_path = '' as $$
declare authenticated_tenant_id uuid := public.current_tenant_id(); content_record public.website_content%rowtype;
begin
  if auth.uid() is null or authenticated_tenant_id is null then raise exception 'An authenticated tenant profile is required'; end if;
  select * into content_record from public.website_content where website_id = requested_website_id and content_key = requested_content_key and tenant_id = authenticated_tenant_id;
  if content_record.id is null then raise exception 'Website content is not available to the authenticated tenant'; end if;
  if public.content_safety_blocks_publication(content_record.id) then raise exception 'Content safety review must be resolved before publishing'; end if;
  insert into public.published_website_content (website_content_id, tenant_id, website_id, content_key, content, published_at)
  values (content_record.id, content_record.tenant_id, content_record.website_id, content_record.content_key, content_record.content, pg_catalog.timezone('utc', pg_catalog.now()))
  on conflict (website_content_id) do update set content = excluded.content, published_at = excluded.published_at, tenant_id = excluded.tenant_id, website_id = excluded.website_id, content_key = excluded.content_key;
  update public.website_content set content_status = 'PUBLISHED' where id = content_record.id;
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
  if public.content_safety_blocks_publication(content_record.id) then raise exception 'Content safety review must be resolved before publishing'; end if;
  insert into public.published_website_content (website_content_id, tenant_id, website_id, content_key, content, published_at) values (content_record.id, content_record.tenant_id, content_record.website_id, content_record.content_key, content_record.content, pg_catalog.timezone('utc', pg_catalog.now())) on conflict (website_content_id) do update set content = excluded.content, published_at = excluded.published_at;
  update public.website_content set content_status = 'PUBLISHED', approved_at = pg_catalog.timezone('utc', pg_catalog.now()), approved_by = caller_id where id = content_record.id;
  insert into public.audit_logs (actor_id, tenant_id, website_id, action, resource_type, resource_id, metadata) values (caller_id, caller_tenant_id, requested_website_id, 'CONTENT_APPROVED_AND_PUBLISHED', 'website_content', content_record.id, jsonb_build_object('content_key', requested_content_key));
end;
$$;

revoke execute on function public.validate_content_safety_review_scope() from public, authenticated;
revoke execute on function public.validate_content_safety_finding_scope() from public, authenticated;
revoke execute on function public.audit_content_safety_review_change() from public, authenticated;
revoke execute on function public.audit_content_safety_finding_change() from public, authenticated;
revoke execute on function public.content_safety_blocks_publication(uuid) from public, authenticated;
revoke execute on function public.publish_website_content(uuid, text) from public, anon, authenticated;
grant execute on function public.publish_website_content(uuid, text) to authenticated;
revoke execute on function public.approve_website_content(uuid, text) from public;
grant execute on function public.approve_website_content(uuid, text) to authenticated;
