-- Additive migration only. Do not modify or rerun earlier migrations.
--
-- storage.buckets has RLS enabled with no policies, so the authenticated role
-- cannot resolve the private website-media bucket and every upload and signed
-- URL request fails with "Bucket not found" before object RLS is ever reached.
-- This grants visibility of that one bucket row only. Object access remains
-- governed solely by the website_media_tenant_* policies on storage.objects.

drop policy if exists website_media_bucket_visible_to_authenticated on storage.buckets;

create policy website_media_bucket_visible_to_authenticated
on storage.buckets
for select
to authenticated
using (id = 'website-media');
