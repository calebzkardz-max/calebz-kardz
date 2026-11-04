-- Allow all supported event categories used by the Event Management form.
-- Preserve the existing values and add the extended event types.
begin;

do $$
declare
  target_table regclass;
  constraint_record record;
  type_column text;
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
    raise notice 'Neither public.events nor public.event exists; no event type constraint was changed.';
    return;
  end if;

  select con.oid, con.conname, pg_get_constraintdef(con.oid) as definition
    into constraint_record
  from pg_constraint con
  where con.conrelid = target_table
    and con.contype = 'c'
    and con.conname = 'events_event_type_check'
  limit 1;

  if constraint_record.oid is not null then
    if position('event_type' in constraint_record.definition) > 0 then
      type_column := 'event_type';
    else
      type_column := 'type';
    end if;
    execute format('alter table %s drop constraint %I', target_table, constraint_record.conname);
  else
    if exists (
      select 1 from information_schema.columns
      where table_schema = split_part(target_table::text,'.',1)
        and table_name = split_part(target_table::text,'.',2)
        and column_name = 'event_type'
    ) then
      type_column := 'event_type';
    else
      type_column := 'type';
    end if;
  end if;

  select string_agg(quote_literal(v), ',') into values_sql
  from unnest(allowed_values) as v;

  execute format(
    'alter table %s add constraint events_event_type_check check (%I in (%s))',
    target_table, type_column, values_sql
  );
end $$;

commit;
