-- ============================================================================
-- MOTORE DESTINATARI NOTIFICHE
-- ============================================================================
-- Prerequisiti:
--   notifiche_messaggi
--   notifiche_destinatari
--   notifiche_utenti_attivi
--   anagrafica_riservata.attivo
--   user_roles.role
--
-- La funzione centrale e:
--   notifiche_genera_destinatari(p_messaggio_id uuid)
--
-- Regola inderogabile:
--   un utente viene inserito tra i destinatari soltanto se
--   anagrafica_riservata.attivo IS TRUE.
-- ============================================================================

create or replace function public.notifiche_puo_gestire()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('owner', 'organizer')
  );
$$;

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
grant execute on function public.notifiche_genera_destinatari(uuid) to authenticated;

-- ============================================================================
-- FUNZIONE DI CONTROLLO: conteggio destinatari di un messaggio
-- ============================================================================
create or replace function public.notifiche_conta_destinatari(
  p_messaggio_id uuid
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifiche_destinatari nd
  where nd.messaggio_id = p_messaggio_id;
$$;

revoke all on function public.notifiche_conta_destinatari(uuid) from public;
grant execute on function public.notifiche_conta_destinatari(uuid) to authenticated;
