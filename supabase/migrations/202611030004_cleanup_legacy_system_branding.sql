-- Remove only orphaned legacy system-branding logo objects.
-- Keep every logo_path that is still referenced by an active system_branding row.
delete from storage.objects as object
where object.bucket_id = 'promo-images'
  and object.name like '%/system-branding/%'
  and not exists (
    select 1
    from public.system_branding as active_brand
    where active_brand.logo_path = object.name
  );
