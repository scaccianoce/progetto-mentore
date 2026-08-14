-- Eseguire una volta nel SQL Editor del progetto Supabase.
-- La funzione espone soltanto metadati dello schema public, mai i dati.
create or replace function public.app_database_schema()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'version', 1,
    'tables', coalesce(jsonb_agg(table_info order by table_info->>'name'), '[]'::jsonb)
  )
  from (
    select jsonb_build_object(
      'name', cls.relname,
      'comment', pg_catalog.obj_description(cls.oid, 'pg_class'),
      'primary_key', coalesce((
        select jsonb_agg(att.attname order by key_part.position)
        from pg_catalog.pg_constraint pk
        cross join lateral unnest(pk.conkey) with ordinality as key_part(attnum, position)
        join pg_catalog.pg_attribute att
          on att.attrelid = cls.oid and att.attnum = key_part.attnum
        where pk.conrelid = cls.oid and pk.contype = 'p'
      ), '[]'::jsonb),
      'columns', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'name', att.attname,
            'position', att.attnum,
            'data_type', pg_catalog.format_type(att.atttypid, att.atttypmod),
            'nullable', not att.attnotnull,
            'default', pg_catalog.pg_get_expr(def.adbin, def.adrelid),
            'identity', att.attidentity <> '',
            'generated', att.attgenerated <> '',
            'comment', pg_catalog.col_description(att.attrelid, att.attnum),
            'enum_values', coalesce((
              select jsonb_agg(enum.enumlabel order by enum.enumsortorder)
              from pg_catalog.pg_enum enum
              where enum.enumtypid = att.atttypid
            ), '[]'::jsonb),
            'foreign_key', (
              select jsonb_build_object(
                'table', target.relname,
                'column', target_att.attname
              )
              from pg_catalog.pg_constraint fk
              cross join lateral unnest(fk.conkey) with ordinality as source_key(attnum, position)
              cross join lateral unnest(fk.confkey) with ordinality as target_key(attnum, position)
              join pg_catalog.pg_class target on target.oid = fk.confrelid
              join pg_catalog.pg_namespace target_ns on target_ns.oid = target.relnamespace
              join pg_catalog.pg_attribute target_att
                on target_att.attrelid = fk.confrelid
               and target_att.attnum = target_key.attnum
              where fk.conrelid = cls.oid
                and fk.contype = 'f'
                and source_key.attnum = att.attnum
                and source_key.position = target_key.position
                and target_ns.nspname = 'public'
              limit 1
            )
          ) order by att.attnum
        )
        from pg_catalog.pg_attribute att
        left join pg_catalog.pg_attrdef def
          on def.adrelid = att.attrelid and def.adnum = att.attnum
        where att.attrelid = cls.oid
          and att.attnum > 0
          and not att.attisdropped
      ), '[]'::jsonb)
    ) as table_info
    from pg_catalog.pg_class cls
    join pg_catalog.pg_namespace ns on ns.oid = cls.relnamespace
    where ns.nspname = 'public'
      and cls.relkind in ('r', 'p')
  ) tables;
$$;

revoke all on function public.app_database_schema() from public;
revoke all on function public.app_database_schema() from anon;
grant execute on function public.app_database_schema() to authenticated;

-- Direttive UI facoltative nei commenti di colonna:
-- comment on column public.news.testo is
--   '@app:label=Contenuto @app:formatted';
--
-- Disponibili: @app:multiline, @app:formatted, @app:hidden,
-- @app:readonly e @app:label=Etichetta visualizzata.
