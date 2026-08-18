-- ============================================================================
-- NOTIFICHE - REGOLE RELAZIONALI
-- ============================================================================
-- Estende il sistema esistente senza creare nuove tabelle.
--
-- Consente una regola del tipo:
--   tabella principale: insegnamenti
--   data: insegnamenti.data_inizio + 21 giorni
--   condizione: mentoraggi.data_visita_1 IS NULL
--     via insegnamenti.id = mentoraggi.insegnamento_id
--   destinatari: mentoraggio_mentori.mentore_id
--     via insegnamenti.id = mentoraggi.insegnamento_id
--         mentoraggi.id = mentoraggio_mentori.mentoraggio_id
--
-- Le relazioni vengono salvate in notifiche_regole.configurazione (jsonb).
-- ============================================================================

-- 1. Nuovo tipo destinatari generico basato su tabelle collegate.
alter type public.notifiche_tipo_destinatari
  add value if not exists 'relazionale';

-- --------------------------------------------------------------------------
-- 2. Valutazione di un singolo operatore su un valore della tabella principale.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_valore_condizione_ok(
  p_valore jsonb,
  p_operatore text,
  p_atteso text default null
)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 3. Valuta una condizione che può trovarsi su una tabella collegata.
--
-- Formato condizione:
-- {
--   "tabella": "mentoraggi",
--   "campo": "data_visita_1",
--   "operatore": "is_null",
--   "percorso": [
--     {
--       "da_tabella":"insegnamenti",
--       "da_campo":"id",
--       "a_tabella":"mentoraggi",
--       "a_campo":"insegnamento_id"
--     }
--   ]
-- }
--
-- La condizione è vera se ESISTE almeno una riga collegata che la soddisfa.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_condizione_relazionale_ok(
  p_tabella_principale text,
  p_record jsonb,
  p_condizione jsonb,
  p_campo_id_principale text default 'id'
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 4. Valuta tutte le condizioni della regola (AND), anche su tabelle diverse.
--    È retrocompatibile: una vecchia condizione senza "tabella" viene
--    interpretata sulla tabella principale.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_condizioni_regola_ok(
  p_tabella_principale text,
  p_record jsonb,
  p_configurazione jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 5. Configurazione destinatari: aggiunge la modalità "relazionale".
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
$$;

-- --------------------------------------------------------------------------
-- 6. Inserisce destinatari da una tabella collegata mediante un percorso FK.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_inserisci_destinatari_relazionali(
  p_messaggio_id uuid,
  p_configurazione jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 7. Sostituisce il motore destinatari aggiungendo il ramo RELAZIONALE.
-- --------------------------------------------------------------------------
create or replace function public.notifiche_genera_destinatari(
  p_messaggio_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.notifiche_genera_destinatari(uuid) from public;
grant execute on function public.notifiche_genera_destinatari(uuid) to authenticated, service_role;


-- --------------------------------------------------------------------------
-- 8. Trigger INSERT/UPDATE: usa ora anche condizioni relazionali.
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
$$;

-- --------------------------------------------------------------------------
-- 9. Regole DATA/PROGRAMMATA: valuta ogni record principale separatamente.
--    La chiave univoca già contiene l'id del record principale, quindi viene
--    prodotta al massimo una notifica per regola + insegnamento + data.
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
$$;

revoke all on function public.notifiche_materializza_regole_temporali() from public;
grant execute on function public.notifiche_materializza_regole_temporali() to service_role;

grant execute on function public.notifiche_inserisci_destinatari_relazionali(uuid, jsonb) to service_role;
grant execute on function public.notifiche_condizioni_regola_ok(text, jsonb, jsonb) to service_role;
grant execute on function public.notifiche_condizione_relazionale_ok(text, jsonb, jsonb, text) to service_role;

-- Fine migrazione.
