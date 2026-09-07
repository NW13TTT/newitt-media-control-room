-- Temporary website central-data foundation. No GitHub, Cloudflare, DNS, or deployment.
create type public.site_lifecycle_status as enum ('DRAFT','BUILDING','PREVIEW','PENDING_APPROVAL','APPROVED','PUBLISHED','EXPIRED','ARCHIVED','SUSPENDED');
create type public.site_page_type as enum ('HOME','ABOUT','SERVICES','CONTACT','NEWS','CUSTOM');

create table public.website_templates (
 id uuid primary key default gen_random_uuid(), name text not null unique, description text, template_type text not null, version text not null default '1.0', active boolean not null default true, created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now())
);
insert into public.website_templates (name,description,template_type) values
 ('NEWITT Media Standard','Standard NEWITT Media website structure','STANDARD'),('Professional Business','Business service website structure','BUSINESS'),('Photography','Photography portfolio structure','PHOTOGRAPHY'),('Paranormal','Investigation and paranormal structure','PARANORMAL'),('Portfolio','Portfolio presentation structure','PORTFOLIO'),('Event','Event information structure','EVENT'),('Simple Landing Page','Single-page launch structure','LANDING') on conflict (name) do nothing;

alter table public.websites add column site_slug text, add column site_lifecycle public.site_lifecycle_status not null default 'DRAFT', add column template_id uuid references public.website_templates(id) on delete set null, add column description text, add column expires_at timestamptz, add column published_at timestamptz, add column archived_at timestamptz, add column preview_token uuid default gen_random_uuid(), add column is_primary boolean not null default false, add column created_by uuid references public.profiles(id) on delete set null, add column updated_by uuid references public.profiles(id) on delete set null;
create unique index websites_tenant_slug_idx on public.websites(tenant_id,site_slug) where site_slug is not null;
create unique index websites_primary_tenant_idx on public.websites(tenant_id) where is_primary;
create index websites_expiry_idx on public.websites(expires_at) where expires_at is not null;
create table public.website_pages (id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.customer_accounts(id) on delete cascade, website_id uuid not null references public.websites(id) on delete cascade, title text not null, slug text not null, page_type public.site_page_type not null default 'CUSTOM', visibility boolean not null default true, sort_order integer not null default 0, published boolean not null default false, created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), unique(website_id,slug));

create or replace function public.validate_site_scope() returns trigger language plpgsql set search_path = '' as $$
declare old_status public.site_lifecycle_status; begin
 if auth.uid() is null then raise exception 'An authenticated profile is required'; end if;
 if tg_op='INSERT' then new.created_by := auth.uid(); end if; new.updated_by := auth.uid();
 if not public.is_master_admin() then
  if tg_op='INSERT' then raise exception 'Only Master Admin can create websites'; end if;
  if new.site_lifecycle is distinct from old.site_lifecycle or new.template_id is distinct from old.template_id or new.expires_at is distinct from old.expires_at or new.published_at is distinct from old.published_at or new.archived_at is distinct from old.archived_at or new.tenant_id is distinct from old.tenant_id then raise exception 'Website lifecycle is managed by Master Admin'; end if;
 end if;
 if new.expires_at is not null and new.expires_at <= timezone('utc',now()) and new.site_lifecycle not in ('EXPIRED','ARCHIVED') then new.site_lifecycle := 'EXPIRED'; end if;
 if new.site_lifecycle='PUBLISHED' then new.published_at := coalesce(new.published_at,timezone('utc',now())); end if;
 if new.site_lifecycle='ARCHIVED' then new.archived_at := coalesce(new.archived_at,timezone('utc',now())); end if;
 return new; end; $$;
create trigger websites_validate_site_scope before insert or update on public.websites for each row execute function public.validate_site_scope();
create or replace function public.validate_website_page_scope() returns trigger language plpgsql set search_path = '' as $$
declare website_tenant uuid; begin select tenant_id into website_tenant from public.websites where id=new.website_id; if website_tenant is null then raise exception 'Website is not available'; end if; new.tenant_id:=website_tenant; if not public.is_master_admin() and website_tenant<>public.current_tenant_id() then raise exception 'Website page is not available'; end if; return new; end; $$;
create trigger website_pages_validate_scope before insert or update on public.website_pages for each row execute function public.validate_website_page_scope();
create trigger website_templates_updated before update on public.website_templates for each row execute function public.set_updated_at(); create trigger website_pages_updated before update on public.website_pages for each row execute function public.set_updated_at();
alter table public.website_templates enable row level security; alter table public.website_pages enable row level security;
create policy website_templates_select_active on public.website_templates for select to authenticated using (active or public.is_master_admin()); create policy website_templates_master_manage on public.website_templates for all to authenticated using (public.is_master_admin()) with check (public.is_master_admin());
create policy website_pages_select_scope on public.website_pages for select to authenticated using (tenant_id=public.current_tenant_id() or public.is_master_admin()); create policy website_pages_customer_manage on public.website_pages for all to authenticated using (tenant_id=public.current_tenant_id()) with check (tenant_id=public.current_tenant_id()); create policy website_pages_master_manage on public.website_pages for all to authenticated using (public.is_master_admin()) with check(public.is_master_admin());
create or replace function public.website_can_publish(requested_website_id uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.websites where id=requested_website_id and tenant_id=public.current_tenant_id() and site_lifecycle in ('APPROVED','PUBLISHED') and (expires_at is null or expires_at > timezone('utc',now()))); $$;
revoke execute on function public.website_can_publish(uuid) from public,authenticated;
create or replace function public.audit_site_change() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.audit_logs(actor_id,tenant_id,website_id,action,resource_type,resource_id,metadata) values(auth.uid(),new.tenant_id,new.id,case when tg_op='INSERT' then 'WEBSITE_CREATED' when new.site_lifecycle='EXPIRED' then 'WEBSITE_EXPIRED' when new.site_lifecycle='ARCHIVED' then 'WEBSITE_ARCHIVED' when new.site_lifecycle='SUSPENDED' then 'WEBSITE_SUSPENDED' when new.site_lifecycle='PUBLISHED' then 'WEBSITE_PUBLISHED' else 'WEBSITE_UPDATED' end,'website',new.id,jsonb_build_object('lifecycle',new.site_lifecycle)); return new; end; $$;
create trigger websites_audit_site_change after insert or update on public.websites for each row execute function public.audit_site_change(); revoke execute on function public.validate_site_scope() from public,authenticated; revoke execute on function public.validate_website_page_scope() from public,authenticated; revoke execute on function public.audit_site_change() from public,authenticated;
