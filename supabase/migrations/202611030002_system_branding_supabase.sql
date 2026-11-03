-- Persist system branding per organization owner.
-- Logo files are stored as WebP in the existing public promo-images bucket.

create table if not exists public.system_branding (
  user_id uuid primary key references auth.users(id) on delete cascade,
  main_name text not null default 'Meshez Kadi',
  system_theme text not null default 'Invitation System',
  slogan text not null default 'Invite Them Easy',
  logo_url text,
  logo_path text,
  logo_scale integer not null default 100
    check (logo_scale between 50 and 200),
  updated_at timestamptz not null default now()
);

alter table public.system_branding enable row level security;

drop policy if exists "system_branding_owner_select" on public.system_branding;
create policy "system_branding_owner_select"
  on public.system_branding
  for select
  to authenticated
  using (public.get_org_owner_id() = user_id);

drop policy if exists "system_branding_owner_insert" on public.system_branding;
create policy "system_branding_owner_insert"
  on public.system_branding
  for insert
  to authenticated
  with check (public.get_org_owner_id() = user_id);

drop policy if exists "system_branding_owner_update" on public.system_branding;
create policy "system_branding_owner_update"
  on public.system_branding
  for update
  to authenticated
  using (public.get_org_owner_id() = user_id)
  with check (public.get_org_owner_id() = user_id);

grant select, insert, update on public.system_branding to authenticated;

-- promo-images is already used by the app for public promotional images.
-- Ensure it is public so the logo URL can be rendered on sign-in and navigation.
update storage.buckets
set public = true
where id = 'promo-images';

-- Managers/admins upload beneath the organization owner's UUID folder.
drop policy if exists "system_branding_logo_insert" on storage.objects;
create policy "system_branding_logo_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'promo-images'
    and (storage.foldername(name))[1] = public.get_org_owner_id()::text
  );

drop policy if exists "system_branding_logo_delete" on storage.objects;
create policy "system_branding_logo_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'promo-images'
    and (storage.foldername(name))[1] = public.get_org_owner_id()::text
  );
