-- Permanently remove the retired system name/logo branding feature.
-- Keep the promo-images bucket and all non-branding promotional images intact.

begin;

-- Storage objects must be removed through the Supabase Storage API or Dashboard.
-- Do not DELETE directly from storage.objects; Supabase protects this table.

drop policy if exists "system_branding_logo_insert" on storage.objects;
drop policy if exists "system_branding_logo_delete" on storage.objects;

drop function if exists public.get_public_system_branding();

drop table if exists public.system_branding cascade;

commit;
