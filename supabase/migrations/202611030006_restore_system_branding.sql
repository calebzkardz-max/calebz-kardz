-- Restore the editable system branding feature removed by the retired migration.
-- Safe to run whether the previous system_branding table still exists or was dropped.

begin;

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

-- Public read-only endpoint used by Sign In / Sign Up before authentication.
create or replace function public.get_public_system_branding()
returns table (
  main_name text,
  system_theme text,
  slogan text,
  logo_url text,
  logo_path text,
  logo_scale integer
)
language sql
stable
security definer
set search_path = public
as $$
  select b.main_name, b.system_theme, b.slogan, b.logo_url, b.logo_path, b.logo_scale
  from public.system_branding b
  order by b.updated_at desc
  limit 1;
$$;

revoke all on function public.get_public_system_branding() from public;
grant execute on function public.get_public_system_branding() to anon, authenticated;

-- Keep the existing public promo-images bucket and its other images.
update storage.buckets set public = true where id = 'promo-images';

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

commit;
