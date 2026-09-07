-- Defense in depth: customer writes must independently prove the referenced
-- website belongs to the authenticated tenant, not merely trust tenant_id.

drop policy if exists media_customer_manage_own on public.media;
create policy media_customer_manage_own on public.media for all to authenticated
using (tenant_id = public.current_tenant_id() and exists (select 1 from public.websites w where w.id = media.website_id and w.tenant_id = public.current_tenant_id()))
with check (tenant_id = public.current_tenant_id() and exists (select 1 from public.websites w where w.id = media.website_id and w.tenant_id = public.current_tenant_id()));

drop policy if exists social_links_customer_manage_own on public.social_links;
create policy social_links_customer_manage_own on public.social_links for all to authenticated
using (tenant_id = public.current_tenant_id() and exists (select 1 from public.websites w where w.id = social_links.website_id and w.tenant_id = public.current_tenant_id()))
with check (tenant_id = public.current_tenant_id() and exists (select 1 from public.websites w where w.id = social_links.website_id and w.tenant_id = public.current_tenant_id()));

drop policy if exists website_content_customer_insert_draft on public.website_content;
drop policy if exists website_content_customer_update_draft on public.website_content;
drop policy if exists website_content_customer_delete_draft on public.website_content;
create policy website_content_customer_insert_draft on public.website_content for insert to authenticated
with check (tenant_id = public.current_tenant_id() and content_status = 'DRAFT' and exists (select 1 from public.websites w where w.id = website_content.website_id and w.tenant_id = public.current_tenant_id()));
create policy website_content_customer_update_draft on public.website_content for update to authenticated
using (tenant_id = public.current_tenant_id() and content_status in ('DRAFT','PUBLISHED') and exists (select 1 from public.websites w where w.id = website_content.website_id and w.tenant_id = public.current_tenant_id()))
with check (tenant_id = public.current_tenant_id() and content_status = 'DRAFT' and exists (select 1 from public.websites w where w.id = website_content.website_id and w.tenant_id = public.current_tenant_id()));
create policy website_content_customer_delete_draft on public.website_content for delete to authenticated
using (tenant_id = public.current_tenant_id() and content_status = 'DRAFT' and exists (select 1 from public.websites w where w.id = website_content.website_id and w.tenant_id = public.current_tenant_id()));
