-- Public, read-only branding for the unauthenticated Sign In / Sign Up screen.
-- This app displays one shared system identity before a user can authenticate.
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
  select
    sb.main_name,
    sb.system_theme,
    sb.slogan,
    sb.logo_url,
    sb.logo_path,
    sb.logo_scale
  from public.system_branding sb
  order by sb.updated_at desc
  limit 1;
$$;

revoke all on function public.get_public_system_branding() from public;
grant execute on function public.get_public_system_branding() to anon, authenticated;
