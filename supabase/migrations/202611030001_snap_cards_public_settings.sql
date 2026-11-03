-- Snap Cards public contact number and six portfolio images
-- Run this once in Supabase SQL Editor for project fymjjqembyrlwgktbcgf.

create table if not exists public.snap_cards_public_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  whatsapp_phone text not null default '',
  portfolio_images jsonb not null default '[null,null,null,null,null,null]'::jsonb,
  updated_at timestamptz not null default now(),
  constraint snap_cards_portfolio_images_is_array
    check (jsonb_typeof(portfolio_images) = 'array')
);

alter table public.snap_cards_public_settings enable row level security;

grant select on public.snap_cards_public_settings to authenticated;
grant insert, update, delete on public.snap_cards_public_settings to authenticated;

drop policy if exists snap_cards_public_settings_owner_manage
  on public.snap_cards_public_settings;

create policy snap_cards_public_settings_owner_manage
  on public.snap_cards_public_settings
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Public invitation pages can read ONLY the public contact number and portfolio
-- for the owner id included in the invitation event. No anonymous write access.
create or replace function public.get_snap_cards_public_settings(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'whatsapp_phone', coalesce(s.whatsapp_phone, ''),
    'portfolio_images', coalesce(s.portfolio_images, '[null,null,null,null,null,null]'::jsonb)
  )
  into result
  from public.snap_cards_public_settings s
  where s.user_id = p_user_id;

  return coalesce(
    result,
    jsonb_build_object(
      'whatsapp_phone', '',
      'portfolio_images', '[null,null,null,null,null,null]'::jsonb
    )
  );
end;
$$;

grant execute on function public.get_snap_cards_public_settings(uuid) to anon, authenticated;
