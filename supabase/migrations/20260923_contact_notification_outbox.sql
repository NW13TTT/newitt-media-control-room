create table if not exists public.contact_enquiry_notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  contact_enquiry_id uuid not null unique references public.contact_enquiries(id) on delete cascade,
  recipient_key text not null,
  status text not null default 'PENDING',
  attempt_count integer not null default 0 check (attempt_count >= 0),
  retry_count integer not null default 0 check (retry_count >= 0),
  attempted_at timestamptz,
  sent_at timestamptz,
  failed_at timestamptz,
  next_attempt_at timestamptz,
  provider_message_id text,
  failure_code text,
  processing_token uuid,
  processing_started_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint contact_enquiry_notification_status_check check (status in ('PENDING', 'SENT', 'FAILED'))
);

create index if not exists contact_enquiry_notifications_retry_idx
  on public.contact_enquiry_notifications (status, next_attempt_at)
  where status in ('PENDING', 'FAILED');

create index if not exists contact_enquiry_notifications_scope_idx
  on public.contact_enquiry_notifications (tenant_id, website_id, created_at desc);

create or replace function public.validate_contact_enquiry_notification_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  website_tenant_id uuid;
  enquiry_tenant_id uuid;
  enquiry_website_id uuid;
begin
  select tenant_id into website_tenant_id from public.websites where id = new.website_id;
  select tenant_id, website_id into enquiry_tenant_id, enquiry_website_id
    from public.contact_enquiries where id = new.contact_enquiry_id;
  if website_tenant_id is null
    or enquiry_tenant_id is null
    or website_tenant_id <> new.tenant_id
    or enquiry_tenant_id <> new.tenant_id
    or enquiry_website_id <> new.website_id then
    raise exception 'Contact notification must match its enquiry website and tenant';
  end if;
  return new;
end;
$$;

drop trigger if exists contact_enquiry_notifications_validate_tenant on public.contact_enquiry_notifications;
create trigger contact_enquiry_notifications_validate_tenant
before insert or update on public.contact_enquiry_notifications
for each row execute function public.validate_contact_enquiry_notification_tenant();

drop trigger if exists contact_enquiry_notifications_set_updated_at on public.contact_enquiry_notifications;
create trigger contact_enquiry_notifications_set_updated_at
before update on public.contact_enquiry_notifications
for each row execute function public.set_updated_at();

alter table public.contact_enquiry_notifications enable row level security;

create policy contact_enquiry_notifications_select_scoped
on public.contact_enquiry_notifications for select to authenticated
using (tenant_id = public.current_tenant_id() or public.is_master_admin());

create or replace function public.create_contact_enquiry_with_notification(
  p_tenant_id uuid,
  p_website_id uuid,
  p_area text,
  p_name text,
  p_email text,
  p_message text,
  p_recipient_key text
)
returns table (contact_enquiry_id uuid, notification_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  enquiry_id uuid;
  outbox_id uuid;
begin
  if not exists (
    select 1 from public.websites
    where id = p_website_id and tenant_id = p_tenant_id
  ) then
    raise exception 'Website scope is invalid';
  end if;

  insert into public.contact_enquiries (tenant_id, website_id, area, name, email, message, status)
  values (p_tenant_id, p_website_id, p_area, p_name, p_email, p_message, 'NEW')
  returning id into enquiry_id;

  insert into public.contact_enquiry_notifications (
    tenant_id, website_id, contact_enquiry_id, recipient_key, status
  ) values (
    p_tenant_id, p_website_id, enquiry_id, p_recipient_key, 'PENDING'
  ) returning id into outbox_id;

  return query select enquiry_id, outbox_id;
end;
$$;

revoke all on function public.create_contact_enquiry_with_notification(uuid, uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.create_contact_enquiry_with_notification(uuid, uuid, text, text, text, text, text) to service_role;

create or replace function public.claim_contact_enquiry_notification(
  p_notification_id uuid
)
returns table (
  notification_id uuid,
  contact_enquiry_id uuid,
  tenant_id uuid,
  website_id uuid,
  recipient_key text,
  area text,
  name text,
  email text,
  message text,
  processing_token uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  claimed_token uuid := gen_random_uuid();
begin
  return query
  with claimed as (
    update public.contact_enquiry_notifications
       set processing_token = claimed_token,
           processing_started_at = timezone('utc', now()),
           attempted_at = timezone('utc', now()),
           attempt_count = attempt_count + 1,
           retry_count = case when attempt_count > 0 then retry_count + 1 else retry_count end,
           status = 'PENDING',
           failure_code = null
     where id = p_notification_id
       and status in ('PENDING', 'FAILED')
       and (next_attempt_at is null or next_attempt_at <= timezone('utc', now()))
       and (processing_started_at is null or processing_started_at < timezone('utc', now()) - interval '15 minutes')
    returning id, contact_enquiry_id, tenant_id, website_id, recipient_key, processing_token
  )
  select claimed.id, claimed.contact_enquiry_id, claimed.tenant_id, claimed.website_id,
         claimed.recipient_key, enquiry.area, enquiry.name, enquiry.email, enquiry.message,
         claimed.processing_token
    from claimed
    join public.contact_enquiries as enquiry on enquiry.id = claimed.contact_enquiry_id;
end;
$$;

revoke all on function public.claim_contact_enquiry_notification(uuid) from public, anon, authenticated;
grant execute on function public.claim_contact_enquiry_notification(uuid) to service_role;

create or replace function public.complete_contact_enquiry_notification(
  p_notification_id uuid,
  p_processing_token uuid,
  p_sent boolean,
  p_provider_message_id text default null,
  p_failure_code text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.contact_enquiry_notifications
     set status = case when p_sent then 'SENT' else 'FAILED' end,
         sent_at = case when p_sent then timezone('utc', now()) else null end,
         failed_at = case when p_sent then null else timezone('utc', now()) end,
         next_attempt_at = case when p_sent then null else timezone('utc', now()) + interval '5 minutes' end,
         provider_message_id = case when p_sent then p_provider_message_id else null end,
         failure_code = case when p_sent then null else p_failure_code end,
         processing_token = null,
         processing_started_at = null
   where id = p_notification_id
     and processing_token = p_processing_token;
  return found;
end;
$$;

revoke all on function public.complete_contact_enquiry_notification(uuid, uuid, boolean, text, text) from public, anon, authenticated;
grant execute on function public.complete_contact_enquiry_notification(uuid, uuid, boolean, text, text) to service_role;