-- ============================================================================
-- COMPLETAMENTO SISTEMA NOTIFICHE
-- Regole automatiche: insert / update / data / programmata
-- ============================================================================
-- Prerequisiti gia presenti nel progetto:
--   notifiche_regole
--   notifiche_messaggi
--   notifiche_destinatari
--   notifiche_dispositivi
--   notifiche_genera_destinatari(uuid)
--   notifiche_anno_corrente()
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. Estende il tipo delle regole con la modalita programmata.
-- --------------------------------------------------------------------------
alter type public.notifiche_tipo_attivazione
  add value if not exists 'programmata';

alter table public.notifiche_regole
  add column if not exists data_programmata timestamptz;

create index if not exists notifiche_regole_attive_idx
  on public.notifiche_regole(attiva, tipo_attivazione);

create index if not exists notifiche_regole_tabella_idx
  on public.notifiche_regole(tabella)
  where tabella is not null;

-- --------------------------------------------------------------------------
-- 2. Privilegi backend per le Edge Functions.
-- --------------------------------------------------------------------------
grant select on table public.user_roles to service_role;
grant select on table public.anagrafica to service_role;
grant select on table public.anagrafica_riservata to service_role;
grant select on table public.insegnamenti to service_role;
grant select on table public.mentoraggi to service_role;
grant select on table public.mentoraggio_mentori to service_role;
grant select on table public.partecipazioni_eventi to service_role;
grant select on table public.partecipazioni_house_of_mentore to service_role;

grant select, insert, update, delete on table public.notifiche_regole to service_role;
grant select, insert, update, delete on table public.notifiche_messaggi to service_role;
grant select, insert, update, delete on table public.notifiche_destinatari to service_role;
grant select, insert, update, delete on table public.notifiche_dispositivi to service_role;

-- --------------------------------------------------------------------------
-- 3. Rendering semplice dei template {{campo}} usando il record sorgente.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_render_template(
  p_template text,
  p_record jsonb
)
returns text
language plpgsql
immutable
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 4. Valuta condizioni configurabili salvate nel JSON della regola.
--
-- Formato supportato:
-- {
--   "condizioni": [
--     {"campo":"data_visita_1", "operatore":"is_null"},
--     {"campo":"stato", "operatore":"neq", "valore":"concluso"}
--   ]
-- }
--
-- Operatori: is_null, not_null, eq, neq, true, false.
-- Tutte le condizioni sono in AND.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_condizioni_ok(
  p_record jsonb,
  p_configurazione jsonb
)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 5. Crea il JSON con i parametri necessari al motore destinatari.
--
-- Per regole legate a eventi/HoM/mentoraggi viene usato per default il campo
-- "id" del record. E possibile indicare un altro campo con:
-- configurazione.campo_riferimento_destinatari
-- --------------------------------------------------------------------------
create or replace function public.notifiche_config_destinatari_regola(
  p_destinatari text,
  p_record jsonb,
  p_anno text,
  p_configurazione jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_campo_rif text := coalesce(
    nullif(p_configurazione->>'campo_riferimento_destinatari', ''),
    'id'
  );
  v_rif text;
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
    else
      return '{}'::jsonb;
  end case;
end;
$$;

-- --------------------------------------------------------------------------
-- 6. Materializza una singola regola in notifiche_messaggi.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_crea_messaggio_da_regola(
  p_regola_id uuid,
  p_record jsonb default '{}'::jsonb,
  p_evento text default null,
  p_data_riferimento timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
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
begin
  select * into v_regola
  from public.notifiche_regole
  where id = p_regola_id
    and attiva is true;

  if not found then
    return null;
  end if;

  v_anno := coalesce(
    nullif(p_record->>'anno_accademico', ''),
    public.notifiche_anno_corrente()
  );

  if v_anno is null then
    raise exception 'Nessun anno accademico corrente disponibile per la regola %.', v_regola.codice;
  end if;

  v_id_testo := nullif(p_record->>'id', '');
  if v_id_testo is not null
     and v_id_testo ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_origine_id := v_id_testo::uuid;
  end if;

  v_titolo := public.notifiche_render_template(v_regola.titolo_template, p_record);
  v_messaggio := public.notifiche_render_template(v_regola.messaggio_template, p_record);
  v_config_dest := public.notifiche_config_destinatari_regola(
    v_regola.destinatari::text,
    p_record,
    v_anno,
    v_regola.configurazione
  );

  -- Chiave unica soltanto per gli eventi che devono essere eseguiti una volta.
  if v_regola.tipo_attivazione::text = 'insert' then
    v_chiave := v_regola.codice || ':' || coalesce(v_id_testo, 'record') || ':insert';
  elsif v_regola.tipo_attivazione::text = 'data' then
    v_chiave := v_regola.codice || ':' || coalesce(v_id_testo, 'record') || ':data:' ||
      coalesce(p_data_riferimento::text, '');
  elsif v_regola.tipo_attivazione::text = 'programmata' then
    v_chiave := v_regola.codice || ':programmata:' || coalesce(v_regola.data_programmata::text, '');
  else
    -- UPDATE: ogni modifica significativa puo generare una nuova notifica.
    v_chiave := null;
  end if;

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
  ) values (
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
  returning id into v_nuovo_id;

  return v_nuovo_id;
end;
$$;

revoke all on function public.notifiche_crea_messaggio_da_regola(uuid, jsonb, text, timestamptz) from public;
grant execute on function public.notifiche_crea_messaggio_da_regola(uuid, jsonb, text, timestamptz) to service_role;

-- --------------------------------------------------------------------------
-- 7. Trigger generico INSERT/UPDATE sulle tabelle selezionate nelle regole.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_trigger_sorgente()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
    if v_richiede_attiva then
      if lower(coalesce(v_new->>'attiva', 'false')) not in ('true', 't', '1', 'yes') then
        continue;
      end if;
    end if;

    if not public.notifiche_condizioni_ok(v_new, v_regola.configurazione) then
      continue;
    end if;

    if tg_op = 'UPDATE' then
      v_cambiato := false;

      if jsonb_typeof(v_regola.configurazione->'campi_monitorati') = 'array'
         and jsonb_array_length(v_regola.configurazione->'campi_monitorati') > 0 then
        for v_campo in
          select value
          from jsonb_array_elements_text(v_regola.configurazione->'campi_monitorati')
        loop
          if (v_old->v_campo) is distinct from (v_new->v_campo) then
            v_cambiato := true;
            exit;
          end if;
        end loop;
      else
        -- Evita che il solo aggiornamento tecnico di updated_at produca push.
        v_cambiato := (v_old - 'updated_at') is distinct from (v_new - 'updated_at');
      end if;

      if not v_cambiato then
        continue;
      end if;
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
$$;

-- --------------------------------------------------------------------------
-- 8. Installa automaticamente il trigger sulle tabelle usate da regole
--    insert/update. I trigger rimasti su una tabella senza regole sono innocui.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_aggiorna_trigger_regole()
returns integer
language plpgsql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.notifiche_trigger_regole_config()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notifiche_aggiorna_trigger_regole();
  return null;
end;
$$;

drop trigger if exists notifiche_regole_config_changed on public.notifiche_regole;
create trigger notifiche_regole_config_changed
after insert or update or delete on public.notifiche_regole
for each statement
execute function public.notifiche_trigger_regole_config();

-- Installa ora i trigger per le regole gia esistenti.
select public.notifiche_aggiorna_trigger_regole();

-- --------------------------------------------------------------------------
-- 9. Materializza regole DATA e PROGRAMMATA.
--    Viene chiamata dal worker Cron prima di processare la coda.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_materializza_regole_temporali()
returns integer
language plpgsql
security definer
set search_path = public
as $$
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
  -- Regole a data/ora fissa.
  for v_regola in
    select *
    from public.notifiche_regole
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

  -- Regole relative a un campo data di una tabella.
  for v_regola in
    select *
    from public.notifiche_regole
    where attiva is true
      and tipo_attivazione::text = 'data'
      and tabella is not null
      and campo_data is not null
  loop
    -- Ignora configurazioni che puntano a tabella/campo inesistente.
    if not exists (
      select 1
      from information_schema.columns c
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

      -- Non genera notifiche retroattive anteriori alla creazione della regola.
      if v_scadenza > now() or v_scadenza < v_regola.created_at then
        continue;
      end if;

      if v_solo_anno_corrente
         and v_record ? 'anno_accademico'
         and nullif(v_record->>'anno_accademico', '') is not null
         and v_record->>'anno_accademico' <> v_anno_corrente then
        continue;
      end if;

      if not public.notifiche_condizioni_ok(v_record, v_regola.configurazione) then
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
$$;

revoke all on function public.notifiche_materializza_regole_temporali() from public;
grant execute on function public.notifiche_materializza_regole_temporali() to service_role;

-- --------------------------------------------------------------------------
-- 10. RLS: owner/organizer possono gestire le regole dal backoffice.
-- --------------------------------------------------------------------------
grant select, insert, update, delete on public.notifiche_regole to authenticated;

alter table public.notifiche_regole enable row level security;

drop policy if exists notifiche_regole_backoffice_select on public.notifiche_regole;
create policy notifiche_regole_backoffice_select
on public.notifiche_regole for select to authenticated
using (public.notifiche_amministratore());

drop policy if exists notifiche_regole_backoffice_insert on public.notifiche_regole;
create policy notifiche_regole_backoffice_insert
on public.notifiche_regole for insert to authenticated
with check (public.notifiche_amministratore());

drop policy if exists notifiche_regole_backoffice_update on public.notifiche_regole;
create policy notifiche_regole_backoffice_update
on public.notifiche_regole for update to authenticated
using (public.notifiche_amministratore())
with check (public.notifiche_amministratore());

drop policy if exists notifiche_regole_backoffice_delete on public.notifiche_regole;
create policy notifiche_regole_backoffice_delete
on public.notifiche_regole for delete to authenticated
using (public.notifiche_amministratore());

-- ============================================================================
-- FINE
-- ============================================================================
