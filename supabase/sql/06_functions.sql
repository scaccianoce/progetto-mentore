-- ============================================================================
-- 06 - FUNZIONI POSTGRESQL
-- VERSIONE CORRETTA V2
--
-- Questo file disabilita temporaneamente la verifica dei corpi delle funzioni
-- durante la loro creazione. È il comportamento adatto a una ricostruzione
-- dello schema, perché alcune funzioni richiamano altre funzioni che possono
-- essere definite più avanti nello stesso script.
--
-- NON modifica dati.
-- Eseguire SOLO sul nuovo progetto Supabase.
-- ============================================================================

SET check_function_bodies = false;

-- --------------------------------------------------------------------------
-- aggiorna_updated_at_house_of_mentore()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.aggiorna_updated_at_house_of_mentore()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

-- --------------------------------------------------------------------------
-- anagrafica_e_attiva(p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.anagrafica_e_attiva(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.anagrafica_riservata ar
    where ar.user_id = p_user_id
      and ar.attivo = true
  );
$function$;

-- --------------------------------------------------------------------------
-- anno_accademico_attivo()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.anno_accademico_attivo()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select codice
  from public.anni_accademici
  where stato = 'attivo' or corrente is true
  order by case when stato = 'attivo' then 0 else 1 end, codice desc
  limit 1;
$function$;

-- --------------------------------------------------------------------------
-- anno_accademico_preparazione()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.anno_accademico_preparazione()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select codice
  from public.anni_accademici
  where stato = 'preparazione'
  order by codice desc
  limit 1;
$function$;

-- --------------------------------------------------------------------------
-- app_backoffice_admin(p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_backoffice_admin(p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_user_id
      and ur.role::text in ('owner', 'organizer')
  );
$function$;

-- --------------------------------------------------------------------------
-- app_database_schema()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_database_schema()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- --------------------------------------------------------------------------
-- app_owner(p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_owner(p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_user_id
      and ur.role::text = 'owner'
  );
$function$;

-- --------------------------------------------------------------------------
-- crea_anagrafica_riservata()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crea_anagrafica_riservata()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.anagrafica_riservata (
    user_id
  )
  values (
    new.user_id
  )
  on conflict (user_id)
  do nothing;

  return new;
end;
$function$;

-- --------------------------------------------------------------------------
-- crea_mentoraggio_da_insegnamento()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crea_mentoraggio_da_insegnamento()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.mentoraggi (
    insegnamento_id
  )
  values (
    new.id
  )
  on conflict (insegnamento_id)
  do nothing;

  return new;
end;
$function$;

-- --------------------------------------------------------------------------
-- has_role(allowed_roles app_role[])
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_role(allowed_roles app_role[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = any(allowed_roles)
  );
$function$;

-- --------------------------------------------------------------------------
-- insegnamenti_miei()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.insegnamenti_miei()
 RETURNS SETOF insegnamenti
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  select i.*

  from public.insegnamenti i

  where i.docente_id = auth.uid()

  order by i.created_at nulls last;

$function$;

-- --------------------------------------------------------------------------
-- is_docente_del_mentoraggio(p_mentoraggio_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_docente_del_mentoraggio(p_mentoraggio_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1
    from public.mentoraggi m
    join public.insegnamenti i
      on i.id = m.insegnamento_id
    where m.id = p_mentoraggio_id
      and i.docente_id = auth.uid()
  );
$function$;

-- --------------------------------------------------------------------------
-- is_mentore_assegnato(p_mentoraggio_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_mentore_assegnato(p_mentoraggio_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1
    from public.mentoraggio_mentori mm
    where mm.mentoraggio_id = p_mentoraggio_id
      and mm.mentore_id = auth.uid()
  );
$function$;

-- --------------------------------------------------------------------------
-- is_mentore_di_insegnamento(p_insegnamento_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_mentore_di_insegnamento(p_insegnamento_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.mentoraggi m
    join public.mentoraggio_mentori mm
      on mm.mentoraggio_id = m.id
    where m.insegnamento_id = p_insegnamento_id
      and mm.mentore_id = auth.uid()
  );
$function$;

-- --------------------------------------------------------------------------
-- mentoraggi_del_mentee()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggi_del_mentee()
 RETURNS SETOF jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    to_jsonb(m) - coalesce(
      array(
        select c.column_name
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'mentoraggi'
          and c.column_name like 'osservazioni%'
      ),
      array[]::text[]
    )
  from public.mentoraggi m
  join public.insegnamenti i
    on i.id = m.insegnamento_id
  where i.docente_id = auth.uid()
  order by m.anno_accademico desc, m.id;
$function$;

-- --------------------------------------------------------------------------
-- mentoraggi_del_mentore()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggi_del_mentore()
 RETURNS SETOF mentoraggi
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select distinct m.*
  from public.mentoraggi m
  join public.mentoraggio_mentori mm
    on mm.mentoraggio_id = m.id
  where mm.mentore_id = auth.uid()
  order by m.anno_accademico desc, m.id;
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_anno_corrente(p_mentoraggio_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_anno_corrente(p_mentoraggio_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.mentoraggi m
    join public.anni_accademici aa
      on aa.codice = m.anno_accademico
    where m.id = p_mentoraggio_id
      and aa.corrente is true
  );
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_backoffice()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_backoffice()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role::text in ('owner', 'organizer')
  );
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_utente_associato(p_mentoraggio_id uuid, p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_utente_associato(p_mentoraggio_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.mentoraggio_mentori mm
    where mm.mentoraggio_id = p_mentoraggio_id
      and mm.mentore_id = p_user_id
  );
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_utente_mentee(p_mentoraggio_id uuid, p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_utente_mentee(p_mentoraggio_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.mentoraggi m
    join public.insegnamenti i
      on i.id = m.insegnamento_id
    where m.id = p_mentoraggio_id
      and i.docente_id = p_user_id
  );
$function$;

-- --------------------------------------------------------------------------
-- notifiche_amministratore()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_amministratore()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('owner', 'organizer')
  );
$function$;

-- --------------------------------------------------------------------------
-- notifiche_anno_corrente()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_anno_corrente()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select codice
  from public.anni_accademici
  where corrente is true
  limit 1;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_condizioni_ok(p_record jsonb, p_configurazione jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_condizioni_ok(p_record jsonb, p_configurazione jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare
  v_cond jsonb;
  v_campo text;
  v_operatore text;
  v_attuale jsonb;
  v_attuale_testo text;
  v_atteso text;
begin
  if p_configurazione is null
     or jsonb_typeof(p_configurazione->'condizioni') <> 'array'
     or jsonb_array_length(p_configurazione->'condizioni') = 0 then
    return true;
  end if;

  for v_cond in
    select value
    from jsonb_array_elements(p_configurazione->'condizioni')
  loop
    v_campo := nullif(v_cond->>'campo', '');
    v_operatore := lower(coalesce(v_cond->>'operatore', 'eq'));
    v_atteso := v_cond->>'valore';

    if v_campo is null then
      continue;
    end if;

    v_attuale := p_record->v_campo;
    v_attuale_testo := p_record->>v_campo;

    case v_operatore
      when 'is_null' then
        if v_attuale is not null and v_attuale <> 'null'::jsonb then return false; end if;
      when 'not_null' then
        if v_attuale is null or v_attuale = 'null'::jsonb then return false; end if;
      when 'eq' then
        if coalesce(v_attuale_testo, '') <> coalesce(v_atteso, '') then return false; end if;
      when 'neq' then
        if coalesce(v_attuale_testo, '') = coalesce(v_atteso, '') then return false; end if;
      when 'true' then
        if lower(coalesce(v_attuale_testo, 'false')) not in ('true', 't', '1', 'yes') then return false; end if;
      when 'false' then
        if lower(coalesce(v_attuale_testo, 'false')) in ('true', 't', '1', 'yes') then return false; end if;
      else
        raise exception 'Operatore condizione notifiche non supportato: %', v_operatore;
    end case;
  end loop;

  return true;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_config_destinatari_regola(p_destinatari text, p_record jsonb, p_anno text, p_configurazione jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_config_destinatari_regola(p_destinatari text, p_record jsonb, p_anno text, p_configurazione jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare
  v_campo_rif text := coalesce(
    nullif(p_configurazione->>'campo_riferimento_destinatari', ''),
    'id'
  );
  v_campo_id text := coalesce(
    nullif(p_configurazione->>'campo_id_principale', ''),
    'id'
  );
  v_rif text;
  v_rel jsonb;
begin
  v_rif := nullif(p_record->>v_campo_rif, '');

  case p_destinatari
    when 'iscritti_evento' then
      return jsonb_build_object('evento_id', v_rif);
    when 'iscritti_house_of_mentore' then
      return jsonb_build_object('house_of_mentore_id', v_rif);
    when 'mentor', 'senior', 'mentee', 'mentor_senior', 'mentor_senior_mentee' then
      return jsonb_build_object(
        'mentoraggio_id', v_rif,
        'anno_accademico', p_anno
      );
    when 'anno_accademico' then
      return jsonb_build_object('anno_accademico', p_anno);
    when 'relazionale' then
      v_rel := coalesce(p_configurazione->'destinatari_relazionali', '{}'::jsonb);
      return v_rel || jsonb_build_object(
        'tabella_principale', p_configurazione->>'tabella_principale',
        'campo_id_principale', v_campo_id,
        'record_id', nullif(p_record->>v_campo_id, ''),
        'anno_accademico', p_anno
      );
    else
      return '{}'::jsonb;
  end case;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_conta_destinatari(p_messaggio_id uuid)
-- --------------------------------------------------------------------------
-- CREATE OR REPLACE FUNCTION public.notifiche_conta_destinatari(p_messaggio_id uuid)
--  RETURNS integer
-- LANGUAGE sql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
--  select count(*)::integer
--  from public.notifiche_destinatari nd
--  where nd.messaggio_id = p_messaggio_id;
--$function$;

-- --------------------------------------------------------------------------
-- notifiche_dettaglio_destinatari(p_messaggio_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_dettaglio_destinatari(p_messaggio_id uuid)
 RETURNS TABLE(user_id uuid, nome text, cognome text, email_unipa text, stato text, inviato_at timestamp with time zone, letto_at timestamp with time zone, errore text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role::text in ('owner', 'organizer')
  ) then
    raise exception 'Utente non autorizzato.'
      using errcode = '42501';
  end if;

  return query
  select
    nd.user_id,
    a.nome::text,
    a.cognome::text,
    a.email_unipa::text,
    nd.stato::text,
    nd.inviato_at,
    nd.letto_at,
    nd.errore::text
  from public.notifiche_destinatari nd
  left join public.anagrafica a
    on a.user_id = nd.user_id
  where nd.messaggio_id = p_messaggio_id
  order by
    a.cognome nulls last,
    a.nome nulls last,
    nd.created_at;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_disattiva_dispositivo(p_token text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_disattiva_dispositivo(p_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato';
  end if;

  update public.notifiche_dispositivi
  set
    attivo = false,
    updated_at = now()
  where token = p_token
    and user_id = v_user_id;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_elenco_utenti_attivi()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_elenco_utenti_attivi()
 RETURNS TABLE(user_id uuid, nome text, cognome text, email_unipa text, role text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin

  -- ----------------------------------------------------------
  -- Controllo autorizzazione
  -- ----------------------------------------------------------

  if not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role::text in ('owner', 'organizer')
  ) then
    raise exception 'Utente non autorizzato.'
      using errcode = '42501';
  end if;


  -- ----------------------------------------------------------
  -- Restituisce esclusivamente persone ATTIVE
  -- ----------------------------------------------------------

  return query

  select
    a.user_id,
    a.nome::text,
    a.cognome::text,
    a.email_unipa::text,
    ur.role::text

  from public.anagrafica a

  join public.anagrafica_riservata ar
    on ar.user_id = a.user_id

  left join public.user_roles ur
    on ur.user_id = a.user_id

  where ar.attivo is true

  order by
    a.cognome,
    a.nome;

end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_inserisci_destinatari_relazionali(p_messaggio_id uuid, p_configurazione jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_inserisci_destinatari_relazionali(p_messaggio_id uuid, p_configurazione jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tabella_principale text := nullif(p_configurazione->>'tabella_principale', '');
  v_campo_id text := coalesce(nullif(p_configurazione->>'campo_id_principale', ''), 'id');
  v_record_id text := nullif(p_configurazione->>'record_id', '');
  v_tabella_target text := nullif(p_configurazione->>'tabella', '');
  v_campo_user text := nullif(p_configurazione->>'campo_user_id', '');
  v_percorso jsonb := coalesce(p_configurazione->'percorso', '[]'::jsonb);
  v_condizioni jsonb := coalesce(p_configurazione->'condizioni', '[]'::jsonb);
  v_edge jsonb;
  v_cond jsonb;
  v_tabella_corrente text;
  v_alias_corrente integer := 0;
  v_alias_successivo integer;
  v_sql text;
  v_predicato text;
  v_operatore text;
  v_campo text;
  v_valore text;
  v_count integer := 0;
begin
  if v_tabella_principale is null or v_record_id is null
     or v_tabella_target is null or v_campo_user is null then
    raise exception 'Configurazione destinatari relazionali incompleta.';
  end if;

  v_tabella_corrente := v_tabella_principale;
  v_sql := format(
    'insert into public.notifiche_destinatari (messaggio_id, user_id) '
    'select distinct $1, TARGET_ALIAS.%I '
    'from public.%I t0 ',
    v_campo_user,
    v_tabella_principale
  );

  for v_edge in
    select value from jsonb_array_elements(v_percorso)
  loop
    if v_edge->>'da_tabella' <> v_tabella_corrente then
      raise exception 'Percorso destinatari non continuo: attesa %, trovata %.',
        v_tabella_corrente, v_edge->>'da_tabella';
    end if;

    v_alias_successivo := v_alias_corrente + 1;
    v_sql := v_sql || format(
      ' join public.%I t%s on t%s.%I = t%s.%I ',
      v_edge->>'a_tabella',
      v_alias_successivo,
      v_alias_corrente,
      v_edge->>'da_campo',
      v_alias_successivo,
      v_edge->>'a_campo'
    );
    v_tabella_corrente := v_edge->>'a_tabella';
    v_alias_corrente := v_alias_successivo;
  end loop;

  if v_tabella_corrente <> v_tabella_target then
    raise exception 'Il percorso destinatari termina su %, non su %.',
      v_tabella_corrente, v_tabella_target;
  end if;

  v_sql := replace(v_sql, 'TARGET_ALIAS', 't' || v_alias_corrente::text);
  v_sql := v_sql || format(
    ' join public.anagrafica_riservata ar '
    '   on ar.user_id = t%s.%I and ar.attivo is true '
    ' where t0.%I::text = $2 '
    '   and t%s.%I is not null ',
    v_alias_corrente,
    v_campo_user,
    v_campo_id,
    v_alias_corrente,
    v_campo_user
  );

  -- Condizioni opzionali direttamente sulla tabella destinatari.
  for v_cond in
    select value from jsonb_array_elements(v_condizioni)
  loop
    v_campo := nullif(v_cond->>'campo', '');
    if v_campo is null then continue; end if;
    v_operatore := lower(coalesce(v_cond->>'operatore', 'eq'));
    v_valore := v_cond->>'valore';

    case v_operatore
      when 'is_null' then
        v_predicato := format('t%s.%I is null', v_alias_corrente, v_campo);
      when 'not_null' then
        v_predicato := format('t%s.%I is not null', v_alias_corrente, v_campo);
      when 'eq' then
        v_predicato := format('coalesce(t%s.%I::text, '''') = %L', v_alias_corrente, v_campo, coalesce(v_valore, ''));
      when 'neq' then
        v_predicato := format('coalesce(t%s.%I::text, '''') <> %L', v_alias_corrente, v_campo, coalesce(v_valore, ''));
      when 'true' then
        v_predicato := format('lower(coalesce(t%s.%I::text, ''false'')) in (''true'',''t'',''1'',''yes'')', v_alias_corrente, v_campo);
      when 'false' then
        v_predicato := format('lower(coalesce(t%s.%I::text, ''false'')) not in (''true'',''t'',''1'',''yes'')', v_alias_corrente, v_campo);
      else
        raise exception 'Operatore destinatari relazionali non supportato: %', v_operatore;
    end case;

    v_sql := v_sql || ' and ' || v_predicato;
  end loop;

  v_sql := v_sql || ' on conflict (messaggio_id, user_id) do nothing';

  execute v_sql using p_messaggio_id, v_record_id;

  select count(*)::integer into v_count
  from public.notifiche_destinatari
  where messaggio_id = p_messaggio_id
    and stato = 'da_inviare';

  return v_count;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_puo_gestire()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_puo_gestire()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('owner', 'organizer')
  );
$function$;

-- --------------------------------------------------------------------------
-- notifiche_registra_dispositivo(p_token text, p_piattaforma text, p_device_id text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_registra_dispositivo(p_token text, p_piattaforma text, p_device_id text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato';
  end if;

  if p_token is null or btrim(p_token) = '' then
    raise exception 'Token dispositivo mancante';
  end if;

  if p_piattaforma not in ('android', 'ios', 'web') then
    raise exception 'Piattaforma non valida: %', p_piattaforma;
  end if;

  p_device_id := btrim(p_device_id);
  if p_device_id is null or p_device_id = '' or length(p_device_id) > 200 then
    raise exception 'Identificatore installazione non valido';
  end if;

  -- Serializza due registrazioni contemporanee della stessa installazione.
  perform pg_advisory_xact_lock(hashtextextended(p_device_id, 0));

  select id into v_id
  from public.notifiche_dispositivi
  where device_id = p_device_id;

  if v_id is null then
    -- Migra senza duplicarla un'eventuale riga preesistente nota per token.
    select id into v_id
    from public.notifiche_dispositivi
    where token = p_token;
  end if;

  if v_id is null then
    insert into public.notifiche_dispositivi (
      user_id, token, device_id, piattaforma, attivo, ultimo_accesso
    ) values (
      v_user_id, p_token, p_device_id,
      p_piattaforma::public.notifiche_piattaforma, true, now()
    )
    returning id into v_id;
  else
    -- Se il token e' stato ruotato, libera l'eventuale vecchia riga legacy.
    delete from public.notifiche_dispositivi
    where token = p_token and id <> v_id;

    update public.notifiche_dispositivi
    set user_id = v_user_id,
        token = p_token,
        device_id = p_device_id,
        piattaforma = p_piattaforma::public.notifiche_piattaforma,
        attivo = true,
        ultimo_accesso = now(),
        updated_at = now()
    where id = v_id;
  end if;

  return v_id;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_render_template(p_template text, p_record jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_render_template(p_template text, p_record jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare
  v_result text := coalesce(p_template, '');
  v_key text;
  v_value text;
begin
  if p_record is null then
    return v_result;
  end if;

  for v_key, v_value in
    select key, value
    from jsonb_each_text(p_record)
  loop
    v_result := replace(v_result, '{{' || v_key || '}}', coalesce(v_value, ''));
  end loop;

  return v_result;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_segna_letta(p_destinatario_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_segna_letta(p_destinatario_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.notifiche_destinatari
  set
    stato = 'letto',
    letto_at = coalesce(letto_at, now()),
    updated_at = now()
  where id = p_destinatario_id
    and user_id = auth.uid();

  if not found then
    raise exception 'Notifica non trovata o non appartenente all''utente corrente.';
  end if;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_set_updated_at()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin

  new.updated_at = now();

  return new;

end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_utente_amministratore()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_utente_amministratore()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('owner', 'organizer')
  );
$function$;

-- --------------------------------------------------------------------------
-- notifiche_utente_attivo(p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_utente_attivo(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (

    select 1

    from public.anagrafica_riservata ar

    where ar.user_id = p_user_id

      and ar.attivo is true

  );
$function$;

-- --------------------------------------------------------------------------
-- notifiche_valore_condizione_ok(p_valore jsonb, p_operatore text, p_atteso text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_valore_condizione_ok(p_valore jsonb, p_operatore text, p_atteso text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare
  v_testo text;
  v_op text := lower(coalesce(p_operatore, 'eq'));
begin
  if p_valore is null or p_valore = 'null'::jsonb then
    v_testo := null;
  else
    v_testo := trim(both '"' from p_valore::text);
  end if;

  case v_op
    when 'is_null' then return p_valore is null or p_valore = 'null'::jsonb;
    when 'not_null' then return p_valore is not null and p_valore <> 'null'::jsonb;
    when 'eq' then return coalesce(v_testo, '') = coalesce(p_atteso, '');
    when 'neq' then return coalesce(v_testo, '') <> coalesce(p_atteso, '');
    when 'true' then return lower(coalesce(v_testo, 'false')) in ('true', 't', '1', 'yes');
    when 'false' then return lower(coalesce(v_testo, 'false')) not in ('true', 't', '1', 'yes');
    else
      raise exception 'Operatore condizione notifiche non supportato: %', v_op;
  end case;
end;
$function$;

-- --------------------------------------------------------------------------
-- puo_modificare(p_ambito ambito_modifica, p_anno_accademico character varying)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.puo_modificare(p_ambito ambito_modifica, p_anno_accademico character varying)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role in (
          'owner'::public.app_role,
          'organizer'::public.app_role
        )
    )
    or exists (
      select 1
      from public.abilitazioni_modifica am
      where am.user_id = auth.uid()
        and am.ambito = p_ambito
        and am.anno_accademico = p_anno_accademico
        and am.abilitata = true
        and am.revocata_at is null
        and (
          am.scade_at is null
          or am.scade_at > now()
        )
    );
$function$;

-- --------------------------------------------------------------------------
-- questionario_pubblico_carica(p_token uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.questionario_pubblico_carica(p_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_q public.questionari%rowtype;
  v_risultato jsonb;
begin
  select * into v_q
  from public.questionari q
  where q.token_pubblico = p_token
    and q.provider = 'pubblico'
    and q.aperto = true
    and (q.data_apertura is null or q.data_apertura <= now())
    and (q.data_chiusura is null or q.data_chiusura >= now());

  if not found then
    raise exception 'Questionario non disponibile.';
  end if;

  select jsonb_build_object(
    'questionario', jsonb_build_object(
      'id', v_q.id,
      'titolo', v_q.titolo,
      'template_id', v_q.template_id
    ),
    'domande', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', d.id,
          'ordine', d.ordine,
          'testo', d.testo,
          'tipo', d.tipo,
          'obbligatoria', d.obbligatoria,
          'opzioni', d.opzioni
        ) order by d.ordine
      )
      from public.questionari_domande d
      where d.template_id = v_q.template_id
    ), '[]'::jsonb)
  ) into v_risultato;

  return v_risultato;
end;
$function$;

-- --------------------------------------------------------------------------
-- questionario_pubblico_invia(p_token uuid, p_risposte jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.questionario_pubblico_invia(p_token uuid, p_risposte jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_q public.questionari%rowtype;
  v_compilazione uuid;
  v_domanda record;
  v_valore jsonb;
begin
  select * into v_q
  from public.questionari q
  where q.token_pubblico = p_token
    and q.provider = 'pubblico'
    and q.aperto = true
    and (q.data_apertura is null or q.data_apertura <= now())
    and (q.data_chiusura is null or q.data_chiusura >= now());

  if not found then
    raise exception 'Questionario non disponibile.';
  end if;

  for v_domanda in
    select id, obbligatoria
    from public.questionari_domande
    where template_id = v_q.template_id
  loop
    if v_domanda.obbligatoria
       and not (p_risposte ? v_domanda.id::text) then
      raise exception 'Manca una risposta obbligatoria.';
    end if;
  end loop;

  insert into public.questionari_compilazioni(questionario_id, user_id)
  values (v_q.id, null)
  returning id into v_compilazione;

  for v_domanda in
    select id
    from public.questionari_domande
    where template_id = v_q.template_id
  loop
    if p_risposte ? v_domanda.id::text then
      v_valore := p_risposte -> v_domanda.id::text;
      insert into public.questionari_risposte(
        compilazione_id, domanda_id, valore
      ) values (
        v_compilazione, v_domanda.id, v_valore
      );
    end if;
  end loop;

  return v_compilazione;
end;
$function$;

-- --------------------------------------------------------------------------
-- questionario_pubblico_leggi(p_token uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.questionario_pubblico_leggi(p_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_q public.questionari%rowtype;
  v_domande jsonb;
begin
  select *
  into v_q
  from public.questionari q
  where q.pubblico_token = p_token
    and q.provider = 'pubblico'
    and q.aperto = true
    and (q.data_apertura is null or q.data_apertura <= now())
    and (q.data_chiusura is null or q.data_chiusura >= now());

  if not found then
    return jsonb_build_object(
      'disponibile', false,
      'messaggio', 'Questionario non disponibile o non più aperto.'
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'ordine', d.ordine,
        'testo', d.testo,
        'tipo', d.tipo,
        'obbligatoria', d.obbligatoria,
        'opzioni', d.opzioni
      )
      order by d.ordine
    ),
    '[]'::jsonb
  )
  into v_domande
  from public.questionari_domande d
  where d.template_id = v_q.template_id;

  return jsonb_build_object(
    'disponibile', true,
    'questionario', jsonb_build_object(
      'id', v_q.id,
      'titolo', v_q.titolo
    ),
    'domande', v_domande
  );
end;
$function$;

-- --------------------------------------------------------------------------
-- richiedi_abilitazione(p_ambito ambito_modifica)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.richiedi_abilitazione(p_ambito ambito_modifica)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_anno varchar(7);
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Utente non autenticato';
  end if;

  select aa.codice
  into v_anno
  from public.anni_accademici aa
  where aa.corrente = true;

  if v_anno is null then
    raise exception 'Anno accademico corrente non configurato';
  end if;

  insert into public.abilitazioni_modifica (
    user_id,
    ambito,
    anno_accademico,
    richiesta_at,
    abilitata
  )
  values (
    v_user_id,
    p_ambito,
    v_anno,
    now(),
    false
  )
  on conflict (
    user_id,
    ambito,
    anno_accademico
  )
  do update set
    richiesta_at = now(),
    abilitata = false,
    abilitata_da = null,
    abilitata_at = null,
    scade_at = null,
    revocata_at = null;
end;
$function$;

-- --------------------------------------------------------------------------
-- set_updated_at()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

-- --------------------------------------------------------------------------
-- utente_owner_organizer(p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.utente_owner_organizer(p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_user_id
      and ur.role::text in ('owner', 'organizer')
  );
$function$;

-- --------------------------------------------------------------------------
-- abilitazione_modifica_imposta(p_user_id uuid, p_ambito ambito_modifica, p_anno_accademico text, p_abilitata boolean, p_scade_at timestamp with time zone)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.abilitazione_modifica_imposta(p_user_id uuid, p_ambito ambito_modifica, p_anno_accademico text, p_abilitata boolean, p_scade_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin

  if not public.utente_owner_organizer() then
    raise exception
      'Operazione consentita solo a owner o organizer.'
      using errcode = '42501';
  end if;


  insert into public.abilitazioni_modifica (
    user_id,
    ambito,
    anno_accademico,
    richiesta_at,
    abilitata,
    abilitata_da,
    abilitata_at,
    scade_at,
    revocata_at
  )
  values (
    p_user_id,
    p_ambito,
    p_anno_accademico,
    now(),
    p_abilitata,
    auth.uid(),
    case
      when p_abilitata then now()
      else null
    end,
    p_scade_at,
    case
      when p_abilitata then null
      else now()
    end
  )

  on conflict (
    user_id,
    ambito,
    anno_accademico
  )
  do update set

    abilitata = excluded.abilitata,

    abilitata_da = auth.uid(),

    abilitata_at =
      case
        when excluded.abilitata
        then now()
        else abilitazioni_modifica.abilitata_at
      end,

    scade_at = excluded.scade_at,

    revocata_at =
      case
        when excluded.abilitata
        then null
        else now()
      end;

end;
$function$;

-- --------------------------------------------------------------------------
-- anno_accademico_corrente()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.anno_accademico_corrente()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.anno_accademico_attivo();
$function$;

-- --------------------------------------------------------------------------
-- anno_accademico_gestione_insegnamenti()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.anno_accademico_gestione_insegnamenti()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    public.anno_accademico_preparazione(),
    public.anno_accademico_attivo()
  );
$function$;

-- --------------------------------------------------------------------------
-- imposta_anno_accademico_corrente(p_codice character varying)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.imposta_anno_accademico_corrente(p_codice character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null
     or not public.has_role(
       array['owner'::public.app_role]
     )
  then
    raise exception 'Operazione consentita soltanto al proprietario'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.anni_accademici
    where codice = p_codice
  ) then
    raise exception 'Anno accademico inesistente: %', p_codice
      using errcode = 'P0002';
  end if;

  update public.anni_accademici
  set corrente = false
  where corrente = true;

  update public.anni_accademici
  set corrente = true
  where codice = p_codice;
end;
$function$;

-- --------------------------------------------------------------------------
-- imposta_stato_anno_accademico(p_codice text, p_stato text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.imposta_stato_anno_accademico(p_codice text, p_stato text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.app_backoffice_admin() then
    raise exception 'Operazione riservata a owner/organizer.' using errcode = '42501';
  end if;

  if p_stato not in ('preparazione', 'attivo', 'chiuso') then
    raise exception 'Stato anno accademico non valido: %', p_stato;
  end if;

  if not exists (
    select 1 from public.anni_accademici where codice = p_codice
  ) then
    raise exception 'Anno accademico inesistente: %', p_codice;
  end if;

  if p_stato = 'attivo' then
    update public.anni_accademici
    set stato = case when codice = p_codice then 'attivo' else
        case when stato = 'attivo' then 'chiuso' else stato end end,
        corrente = (codice = p_codice);
  elsif p_stato = 'preparazione' then
    update public.anni_accademici
    set stato = case
          when codice = p_codice then 'preparazione'
          when stato = 'preparazione' then 'chiuso'
          else stato
        end,
        corrente = case when codice = p_codice then false else corrente end;
  else
    update public.anni_accademici
    set stato = 'chiuso',
        corrente = false
    where codice = p_codice;
  end if;
end;
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_aggiorna_backoffice(p_mentoraggio_id uuid, p_valori jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_aggiorna_backoffice(p_mentoraggio_id uuid, p_valori jsonb)
 RETURNS mentoraggi
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_riga public.mentoraggi;
  v_chiave text;
  v_valore jsonb;
  v_tipo text;
  v_sql text;
begin
  if not public.mentoraggio_backoffice() then
    raise exception 'Operazione consentita solo a owner o organizer.' using errcode = '42501';
  end if;

  for v_chiave, v_valore in select key, value from jsonb_each(p_valori)
  loop
    if v_chiave = 'id' then
      raise exception 'Il campo id non e modificabile.';
    end if;

    select pg_catalog.format_type(a.atttypid, a.atttypmod)
      into v_tipo
    from pg_catalog.pg_attribute a
    where a.attrelid = 'public.mentoraggi'::regclass
      and a.attname = v_chiave
      and a.attnum > 0
      and not a.attisdropped;

    if v_tipo is null then
      raise exception 'Campo mentoraggi.% inesistente.', v_chiave;
    end if;

    v_sql := format(
      'update public.mentoraggi set %I = ($1 #>> ''{}'')::%s where id = $2',
      v_chiave,
      v_tipo
    );
    execute v_sql using v_valore, p_mentoraggio_id;
  end loop;

  select * into v_riga from public.mentoraggi where id = p_mentoraggio_id;
  return v_riga;
end;
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_aggiorna_mentee(p_mentoraggio_id uuid, p_valori jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_aggiorna_mentee(p_mentoraggio_id uuid, p_valori jsonb)
 RETURNS mentoraggi
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_riga public.mentoraggi;
  v_chiave text;
  v_valore jsonb;
  v_tipo text;
  v_sql text;
  v_consentiti constant text[] := array[
    'data_inizio',
    'data_fine',
    'numero_studenti',
    'sede',
    'note',
    'svolgimento',
    'giorni_orari_lezioni'
  ];
begin
  if not public.mentoraggio_utente_mentee(p_mentoraggio_id, auth.uid()) then
    raise exception 'Non sei il mentee di questo mentoraggio.' using errcode = '42501';
  end if;

  if not public.mentoraggio_anno_corrente(p_mentoraggio_id) then
    raise exception 'I mentoraggi degli anni precedenti sono in sola lettura.' using errcode = '42501';
  end if;

  for v_chiave, v_valore in select key, value from jsonb_each(p_valori)
  loop
    if not (v_chiave = any(v_consentiti)) then
      raise exception 'Il mentee non puo modificare il campo "%".', v_chiave using errcode = '42501';
    end if;

    select pg_catalog.format_type(a.atttypid, a.atttypmod)
      into v_tipo
    from pg_catalog.pg_attribute a
    where a.attrelid = 'public.mentoraggi'::regclass
      and a.attname = v_chiave
      and a.attnum > 0
      and not a.attisdropped;

    if v_tipo is null then
      raise exception 'Campo mentoraggi.% inesistente.', v_chiave;
    end if;

    v_sql := format(
      'update public.mentoraggi set %I = ($1 #>> ''{}'')::%s where id = $2',
      v_chiave,
      v_tipo
    );
    execute v_sql using v_valore, p_mentoraggio_id;
  end loop;

  select * into v_riga from public.mentoraggi where id = p_mentoraggio_id;
  return v_riga;
end;
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_aggiorna_mentore(p_mentoraggio_id uuid, p_valori jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_aggiorna_mentore(p_mentoraggio_id uuid, p_valori jsonb)
 RETURNS mentoraggi
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_riga public.mentoraggi;
  v_chiave text;
  v_valore jsonb;
  v_tipo text;
  v_sql text;
  v_esclusi constant text[] := array[
    'id',
    'insegnamento_id',
    'anno_accademico',
    'data_inizio',
    'data_fine',
    'numero_studenti',
    'sede',
    'note',
    'svolgimento',
    'giorni_orari_lezioni',
    'data_invio_scheda',
    'scheda_sintesi_pdf_url',
    'created_at',
    'updated_at'
  ];
begin
  if not public.mentoraggio_utente_associato(p_mentoraggio_id, auth.uid()) then
    raise exception 'Non sei associato a questo mentoraggio.' using errcode = '42501';
  end if;

  if not public.mentoraggio_anno_corrente(p_mentoraggio_id) then
    raise exception 'I mentoraggi degli anni precedenti sono in sola lettura.' using errcode = '42501';
  end if;

  for v_chiave, v_valore in select key, value from jsonb_each(p_valori)
  loop
    if v_chiave = any(v_esclusi) then
      raise exception 'Il campo "%" non puo essere modificato dal team di mentoraggio.', v_chiave using errcode = '42501';
    end if;

    select pg_catalog.format_type(a.atttypid, a.atttypmod)
      into v_tipo
    from pg_catalog.pg_attribute a
    where a.attrelid = 'public.mentoraggi'::regclass
      and a.attname = v_chiave
      and a.attnum > 0
      and not a.attisdropped;

    if v_tipo is null then
      raise exception 'Campo mentoraggi.% inesistente.', v_chiave;
    end if;

    v_sql := format(
      'update public.mentoraggi set %I = ($1 #>> ''{}'')::%s where id = $2',
      v_chiave,
      v_tipo
    );
    execute v_sql using v_valore, p_mentoraggio_id;
  end loop;

  select * into v_riga from public.mentoraggi where id = p_mentoraggio_id;
  return v_riga;
end;
$function$;

-- --------------------------------------------------------------------------
-- mentoraggio_scheda_sintesi_imposta(p_mentoraggio_id uuid, p_storage_path text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mentoraggio_scheda_sintesi_imposta(p_mentoraggio_id uuid, p_storage_path text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_stato text;
begin
  if auth.uid() is null then
    raise exception 'Utente non autenticato.' using errcode = '42501';
  end if;

  select m.stato::text
  into v_stato
  from public.mentoraggi m
  where m.id = p_mentoraggio_id;

  if v_stato is null then
    raise exception 'Mentoraggio non trovato.';
  end if;

  if not public.app_backoffice_admin() then
    if v_stato <> 'Completato' then
      raise exception 'La scheda definitiva può essere caricata solo a mentoraggio completato.';
    end if;

    if not exists (
      select 1
      from public.mentoraggio_mentori mm
      where mm.mentoraggio_id = p_mentoraggio_id
        and mm.mentore_id = auth.uid()
    ) then
      raise exception 'Operazione non autorizzata.' using errcode = '42501';
    end if;
  end if;

  update public.mentoraggi
  set scheda_sintesi_pdf_url = nullif(trim(p_storage_path), ''),
      data_invio_scheda = current_date
  where id = p_mentoraggio_id;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_condizione_relazionale_ok(p_tabella_principale text, p_record jsonb, p_condizione jsonb, p_campo_id_principale text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_condizione_relazionale_ok(p_tabella_principale text, p_record jsonb, p_condizione jsonb, p_campo_id_principale text DEFAULT 'id'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tabella_target text := coalesce(nullif(p_condizione->>'tabella', ''), p_tabella_principale);
  v_campo text := nullif(p_condizione->>'campo', '');
  v_operatore text := lower(coalesce(p_condizione->>'operatore', 'eq'));
  v_atteso text := p_condizione->>'valore';
  v_percorso jsonb := coalesce(p_condizione->'percorso', '[]'::jsonb);
  v_record_id text := nullif(p_record->>p_campo_id_principale, '');
  v_edge jsonb;
  v_sql text;
  v_predicato text;
  v_tabella_corrente text := p_tabella_principale;
  v_alias_corrente integer := 0;
  v_alias_successivo integer;
  v_esiste boolean := false;
begin
  if v_campo is null then
    return true;
  end if;

  -- Condizione sulla stessa riga principale: nessun SQL dinamico necessario.
  if v_tabella_target = p_tabella_principale
     and jsonb_array_length(v_percorso) = 0 then
    return public.notifiche_valore_condizione_ok(
      p_record->v_campo,
      v_operatore,
      v_atteso
    );
  end if;

  if v_record_id is null then
    return false;
  end if;

  v_sql := format('select exists(select 1 from public.%I t0 ', p_tabella_principale);

  for v_edge in
    select value from jsonb_array_elements(v_percorso)
  loop
    if nullif(v_edge->>'da_tabella', '') is null
       or nullif(v_edge->>'da_campo', '') is null
       or nullif(v_edge->>'a_tabella', '') is null
       or nullif(v_edge->>'a_campo', '') is null then
      return false;
    end if;

    if v_edge->>'da_tabella' <> v_tabella_corrente then
      return false;
    end if;

    v_alias_successivo := v_alias_corrente + 1;
    v_sql := v_sql || format(
      ' join public.%I t%s on t%s.%I = t%s.%I ',
      v_edge->>'a_tabella',
      v_alias_successivo,
      v_alias_corrente,
      v_edge->>'da_campo',
      v_alias_successivo,
      v_edge->>'a_campo'
    );
    v_tabella_corrente := v_edge->>'a_tabella';
    v_alias_corrente := v_alias_successivo;
  end loop;

  if v_tabella_corrente <> v_tabella_target then
    return false;
  end if;

  case v_operatore
    when 'is_null' then
      v_predicato := format('t%s.%I is null', v_alias_corrente, v_campo);
    when 'not_null' then
      v_predicato := format('t%s.%I is not null', v_alias_corrente, v_campo);
    when 'eq' then
      v_predicato := format(
        'coalesce(t%s.%I::text, '''') = %L',
        v_alias_corrente, v_campo, coalesce(v_atteso, '')
      );
    when 'neq' then
      v_predicato := format(
        'coalesce(t%s.%I::text, '''') <> %L',
        v_alias_corrente, v_campo, coalesce(v_atteso, '')
      );
    when 'true' then
      v_predicato := format(
        'lower(coalesce(t%s.%I::text, ''false'')) in (''true'',''t'',''1'',''yes'')',
        v_alias_corrente, v_campo
      );
    when 'false' then
      v_predicato := format(
        'lower(coalesce(t%s.%I::text, ''false'')) not in (''true'',''t'',''1'',''yes'')',
        v_alias_corrente, v_campo
      );
    else
      raise exception 'Operatore condizione notifiche non supportato: %', v_operatore;
  end case;

  v_sql := v_sql || format(
    ' where t0.%I::text = $1 and %s)',
    p_campo_id_principale,
    v_predicato
  );

  execute v_sql into v_esiste using v_record_id;
  return coalesce(v_esiste, false);
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_crea_messaggio_da_regola(p_regola_id uuid, p_record jsonb, p_evento text, p_data_riferimento timestamp with time zone)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_crea_messaggio_da_regola(p_regola_id uuid, p_record jsonb DEFAULT '{}'::jsonb, p_evento text DEFAULT NULL::text, p_data_riferimento timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_regola public.notifiche_regole%rowtype;

  v_anno text;
  v_origine_id uuid;
  v_id_testo text;

  v_titolo text;
  v_messaggio text;

  v_config_dest jsonb;

  v_chiave text;
  v_nuovo_id uuid;

  v_campi_chiave jsonb;
  v_campo_chiave text;
  v_valore_chiave text;

begin

  select *
  into v_regola
  from public.notifiche_regole
  where id = p_regola_id
    and attiva is true;

  if not found then
    return null;
  end if;


  -- ==========================================================
  -- ANNO ACCADEMICO
  -- ==========================================================

  v_anno := coalesce(
    nullif(
      p_record->>'anno_accademico',
      ''
    ),
    public.notifiche_anno_corrente()
  );

  if v_anno is null then
    raise exception
      'Nessun anno accademico corrente disponibile per la regola %.',
      v_regola.codice;
  end if;


  -- ==========================================================
  -- ORIGINE
  -- ==========================================================

  v_id_testo :=
    nullif(
      p_record->>'id',
      ''
    );

  if
    v_id_testo is not null
    and v_id_testo ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  then
    v_origine_id :=
      v_id_testo::uuid;
  end if;


  -- ==========================================================
  -- TESTO NOTIFICA
  -- ==========================================================

  v_titolo :=
    public.notifiche_render_template(
      v_regola.titolo_template,
      p_record
    );

  v_messaggio :=
    public.notifiche_render_template(
      v_regola.messaggio_template,
      p_record
    );


  -- ==========================================================
  -- CONFIGURAZIONE DESTINATARI
  -- ==========================================================

  v_config_dest :=
    public.notifiche_config_destinatari_regola(
      v_regola.destinatari::text,
      p_record,
      v_anno,
      v_regola.configurazione
    );


  -- ==========================================================
  -- CHIAVE UNIVOCA
  -- ==========================================================

  if
    v_regola.tipo_attivazione::text = 'insert'
  then

    v_chiave :=
      v_regola.codice
      || ':'
      || coalesce(
        v_id_testo,
        'record'
      )
      || ':insert';


  elsif
    v_regola.tipo_attivazione::text = 'data'
  then

    v_chiave :=
      v_regola.codice
      || ':'
      || coalesce(
        v_id_testo,
        'record'
      )
      || ':data:'
      || coalesce(
        p_data_riferimento::text,
        ''
      );


  elsif
    v_regola.tipo_attivazione::text =
      'programmata'
  then

    v_chiave :=
      v_regola.codice
      || ':programmata:'
      || coalesce(
        v_regola.data_programmata::text,
        ''
      );


  else

    -- ========================================================
    -- UPDATE
    --
    -- Normalmente ogni modifica significativa può generare
    -- una nuova notifica.
    --
    -- Se però la regola contiene:
    --
    --   "chiave_univoca_campi": [...]
    --
    -- costruiamo una chiave stabile usando quei campi.
    -- ========================================================

    v_campi_chiave :=
      v_regola.configurazione
        -> 'chiave_univoca_campi';

    if
      jsonb_typeof(
        v_campi_chiave
      ) = 'array'
      and jsonb_array_length(
        v_campi_chiave
      ) > 0
    then

      v_chiave :=
        v_regola.codice;

      for v_campo_chiave in
        select value
        from jsonb_array_elements_text(
          v_campi_chiave
        )
      loop

        v_valore_chiave :=
          coalesce(
            p_record
              ->> v_campo_chiave,
            ''
          );

        v_chiave :=
          v_chiave
          || ':'
          || v_valore_chiave;

      end loop;

    else

      v_chiave := null;

    end if;

  end if;


  -- ==========================================================
  -- CREA MESSAGGIO
  -- ==========================================================

  insert into public.notifiche_messaggi (
    regola_id,
    anno_accademico,
    titolo,
    messaggio,
    destinatari,
    destinatari_configurazione,
    origine_tabella,
    origine_id,
    chiave_univoca,
    programmata_per,
    stato,
    creata_da
  )
  values (
    v_regola.id,
    v_anno,
    v_titolo,
    v_messaggio,
    v_regola.destinatari,
    v_config_dest,
    v_regola.tabella,
    v_origine_id,
    v_chiave,
    null,
    'da_inviare',
    null
  )
  on conflict do nothing
  returning id
  into v_nuovo_id;


  return v_nuovo_id;

end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_genera_destinatari(p_messaggio_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_genera_destinatari(p_messaggio_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_messaggio public.notifiche_messaggi%rowtype;
  v_tipo text;
  v_evento_id uuid;
  v_hom_id uuid;
  v_mentoraggio_id uuid;
  v_anno text;
  v_count integer := 0;
begin
  -- Le chiamate dal client sono ammesse solo a owner/organizer.
  -- Un eventuale processo server con auth.uid() nullo puo usare la stessa
  -- funzione in seguito per le notifiche automatiche/schedulate.
  if auth.uid() is not null and not public.notifiche_puo_gestire() then
    raise exception 'Operazione non autorizzata: solo owner o organizer possono generare destinatari.';
  end if;

  select *
    into v_messaggio
  from public.notifiche_messaggi
  where id = p_messaggio_id;

  if not found then
    raise exception 'Messaggio % non trovato.', p_messaggio_id;
  end if;

  v_tipo := v_messaggio.destinatari::text;
  v_anno := coalesce(
    nullif(v_messaggio.destinatari_configurazione->>'anno_accademico', ''),
    v_messaggio.anno_accademico
  );

  if nullif(v_messaggio.destinatari_configurazione->>'evento_id', '') is not null then
    v_evento_id := (v_messaggio.destinatari_configurazione->>'evento_id')::uuid;
  end if;

  if nullif(v_messaggio.destinatari_configurazione->>'house_of_mentore_id', '') is not null then
    v_hom_id := (v_messaggio.destinatari_configurazione->>'house_of_mentore_id')::uuid;
  end if;

  if nullif(v_messaggio.destinatari_configurazione->>'mentoraggio_id', '') is not null then
    v_mentoraggio_id := (v_messaggio.destinatari_configurazione->>'mentoraggio_id')::uuid;
  elsif v_messaggio.origine_tabella = 'mentoraggi' and v_messaggio.origine_id is not null then
    v_mentoraggio_id := v_messaggio.origine_id;
  end if;

  -- Rigenerazione idempotente: elimina soltanto i destinatari non ancora inviati.
  -- Lo storico di righe gia inviate/lette non viene toccato.
  delete from public.notifiche_destinatari
  where messaggio_id = p_messaggio_id
    and stato in ('da_inviare', 'escluso_inattivo', 'senza_dispositivo', 'errore');

  -- --------------------------------------------------------------------------
  -- TUTTI GLI UTENTI ATTIVI
  -- --------------------------------------------------------------------------
  if v_tipo = 'tutti' then
    insert into public.notifiche_destinatari (messaggio_id, user_id)
    select p_messaggio_id, ar.user_id
    from public.anagrafica_riservata ar
    where ar.attivo is true
    on conflict (messaggio_id, user_id) do nothing;

  -- --------------------------------------------------------------------------
  -- PARTICIPANT APPLICATIVI ATTIVI
  -- --------------------------------------------------------------------------
  elsif v_tipo = 'participant' then
    insert into public.notifiche_destinatari (messaggio_id, user_id)
    select p_messaggio_id, ur.user_id
    from public.user_roles ur
    join public.anagrafica_riservata ar
      on ar.user_id = ur.user_id
     and ar.attivo is true
    where ur.role = 'participant'
    on conflict (messaggio_id, user_id) do nothing;

  -- --------------------------------------------------------------------------
  -- PERSONE SCELTE MANUALMENTE
  -- --------------------------------------------------------------------------
  elsif v_tipo = 'manuale' then
    insert into public.notifiche_destinatari (messaggio_id, user_id)
    select distinct p_messaggio_id, x.user_id
    from (
      select value::text::uuid as user_id
      from jsonb_array_elements_text(
        coalesce(v_messaggio.destinatari_configurazione->'user_ids', '[]'::jsonb)
      )
    ) x
    join public.anagrafica_riservata ar
      on ar.user_id = x.user_id
     and ar.attivo is true
    on conflict (messaggio_id, user_id) do nothing;

  -- --------------------------------------------------------------------------
  -- ISCRITTI A UNO SPECIFICO EVENTO
  -- --------------------------------------------------------------------------
  elsif v_tipo = 'iscritti_evento' then
    if v_evento_id is null then
      raise exception 'destinatari_configurazione.evento_id obbligatorio.';
    end if;

    insert into public.notifiche_destinatari (messaggio_id, user_id)
    select distinct p_messaggio_id, pe.partecipante_id
    from public.partecipazioni_eventi pe
    join public.anagrafica_riservata ar
      on ar.user_id = pe.partecipante_id
     and ar.attivo is true
    where pe.evento_id = v_evento_id
    on conflict (messaggio_id, user_id) do nothing;

  -- --------------------------------------------------------------------------
  -- ISCRITTI A UNA SPECIFICA HOUSE OF MENTORE
  -- --------------------------------------------------------------------------
  elsif v_tipo = 'iscritti_house_of_mentore' then
    if v_hom_id is null then
      raise exception 'destinatari_configurazione.house_of_mentore_id obbligatorio.';
    end if;

    insert into public.notifiche_destinatari (messaggio_id, user_id)
    select distinct p_messaggio_id, ph.partecipante_id
    from public.partecipazioni_house_of_mentore ph
    join public.anagrafica_riservata ar
      on ar.user_id = ph.partecipante_id
     and ar.attivo is true
    where ph.evento_id = v_hom_id
    on conflict (messaggio_id, user_id) do nothing;

  -- --------------------------------------------------------------------------
  -- PARTECIPANTI DI UN ANNO ACCADEMICO
  -- Definizione: union di mentee effettivamente mentorati e mentori/senior
  -- assegnati ai mentoraggi di quell'anno.
  -- --------------------------------------------------------------------------
  elsif v_tipo = 'anno_accademico' then
    if v_anno is null or btrim(v_anno) = '' then
      raise exception 'Anno accademico non determinabile.';
    end if;

    insert into public.notifiche_destinatari (messaggio_id, user_id)
    select distinct p_messaggio_id, candidati.user_id
    from (
      -- mentee/docenti con un mentoraggio nell'anno
      select i.docente_id as user_id
      from public.insegnamenti i
      join public.mentoraggi m
        on m.insegnamento_id = i.id
      where i.anno_accademico = v_anno
        and i.docente_id is not null

      union

      -- mentor e senior assegnati nell'anno
      select mm.mentore_id as user_id
      from public.mentoraggio_mentori mm
      join public.mentoraggi m
        on m.id = mm.mentoraggio_id
      join public.insegnamenti i
        on i.id = m.insegnamento_id
      where i.anno_accademico = v_anno
        and mm.mentore_id is not null
    ) candidati
    join public.anagrafica_riservata ar
      on ar.user_id = candidati.user_id
     and ar.attivo is true
    on conflict (messaggio_id, user_id) do nothing;

  -- --------------------------------------------------------------------------
  -- MENTEE / MENTOR / SENIOR E COMBINAZIONI
  -- Se e presente mentoraggio_id, destinatari limitati a quel percorso.
  -- Altrimenti vengono considerati tutti i mentoraggi dell'anno del messaggio.
  -- --------------------------------------------------------------------------
  elsif v_tipo in (
    'mentor',
    'senior',
    'mentee',
    'mentor_senior',
    'mentor_senior_mentee'
  ) then

    -- MENTEE
    if v_tipo in ('mentee', 'mentor_senior_mentee') then
      insert into public.notifiche_destinatari (messaggio_id, user_id)
      select distinct p_messaggio_id, i.docente_id
      from public.mentoraggi m
      join public.insegnamenti i
        on i.id = m.insegnamento_id
      join public.anagrafica_riservata ar
        on ar.user_id = i.docente_id
       and ar.attivo is true
      where i.docente_id is not null
        and (
          (v_mentoraggio_id is not null and m.id = v_mentoraggio_id)
          or
          (v_mentoraggio_id is null and i.anno_accademico = v_anno)
        )
      on conflict (messaggio_id, user_id) do nothing;
    end if;

    -- MENTOR / SENIOR
    if v_tipo in ('mentor', 'senior', 'mentor_senior', 'mentor_senior_mentee') then
      insert into public.notifiche_destinatari (messaggio_id, user_id)
      select distinct p_messaggio_id, mm.mentore_id
      from public.mentoraggio_mentori mm
      join public.mentoraggi m
        on m.id = mm.mentoraggio_id
      join public.insegnamenti i
        on i.id = m.insegnamento_id
      join public.anagrafica_riservata ar
        on ar.user_id = mm.mentore_id
       and ar.attivo is true
      where mm.mentore_id is not null
        and (
          (v_mentoraggio_id is not null and m.id = v_mentoraggio_id)
          or
          (v_mentoraggio_id is null and i.anno_accademico = v_anno)
        )
        and (
          v_tipo in ('mentor_senior', 'mentor_senior_mentee')
          or (v_tipo = 'mentor' and lower(mm.tipo::text) = 'mentor')
          or (v_tipo = 'senior' and lower(mm.tipo::text) = 'senior')
        )
      on conflict (messaggio_id, user_id) do nothing;
    end if;

  elsif v_tipo = 'relazionale' then
    perform public.notifiche_inserisci_destinatari_relazionali(
      p_messaggio_id,
      v_messaggio.destinatari_configurazione || jsonb_build_object(
        'tabella_principale', coalesce(
          nullif(v_messaggio.destinatari_configurazione->>'tabella_principale', ''),
          v_messaggio.origine_tabella
        ),
        'record_id', coalesce(
          nullif(v_messaggio.destinatari_configurazione->>'record_id', ''),
          v_messaggio.origine_id::text
        )
      )
    );

  else
    raise exception 'Tipo destinatari non gestito: %', v_tipo;
  end if;

  select count(*)
    into v_count
  from public.notifiche_destinatari
  where messaggio_id = p_messaggio_id
    and stato = 'da_inviare';

  if v_count = 0 then
    raise exception 'Nessun destinatario attivo individuato per il messaggio.';
  end if;

  return v_count;
end;
$function$;

-- --------------------------------------------------------------------------
-- partecipazione_annuale_imposta(p_user_id uuid, p_anno_accademico text, p_stato text, p_note text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.partecipazione_annuale_imposta(p_user_id uuid, p_anno_accademico text, p_stato text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.app_backoffice_admin() then
    raise exception 'Operazione riservata a owner/organizer.' using errcode = '42501';
  end if;

  if p_stato not in ('da_contattare', 'confermato', 'rinuncia', 'nuovo', 'sospeso') then
    raise exception 'Stato partecipazione non valido.';
  end if;

  insert into public.partecipazioni_annuali (
    user_id,
    anno_accademico,
    stato,
    richiesta_at,
    risposta_at,
    aggiornato_da,
    note
  )
  values (
    p_user_id,
    p_anno_accademico,
    p_stato,
    now(),
    case when p_stato in ('confermato', 'rinuncia', 'nuovo') then now() else null end,
    auth.uid(),
    p_note
  )
  on conflict (user_id, anno_accademico)
  do update set
    stato = excluded.stato,
    risposta_at = excluded.risposta_at,
    aggiornato_da = auth.uid(),
    note = excluded.note,
    updated_at = now();
end;
$function$;

-- --------------------------------------------------------------------------
-- partecipazione_annuale_stato(p_anno_accademico text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.partecipazione_annuale_stato(p_anno_accademico text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_anno text;
  v_riga public.partecipazioni_annuali;
begin
  if v_user is null then
    raise exception 'Utente non autenticato.' using errcode = '42501';
  end if;

  v_anno := coalesce(p_anno_accademico, public.anno_accademico_preparazione());

  if v_anno is null then
    return jsonb_build_object(
      'disponibile', false,
      'anno_accademico', null,
      'stato', null
    );
  end if;

  select * into v_riga
  from public.partecipazioni_annuali
  where user_id = v_user
    and anno_accademico = v_anno;

  if not found then
    return jsonb_build_object(
      'disponibile', false,
      'anno_accademico', v_anno,
      'stato', null
    );
  end if;

  return jsonb_build_object(
    'disponibile', true,
    'anno_accademico', v_anno,
    'stato', v_riga.stato,
    'richiesta_at', v_riga.richiesta_at,
    'risposta_at', v_riga.risposta_at
  );
end;
$function$;

-- --------------------------------------------------------------------------
-- partecipazioni_annuali_proprie()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.partecipazioni_annuali_proprie()
 RETURNS SETOF public.partecipazioni_annuali
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select pa.*
  from public.partecipazioni_annuali pa
  where pa.user_id = auth.uid()
  order by pa.anno_accademico desc;
$function$;

-- --------------------------------------------------------------------------
-- partecipazioni_annuali_genera(p_anno_destinazione text, p_anno_sorgente text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.partecipazioni_annuali_genera(p_anno_destinazione text, p_anno_sorgente text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_sorgente text;
  v_numero integer;
begin
  if not public.app_backoffice_admin() then
    raise exception 'Operazione riservata a owner/organizer.' using errcode = '42501';
  end if;

  v_sorgente := coalesce(p_anno_sorgente, public.anno_accademico_attivo());

  if v_sorgente is null then
    raise exception 'Nessun anno sorgente disponibile.';
  end if;

  if not exists (
    select 1 from public.anni_accademici where codice = p_anno_destinazione
  ) then
    raise exception 'Anno destinazione inesistente.';
  end if;

  with utenti as (
    -- Mentee dell'anno sorgente.
    select distinct i.docente_id as user_id
    from public.mentoraggi m
    join public.insegnamenti i on i.id = m.insegnamento_id
    where m.anno_accademico = v_sorgente
      and i.docente_id is not null

    union

    -- Mentor/senior dell'anno sorgente.
    select distinct mm.mentore_id as user_id
    from public.mentoraggio_mentori mm
    join public.mentoraggi m on m.id = mm.mentoraggio_id
    where m.anno_accademico = v_sorgente
      and mm.mentore_id is not null
  ), inserite as (
    insert into public.partecipazioni_annuali (
      user_id,
      anno_accademico,
      stato,
      richiesta_at,
      aggiornato_da
    )
    select
      u.user_id,
      p_anno_destinazione,
      'da_contattare',
      now(),
      auth.uid()
    from utenti u
    join public.anagrafica a on a.user_id = u.user_id
    on conflict (user_id, anno_accademico) do nothing
    returning 1
  )
  select count(*) into v_numero from inserite;

  return v_numero;
end;
$function$;

-- --------------------------------------------------------------------------
-- proteggi_identificativi_insegnamento()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.proteggi_identificativi_insegnamento()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is not null
     and new.docente_id = auth.uid()
     and not public.has_role(
       array[
         'owner'::public.app_role,
         'organizer'::public.app_role
       ]
     )
     and (
       new.insegnamento is distinct from old.insegnamento
       or new.semestre is distinct from old.semestre
     )
  then
    raise exception
      'Nome dell''insegnamento e semestre sono modificabili solo da organizer o owner'
      using errcode = '42501';
  end if;

  return new;
end;
$function$;

-- --------------------------------------------------------------------------
-- proteggi_presenza_evento()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.proteggi_presenza_evento()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if public.app_backoffice_admin() or auth.role() = 'service_role' then
    if tg_op = 'INSERT' then
      if coalesce(new.presente, false) then
        new.presente_impostato_da := auth.uid();
        new.presente_impostato_at := now();
      end if;
    elsif new.presente is distinct from old.presente then
      new.presente_impostato_da := auth.uid();
      new.presente_impostato_at := now();
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.presente := false;
    new.presente_impostato_da := null;
    new.presente_impostato_at := null;
    return new;
  end if;

  if new.presente is distinct from old.presente
     or new.presente_impostato_da is distinct from old.presente_impostato_da
     or new.presente_impostato_at is distinct from old.presente_impostato_at
  then
    raise exception
      'Solo owner e organizer possono modificare la presenza.'
      using errcode = '42501';
  end if;

  return new;
end;
$function$;

-- --------------------------------------------------------------------------
-- puo_modificare_corrente(p_ambito ambito_modifica)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.puo_modificare_corrente(p_ambito ambito_modifica)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce(
    (
      select public.puo_modificare(
        p_ambito,
        aa.codice
      )
      from public.anni_accademici aa
      where aa.corrente = true
    ),
    false
  );
$function$;

-- --------------------------------------------------------------------------
-- questionario_mentoraggio_link_imposta(p_mentoraggio_id uuid, p_url text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.questionario_mentoraggio_link_imposta(p_mentoraggio_id uuid, p_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Utente non autenticato.' using errcode = '42501';
  end if;

  if not public.app_backoffice_admin()
     and not exists (
       select 1
       from public.mentoraggio_mentori mm
       where mm.mentoraggio_id = p_mentoraggio_id
         and mm.mentore_id = auth.uid()
     ) then
    raise exception 'Operazione non autorizzata.' using errcode = '42501';
  end if;

  update public.mentoraggi
  set link_questionario = nullif(trim(p_url), '')
  where id = p_mentoraggio_id;
end;
$function$;

-- --------------------------------------------------------------------------
-- questionario_sintesi_mentoraggio(p_mentoraggio_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.questionario_sintesi_mentoraggio(p_mentoraggio_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_docente uuid;
  v_q public.questionari%rowtype;
  v_numero integer;
begin
  select i.docente_id into v_docente
  from public.mentoraggi m
  join public.insegnamenti i on i.id = m.insegnamento_id
  where m.id = p_mentoraggio_id;

  if v_docente is null then
    return null;
  end if;

  if auth.uid() is distinct from v_docente
     and not public.app_backoffice_admin()
     and not exists (
       select 1 from public.mentoraggio_mentori mm
       where mm.mentoraggio_id = p_mentoraggio_id
         and mm.mentore_id = auth.uid()
     ) then
    raise exception 'Operazione non autorizzata.' using errcode = '42501';
  end if;

  select * into v_q
  from public.questionari q
  where q.mentoraggio_id = p_mentoraggio_id
    and q.provider = 'pubblico'
  limit 1;

  if not found then
    return jsonb_build_object(
      'questionario_id', null,
      'numero_compilazioni', 0,
      'domande', '[]'::jsonb
    );
  end if;

  select count(*) into v_numero
  from public.questionari_compilazioni c
  where c.questionario_id = v_q.id;

  return jsonb_build_object(
    'questionario_id', v_q.id,
    'titolo', v_q.titolo,
    'numero_compilazioni', v_numero,
    'domande', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', d.id,
          'testo', d.testo,
          'tipo', d.tipo,
          'opzioni', d.opzioni,
          'valori', coalesce((
            select jsonb_agg(r.valore)
            from public.questionari_risposte r
            join public.questionari_compilazioni c
              on c.id = r.compilazione_id
            where c.questionario_id = v_q.id
              and r.domanda_id = d.id
          ), '[]'::jsonb)
        ) order by d.ordine
      )
      from public.questionari_domande d
      where d.template_id = v_q.template_id
    ), '[]'::jsonb)
  );
end;
$function$;

-- --------------------------------------------------------------------------
-- utente_ha_abilitazione(p_ambito ambito_modifica, p_anno_accademico text, p_user_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.utente_ha_abilitazione(p_ambito ambito_modifica, p_anno_accademico text, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select

    public.utente_owner_organizer(p_user_id)

    or exists (

      select 1

      from public.abilitazioni_modifica am

      where am.user_id = p_user_id

        and am.ambito = p_ambito

        and am.anno_accademico =
            p_anno_accademico

        and am.abilitata is true

        and am.revocata_at is null

        and (
          am.scade_at is null
          or am.scade_at > now()
        )
    );
$function$;

-- --------------------------------------------------------------------------
-- imposta_anno_accademico_corrente(p_codice text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.imposta_anno_accademico_corrente(p_codice text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.imposta_stato_anno_accademico(p_codice, 'attivo');
end;
$function$;

-- --------------------------------------------------------------------------
-- insegnamento_crea_per_anno(p_valori jsonb, p_anno_accademico text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.insegnamento_crea_per_anno(p_valori jsonb, p_anno_accademico text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_anno text;
  v_stato_anno text;
  v_partecipazione text;
  v_chiave text;
  v_tipo text;
  v_colonne text := 'docente_id';
  v_valori_sql text := '$2';
  v_sql text;
  v_insegnamento_id uuid;
  v_mentoraggio public.mentoraggi;
  v_protetti constant text[] := array[
    'id', 'docente_id', 'created_at', 'updated_at',
    'data_inizio', 'data_fine', 'anno_accademico', 'numero_studenti',
    'sede', 'note', 'svolgimento', 'giorni_orari_lezioni', 'gia_mentorato'
  ];
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato.' using errcode = '42501';
  end if;

  v_anno := coalesce(p_anno_accademico, public.anno_accademico_gestione_insegnamenti());
  if v_anno is null then
    raise exception 'Nessun anno disponibile.';
  end if;

  select stato into v_stato_anno
  from public.anni_accademici where codice = v_anno;

  if not public.app_backoffice_admin() then
    if v_stato_anno not in ('preparazione', 'attivo') then
      raise exception 'L''anno accademico non è aperto alla creazione dell''insegnamento.' using errcode = '42501';
    end if;

    select stato into v_partecipazione
    from public.partecipazioni_annuali
    where user_id = v_user_id and anno_accademico = v_anno;

    if v_stato_anno = 'preparazione' and v_partecipazione not in ('confermato', 'nuovo') then
      raise exception 'Devi prima confermare la partecipazione al prossimo anno accademico.' using errcode = '42501';
    end if;

    if not public.utente_ha_abilitazione('insegnamento_creazione', v_anno, v_user_id) then
      raise exception 'Non sei abilitato alla creazione di un nuovo insegnamento.' using errcode = '42501';
    end if;
  end if;

  if exists (
    select 1
    from public.mentoraggi m
    join public.insegnamenti i on i.id = m.insegnamento_id
    where i.docente_id = v_user_id and m.anno_accademico = v_anno
  ) then
    raise exception 'Hai già un insegnamento associato all''anno %.', v_anno;
  end if;

  for v_chiave in select jsonb_object_keys(p_valori)
  loop
    if v_chiave = any(v_protetti) then
      raise exception 'Il campo "%" non può essere impostato.', v_chiave using errcode = '42501';
    end if;

    select pg_catalog.format_type(a.atttypid, a.atttypmod)
    into v_tipo
    from pg_catalog.pg_attribute a
    where a.attrelid = 'public.insegnamenti'::regclass
      and a.attname = v_chiave
      and a.attnum > 0
      and not a.attisdropped;

    if v_tipo is null then
      raise exception 'Campo insegnamenti.% inesistente.', v_chiave;
    end if;

    v_colonne := v_colonne || format(', %I', v_chiave);
    v_valori_sql := v_valori_sql || format(', ($1->>%L)::%s', v_chiave, v_tipo);
  end loop;

  v_sql := format(
    'insert into public.insegnamenti (%s) values (%s) returning id',
    v_colonne,
    v_valori_sql
  );

  execute v_sql into v_insegnamento_id using p_valori, v_user_id;

  insert into public.mentoraggi (insegnamento_id, anno_accademico)
  values (v_insegnamento_id, v_anno)
  returning * into v_mentoraggio;

  return jsonb_build_object(
    'insegnamento_id', v_insegnamento_id,
    'mentoraggio', to_jsonb(v_mentoraggio)
  );
end;
$function$;

-- --------------------------------------------------------------------------
-- insegnamento_modifica_autorizzata(p_insegnamento_id uuid, p_valori jsonb, p_anno_accademico text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.insegnamento_modifica_autorizzata(p_insegnamento_id uuid, p_valori jsonb, p_anno_accademico text DEFAULT NULL::text)
 RETURNS insegnamenti
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_anno text;
  v_stato_anno text;
  v_chiave text;
  v_tipo text;
  v_set text := '';
  v_sql text;
  v_riga public.insegnamenti;
  v_protetti constant text[] := array[
    'id', 'docente_id', 'created_at', 'updated_at',
    'data_inizio', 'data_fine', 'anno_accademico', 'numero_studenti',
    'sede', 'note', 'svolgimento', 'giorni_orari_lezioni', 'gia_mentorato'
  ];
begin
  v_anno := coalesce(p_anno_accademico, public.anno_accademico_gestione_insegnamenti());
  if v_anno is null then
    raise exception 'Nessun anno disponibile.';
  end if;

  select stato into v_stato_anno from public.anni_accademici where codice = v_anno;

  if not public.app_backoffice_admin() then
    if v_stato_anno not in ('preparazione', 'attivo') then
      raise exception 'L''anno accademico non è aperto alla modifica.' using errcode = '42501';
    end if;

    if not public.utente_ha_abilitazione('insegnamento_modifica', v_anno, v_user_id) then
      raise exception 'Non sei abilitato alla modifica dell''insegnamento.' using errcode = '42501';
    end if;

    if not exists (
      select 1 from public.insegnamenti i
      where i.id = p_insegnamento_id and i.docente_id = v_user_id
    ) then
      raise exception 'Non puoi modificare questo insegnamento.' using errcode = '42501';
    end if;

    if not exists (
      select 1 from public.mentoraggi m
      where m.insegnamento_id = p_insegnamento_id
        and m.anno_accademico = v_anno
    ) then
      raise exception 'L''insegnamento non è associato all''anno indicato.' using errcode = '42501';
    end if;
  end if;

  for v_chiave in select jsonb_object_keys(p_valori)
  loop
    if v_chiave = any(v_protetti) then
      raise exception 'Il campo "%" non è modificabile.', v_chiave using errcode = '42501';
    end if;

    select pg_catalog.format_type(a.atttypid, a.atttypmod)
    into v_tipo
    from pg_catalog.pg_attribute a
    where a.attrelid = 'public.insegnamenti'::regclass
      and a.attname = v_chiave
      and a.attnum > 0
      and not a.attisdropped;

    if v_tipo is null then
      raise exception 'Campo insegnamenti.% inesistente.', v_chiave;
    end if;

    if v_set <> '' then v_set := v_set || ', '; end if;
    v_set := v_set || format('%I = ($1->>%L)::%s', v_chiave, v_chiave, v_tipo);
  end loop;

  if v_set = '' then
    select * into v_riga from public.insegnamenti where id = p_insegnamento_id;
    return v_riga;
  end if;

  v_sql := format(
    'update public.insegnamenti set %s where id = $2 returning *',
    v_set
  );

  execute v_sql into v_riga using p_valori, p_insegnamento_id;
  return v_riga;
end;
$function$;

-- --------------------------------------------------------------------------
-- insegnamento_seleziona_per_anno(p_insegnamento_id uuid, p_anno_accademico text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.insegnamento_seleziona_per_anno(p_insegnamento_id uuid, p_anno_accademico text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_anno text;
  v_mentoraggio public.mentoraggi;
  v_stato_anno text;
  v_partecipazione text;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato.' using errcode = '42501';
  end if;

  v_anno := coalesce(p_anno_accademico, public.anno_accademico_gestione_insegnamenti());
  if v_anno is null then
    raise exception 'Nessun anno disponibile.';
  end if;

  select stato into v_stato_anno
  from public.anni_accademici where codice = v_anno;

  if not public.app_backoffice_admin() then
    if v_stato_anno not in ('preparazione', 'attivo') then
      raise exception 'L''anno accademico non è aperto alla scelta dell''insegnamento.' using errcode = '42501';
    end if;

    select stato into v_partecipazione
    from public.partecipazioni_annuali
    where user_id = v_user_id and anno_accademico = v_anno;

    if v_stato_anno = 'preparazione' and v_partecipazione not in ('confermato', 'nuovo') then
      raise exception 'Devi prima confermare la partecipazione al prossimo anno accademico.' using errcode = '42501';
    end if;

    if not public.utente_ha_abilitazione('insegnamento_selezione', v_anno, v_user_id) then
      raise exception 'Non sei abilitato alla selezione dell''insegnamento.' using errcode = '42501';
    end if;
  end if;

  if not exists (
    select 1 from public.insegnamenti
    where id = p_insegnamento_id and docente_id = v_user_id
  ) then
    raise exception 'L''insegnamento selezionato non appartiene all''utente.' using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.mentoraggi m
    join public.insegnamenti i on i.id = m.insegnamento_id
    where i.docente_id = v_user_id and m.anno_accademico = v_anno
  ) then
    raise exception 'Hai già un insegnamento associato all''anno %.', v_anno;
  end if;

  insert into public.mentoraggi (insegnamento_id, anno_accademico)
  values (p_insegnamento_id, v_anno)
  returning * into v_mentoraggio;

  return to_jsonb(v_mentoraggio);
end;
$function$;

-- --------------------------------------------------------------------------
-- insegnamento_stato_annuale(p_anno_accademico text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.insegnamento_stato_annuale(p_anno_accademico text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_anno text;
  v_user_id uuid := auth.uid();
  v_mentoraggio_id uuid;
  v_insegnamento_id uuid;
  v_partecipazione text;
  v_stato_anno text;
begin
  if v_user_id is null then
    raise exception 'Utente non autenticato.' using errcode = '42501';
  end if;

  v_anno := coalesce(
    p_anno_accademico,
    public.anno_accademico_gestione_insegnamenti()
  );

  if v_anno is null then
    return jsonb_build_object(
      'anno_accademico', null,
      'anno_corrente', false,
      'non_richiesto', false,
      'puo_selezionare', false,
      'puo_creare', false,
      'puo_modificare', false,
      'mentoraggio_id', null,
      'insegnamento_id', null,
      'partecipazione_stato', null
    );
  end if;

  select stato into v_stato_anno
  from public.anni_accademici
  where codice = v_anno;

  select pa.stato into v_partecipazione
  from public.partecipazioni_annuali pa
  where pa.user_id = v_user_id
    and pa.anno_accademico = v_anno;

  select m.id, m.insegnamento_id
  into v_mentoraggio_id, v_insegnamento_id
  from public.mentoraggi m
  join public.insegnamenti i on i.id = m.insegnamento_id
  where i.docente_id = v_user_id
    and m.anno_accademico = v_anno
  limit 1;

  return jsonb_build_object(
    'anno_accademico', v_anno,
    'anno_corrente', v_anno = public.anno_accademico_attivo(),
    'non_richiesto', public.utente_ha_abilitazione(
      'insegnamento_non_richiesto', v_anno, v_user_id
    ),
    'puo_selezionare',
      (v_stato_anno <> 'preparazione' or v_partecipazione in ('confermato', 'nuovo'))
      and public.utente_ha_abilitazione(
        'insegnamento_selezione', v_anno, v_user_id
      ),
    'puo_creare',
      (v_stato_anno <> 'preparazione' or v_partecipazione in ('confermato', 'nuovo'))
      and public.utente_ha_abilitazione(
        'insegnamento_creazione', v_anno, v_user_id
      ),
    'puo_modificare', public.utente_ha_abilitazione(
      'insegnamento_modifica', v_anno, v_user_id
    ),
    'mentoraggio_id', v_mentoraggio_id,
    'insegnamento_id', v_insegnamento_id,
    'partecipazione_stato', v_partecipazione
  );
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_condizioni_regola_ok(p_tabella_principale text, p_record jsonb, p_configurazione jsonb)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_condizioni_regola_ok(p_tabella_principale text, p_record jsonb, p_configurazione jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_cond jsonb;
  v_campo_id text := coalesce(
    nullif(p_configurazione->>'campo_id_principale', ''),
    'id'
  );
begin
  if p_configurazione is null
     or jsonb_typeof(p_configurazione->'condizioni') <> 'array'
     or jsonb_array_length(p_configurazione->'condizioni') = 0 then
    return true;
  end if;

  for v_cond in
    select value from jsonb_array_elements(p_configurazione->'condizioni')
  loop
    if not public.notifiche_condizione_relazionale_ok(
      p_tabella_principale,
      p_record,
      v_cond,
      v_campo_id
    ) then
      return false;
    end if;
  end loop;

  return true;
end;
$function$;

-- --------------------------------------------------------------------------
-- partecipazione_annuale_rispondi(p_partecipa boolean, p_anno_accademico text)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.partecipazione_annuale_rispondi(p_partecipa boolean, p_anno_accademico text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_anno text;
  v_stato text;
begin
  if v_user is null then
    raise exception 'Utente non autenticato.' using errcode = '42501';
  end if;

  v_anno := coalesce(p_anno_accademico, public.anno_accademico_preparazione());
  if v_anno is null then
    raise exception 'Nessun anno accademico in preparazione.';
  end if;

  if not exists (
    select 1
    from public.partecipazioni_annuali
    where user_id = v_user
      and anno_accademico = v_anno
  ) then
    raise exception 'Nessuna richiesta di partecipazione disponibile.';
  end if;

  v_stato := case when p_partecipa then 'confermato' else 'rinuncia' end;

  update public.partecipazioni_annuali
  set stato = v_stato,
      risposta_at = now(),
      aggiornato_da = v_user,
      updated_at = now()
  where user_id = v_user
    and anno_accademico = v_anno;

  return public.partecipazione_annuale_stato(v_anno);
end;
$function$;

-- --------------------------------------------------------------------------
-- questionario_risultati_mentoraggio(p_mentoraggio_id uuid)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.questionario_risultati_mentoraggio(p_mentoraggio_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_docente uuid;
  v_q public.questionari%rowtype;
  v_sintesi jsonb;
begin
  select i.docente_id
  into v_docente
  from public.mentoraggi m
  join public.insegnamenti i on i.id = m.insegnamento_id
  where m.id = p_mentoraggio_id;

  if v_docente is null then
    return null;
  end if;

  if auth.uid() is distinct from v_docente
     and not public.app_backoffice_admin()
     and not exists (
       select 1
       from public.mentoraggio_mentori mm
       where mm.mentoraggio_id = p_mentoraggio_id
         and mm.mentore_id = auth.uid()
     ) then
    raise exception 'Operazione non autorizzata.' using errcode = '42501';
  end if;

  select *
  into v_q
  from public.questionari q
  where q.mentoraggio_id = p_mentoraggio_id
    and q.provider = 'pubblico'
  order by q.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'questionario_id', null,
      'numero_compilazioni', 0,
      'domande', '[]'::jsonb,
      'compilazioni', '[]'::jsonb,
      'risposte', '[]'::jsonb,
      'sintesi', '[]'::jsonb
    );
  end if;

  v_sintesi := public.questionario_sintesi_mentoraggio(p_mentoraggio_id);

  return jsonb_build_object(
    'questionario_id', v_q.id,
    'titolo', v_q.titolo,
    'numero_compilazioni', (
      select count(*)
      from public.questionari_compilazioni c
      where c.questionario_id = v_q.id
    ),
    'domande', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', d.id,
          'ordine', d.ordine,
          'testo', d.testo,
          'tipo', d.tipo,
          'opzioni', d.opzioni
        ) order by d.ordine
      )
      from public.questionari_domande d
      where d.template_id = v_q.template_id
    ), '[]'::jsonb),
    'compilazioni', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'inviato_at', c.inviato_at
        ) order by c.inviato_at
      )
      from public.questionari_compilazioni c
      where c.questionario_id = v_q.id
    ), '[]'::jsonb),
    'risposte', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'compilazione_id', r.compilazione_id,
          'domanda_id', r.domanda_id,
          'valore', r.valore
        )
      )
      from public.questionari_risposte r
      join public.questionari_compilazioni c
        on c.id = r.compilazione_id
      where c.questionario_id = v_q.id
    ), '[]'::jsonb),
    'sintesi', coalesce(v_sintesi -> 'domande', '[]'::jsonb)
  );
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_materializza_regole_temporali()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_materializza_regole_temporali()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_regola public.notifiche_regole%rowtype;
  v_record jsonb;
  v_data timestamptz;
  v_scadenza timestamptz;
  v_id uuid;
  v_count integer := 0;
  v_anno_corrente text := public.notifiche_anno_corrente();
  v_solo_anno_corrente boolean;
begin
  for v_regola in
    select * from public.notifiche_regole
    where attiva is true
      and tipo_attivazione::text = 'programmata'
      and data_programmata is not null
      and data_programmata <= now()
  loop
    v_id := public.notifiche_crea_messaggio_da_regola(
      v_regola.id,
      '{}'::jsonb,
      'programmata',
      v_regola.data_programmata
    );
    if v_id is not null then v_count := v_count + 1; end if;
  end loop;

  for v_regola in
    select * from public.notifiche_regole
    where attiva is true
      and tipo_attivazione::text = 'data'
      and tabella is not null
      and campo_data is not null
  loop
    if not exists (
      select 1 from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = v_regola.tabella
        and c.column_name = v_regola.campo_data
    ) then
      continue;
    end if;

    v_solo_anno_corrente := coalesce(
      (v_regola.configurazione->>'solo_anno_corrente')::boolean,
      true
    );

    for v_record in
      execute format(
        'select to_jsonb(t) from public.%I t where %I is not null',
        v_regola.tabella,
        v_regola.campo_data
      )
    loop
      begin
        v_data := (v_record->>v_regola.campo_data)::timestamptz;
      exception when others then
        continue;
      end;

      v_scadenza := v_data + make_interval(days => v_regola.offset_giorni);

      if v_scadenza > now() or v_scadenza < v_regola.created_at then
        continue;
      end if;

      if v_solo_anno_corrente
         and v_record ? 'anno_accademico'
         and nullif(v_record->>'anno_accademico', '') is not null
         and v_record->>'anno_accademico' <> v_anno_corrente then
        continue;
      end if;

      if not public.notifiche_condizioni_regola_ok(
        v_regola.tabella,
        v_record,
        v_regola.configurazione
      ) then
        continue;
      end if;

      v_id := public.notifiche_crea_messaggio_da_regola(
        v_regola.id,
        v_record,
        'data',
        v_data
      );
      if v_id is not null then v_count := v_count + 1; end if;
    end loop;
  end loop;

  return v_count;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_trigger_sorgente()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_trigger_sorgente()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_regola public.notifiche_regole%rowtype;
  v_new jsonb := to_jsonb(new);
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end;
  v_campo text;
  v_cambiato boolean;
  v_richiede_attiva boolean;
begin
  for v_regola in
    select *
    from public.notifiche_regole
    where attiva is true
      and tabella = tg_table_name
      and tipo_attivazione::text = lower(tg_op)
  loop
    v_richiede_attiva := coalesce((v_regola.configurazione->>'richiede_attiva')::boolean, false);
    if v_richiede_attiva
       and lower(coalesce(v_new->>'attiva', 'false')) not in ('true', 't', '1', 'yes') then
      continue;
    end if;

    if not public.notifiche_condizioni_regola_ok(
      tg_table_name,
      v_new,
      v_regola.configurazione
    ) then
      continue;
    end if;

    if tg_op = 'UPDATE' then
      v_cambiato := false;
      if jsonb_typeof(v_regola.configurazione->'campi_monitorati') = 'array'
         and jsonb_array_length(v_regola.configurazione->'campi_monitorati') > 0 then
        for v_campo in
          select value from jsonb_array_elements_text(v_regola.configurazione->'campi_monitorati')
        loop
          if (v_old->v_campo) is distinct from (v_new->v_campo) then
            v_cambiato := true;
            exit;
          end if;
        end loop;
      else
        v_cambiato := (v_old - 'updated_at') is distinct from (v_new - 'updated_at');
      end if;
      if not v_cambiato then continue; end if;
    end if;

    perform public.notifiche_crea_messaggio_da_regola(
      v_regola.id,
      v_new,
      lower(tg_op),
      null
    );
  end loop;

  return new;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_aggiorna_trigger_regole()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_aggiorna_trigger_regole()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tabella record;
  v_count integer := 0;
begin
  for v_tabella in
    select distinct r.tabella
    from public.notifiche_regole r
    join information_schema.tables t
      on t.table_schema = 'public'
     and t.table_name = r.tabella
     and t.table_type = 'BASE TABLE'
    where r.tabella is not null
      and r.tipo_attivazione::text in ('insert', 'update')
  loop
    execute format(
      'drop trigger if exists notifiche_regole_aiu on public.%I',
      v_tabella.tabella
    );
    execute format(
      'create trigger notifiche_regole_aiu '
      'after insert or update on public.%I '
      'for each row execute function public.notifiche_trigger_sorgente()',
      v_tabella.tabella
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$;

-- --------------------------------------------------------------------------
-- notifiche_trigger_regole_config()
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifiche_trigger_regole_config()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.notifiche_aggiorna_trigger_regole();
  return null;
end;
$function$;

-- ============================================================================
-- DEFAULT DIPENDENTI DA FUNZIONI APPLICATIVE
-- ============================================================================

ALTER TABLE public.notifiche_messaggi
  ALTER COLUMN anno_accademico
  SET DEFAULT public.notifiche_anno_corrente();

SET check_function_bodies = true;
