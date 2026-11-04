-- Allow all event categories offered by the Event Management and Template forms.
-- Detect the constrained column from the existing check definition so this works
-- with installations that named it either "type" or "event_type".
begin;

do $$
declare
  target_table regclass;
  constraint_oid oid;
  constraint_name text;
  constraint_definition text;
  type_column text;
  has_event_type boolean;
  allowed_values text[] := array[
    'harusi','sendoff','birthday','other',
    'graduation','engagement','anniversary','bridal_shower','baby_shower',
    'kitchen_party','conference','corporate','religious','fundraiser',
    'reunion','memorial'
  ];
  values_sql text;
begin
  target_table := to_regclass('public.events');
  if target_table is null then
    target_table := to_regclass('public.event');
  end if;
  if target_table is null then
    raise exception 'Could not find public.events or public.event table. Event type migration was not applied.';
  end if;

  select con.oid, con.conname, pg_get_constraintdef(con.oid)
    into constraint_oid, constraint_name, constraint_definition
  from pg_constraint con
  where con.conrelid = target_table
    and con.contype = 'c'
    and con.conname = 'events_event_type_check'
  limit 1;

  if constraint_oid is not null then
    type_column := case
      when position('event_type' in constraint_definition) > 0 then 'event_type'
      else 'type'
    end;
    execute format('alter table %s drop constraint %I', target_table, constraint_name);
  else
    select exists (
      select 1 from pg_attribute
      where attrelid = target_table
        and attname = 'event_type'
        and not attisdropped
    ) into has_event_type;
    type_column := case when has_event_type then 'event_type' else 'type' end;
  end if;

  select string_agg(quote_literal(v), ',') into values_sql
  from unnest(allowed_values) as v;

  execute format(
    'alter table %s add constraint events_event_type_check check (%I in (%s))',
    target_table, type_column, values_sql
  );
end $$;

commit;
