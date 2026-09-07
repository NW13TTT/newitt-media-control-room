-- Commercial agreement foundation. No payment processing or document storage.

create type public.commercial_agreement_type as enum ('WEBSITE', 'HOSTING', 'SUPPORT', 'MEDIA', 'PHOTOGRAPHY', 'DRONE', 'OTHER');
create type public.commercial_billing_frequency as enum ('ONE_OFF', 'MONTHLY', 'ANNUAL', 'CUSTOM');
create type public.commercial_agreement_status as enum ('DRAFT', 'ACTIVE', 'PENDING_RENEWAL', 'EXPIRED', 'CANCELLED', 'SUSPENDED');

alter table public.commercial_agreements
  add column reference_number text,
  add column title text,
  add column description text,
  add column renewal_date date,
  add column billing_frequency public.commercial_billing_frequency not null default 'CUSTOM',
  add column amount numeric(12,2),
  add column currency char(3) not null default 'GBP',
  add column payment_terms text,
  add column notes text,
  add column created_by uuid references public.profiles(id) on delete set null,
  add column updated_by uuid references public.profiles(id) on delete set null,
  add column cancelled_at timestamptz,
  add column cancelled_by uuid references public.profiles(id) on delete set null,
  add column cancellation_reason text,
  add column previous_agreement_id uuid references public.commercial_agreements(id) on delete set null;
alter table public.commercial_agreements add constraint commercial_agreements_reference_unique unique (reference_number);
alter table public.commercial_agreements add constraint commercial_agreements_amount_valid check (amount is null or amount >= 0);
alter table public.commercial_agreements add constraint commercial_agreements_dates_valid check (ends_at is null or starts_at is null or ends_at >= starts_at);
alter table public.commercial_agreements add constraint commercial_agreements_currency_valid check (currency ~ '^[A-Z]{3}$');

create table public.commercial_agreement_items (
 id uuid primary key default gen_random_uuid(), agreement_id uuid not null references public.commercial_agreements(id) on delete cascade,
 tenant_id uuid not null references public.customer_accounts(id) on delete cascade, service_name text not null, description text,
 quantity numeric(12,2) not null default 1 check (quantity > 0), unit_price numeric(12,2) not null default 0 check (unit_price >= 0),
 amount numeric(12,2) generated always as (quantity * unit_price) stored, billing_frequency public.commercial_billing_frequency not null default 'CUSTOM',
 active boolean not null default true, created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now())
);
create table public.commercial_agreement_documents (
 id uuid primary key default gen_random_uuid(), agreement_id uuid not null references public.commercial_agreements(id) on delete cascade,
 tenant_id uuid not null references public.customer_accounts(id) on delete cascade, document_name text not null, document_type text not null,
 storage_path text, uploaded_at timestamptz not null default timezone('utc', now()), uploaded_by uuid references public.profiles(id) on delete set null
);
create table public.commercial_agreement_history (
 id uuid primary key default gen_random_uuid(), agreement_id uuid not null references public.commercial_agreements(id) on delete cascade,
 tenant_id uuid not null references public.customer_accounts(id) on delete cascade, actor_id uuid references public.profiles(id) on delete set null,
 action text not null, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default timezone('utc', now())
);

create or replace function public.validate_commercial_agreement_scope() returns trigger language plpgsql set search_path = '' as $$
begin
 if auth.uid() is null or not public.is_master_admin() then raise exception 'Only Master Admin can manage commercial agreements'; end if;
 if not exists (select 1 from public.customer_accounts where id = new.tenant_id) then raise exception 'Agreement tenant is not available'; end if;
 if tg_op = 'INSERT' then new.created_by := auth.uid(); end if; new.updated_by := auth.uid();
 if new.status = 'CANCELLED' then new.cancelled_at := coalesce(new.cancelled_at, pg_catalog.timezone('utc', pg_catalog.now())); new.cancelled_by := auth.uid(); if nullif(btrim(new.cancellation_reason), '') is null then raise exception 'A cancellation reason is required'; end if; end if;
 return new;
end; $$;
create trigger commercial_agreements_validate_scope before insert or update on public.commercial_agreements for each row execute function public.validate_commercial_agreement_scope();
create or replace function public.validate_commercial_agreement_child_scope() returns trigger language plpgsql set search_path = '' as $$
declare agreement_tenant uuid; begin
 if auth.uid() is null or not public.is_master_admin() then raise exception 'Only Master Admin can manage commercial agreement records'; end if;
 select tenant_id into agreement_tenant from public.commercial_agreements where id = new.agreement_id; if agreement_tenant is null then raise exception 'Agreement is not available'; end if;
 new.tenant_id := agreement_tenant; if tg_table_name = 'commercial_agreement_documents' then new.uploaded_by := auth.uid(); end if; return new;
end; $$;
create trigger commercial_agreement_items_validate_scope before insert or update on public.commercial_agreement_items for each row execute function public.validate_commercial_agreement_child_scope();
create trigger commercial_agreement_documents_validate_scope before insert or update on public.commercial_agreement_documents for each row execute function public.validate_commercial_agreement_child_scope();
create trigger commercial_agreement_items_set_updated_at before update on public.commercial_agreement_items for each row execute function public.set_updated_at();

alter table public.commercial_agreement_items enable row level security; alter table public.commercial_agreement_documents enable row level security; alter table public.commercial_agreement_history enable row level security;
create policy commercial_agreement_items_customer_select on public.commercial_agreement_items for select to authenticated using (tenant_id = public.current_tenant_id());
create policy commercial_agreement_items_master_manage on public.commercial_agreement_items for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin());
create policy commercial_agreement_documents_customer_select on public.commercial_agreement_documents for select to authenticated using (tenant_id = public.current_tenant_id());
create policy commercial_agreement_documents_master_manage on public.commercial_agreement_documents for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin());
create policy commercial_agreement_history_master_select on public.commercial_agreement_history for select to authenticated using (public.is_master_admin());

create or replace function public.audit_commercial_agreement_change() returns trigger language plpgsql security definer set search_path = '' as $$
declare agreement_record public.commercial_agreements%rowtype; action_name text; begin
 agreement_record := coalesce(new, old); action_name := case when tg_table_name = 'commercial_agreements' and tg_op = 'INSERT' then 'COMMERCIAL_AGREEMENT_CREATED' when agreement_record.status = 'ACTIVE' then 'COMMERCIAL_AGREEMENT_ACTIVATED' when agreement_record.status = 'SUSPENDED' then 'COMMERCIAL_AGREEMENT_SUSPENDED' when agreement_record.status = 'CANCELLED' then 'COMMERCIAL_AGREEMENT_CANCELLED' when tg_table_name = 'commercial_agreement_items' then 'COMMERCIAL_AGREEMENT_ITEM_CHANGED' when tg_table_name = 'commercial_agreement_documents' then 'COMMERCIAL_AGREEMENT_DOCUMENT_CHANGED' else 'COMMERCIAL_AGREEMENT_UPDATED' end;
 insert into public.commercial_agreement_history (agreement_id, tenant_id, actor_id, action, metadata) values (agreement_record.id, agreement_record.tenant_id, auth.uid(), action_name, jsonb_build_object('status', agreement_record.status));
 insert into public.audit_logs (actor_id, tenant_id, action, resource_type, resource_id, metadata) values (auth.uid(), agreement_record.tenant_id, action_name, 'commercial_agreement', agreement_record.id, jsonb_build_object('status', agreement_record.status)); return coalesce(new, old); end; $$;
create trigger commercial_agreements_audit after insert or update on public.commercial_agreements for each row execute function public.audit_commercial_agreement_change();
revoke execute on function public.validate_commercial_agreement_scope() from public, authenticated; revoke execute on function public.validate_commercial_agreement_child_scope() from public, authenticated; revoke execute on function public.audit_commercial_agreement_change() from public, authenticated;
