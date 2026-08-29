-- ============================================================================
-- NOVITA' NEL MENU
-- ============================================================================
-- Prerequisito:
-- le tabelle considerate devono avere `updated_at timestamptz` aggiornato
-- automaticamente tramite trigger.
--
-- `auth.users.last_sign_in_at` viene usato solo come fallback finche' l'utente
-- non ha mai aperto una specifica sezione.


-- ============================================================================
-- 1. ULTIMO ACCESSO DELL'UTENTE ALLE SEZIONI
-- ============================================================================

create table if not exists public.utente_ultimi_accessi (
  user_id uuid not null references auth.users(id) on delete cascade,
  percorso text not null,
  ultimo_accesso timestamptz not null default now(),

  constraint utente_ultimi_accessi_pkey
    primary key (user_id, percorso)
);

alter table public.utente_ultimi_accessi
enable row level security;

grant select, insert, update
on table public.utente_ultimi_accessi
to authenticated;

drop policy if exists utente_ultimi_accessi_own
on public.utente_ultimi_accessi;

create policy utente_ultimi_accessi_own
on public.utente_ultimi_accessi
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());


-- ============================================================================
-- 2. REGISTRA L'ACCESSO A UNA SEZIONE
-- ============================================================================

create or replace function public.menu_registra_accesso(
  p_percorso text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Utente non autenticato.';
  end if;

  if p_percorso is null or btrim(p_percorso) = '' then
    raise exception 'Percorso non valido.';
  end if;

  insert into public.utente_ultimi_accessi (
    user_id,
    percorso,
    ultimo_accesso
  )
  values (
    auth.uid(),
    p_percorso,
    now()
  )
  on conflict (user_id, percorso)
  do update
  set ultimo_accesso = excluded.ultimo_accesso;
end;
$$;

revoke execute
on function public.menu_registra_accesso(text)
from public;

grant execute
on function public.menu_registra_accesso(text)
to authenticated;


-- ============================================================================
-- 3. STATO DELLE NOVITA'
-- ============================================================================
-- La funzione restituisce, per ogni percorso monitorato, true quando almeno
-- uno dei dati pertinenti e' stato creato/modificato dopo l'ultimo accesso.
--
-- Per le sezioni personali vengono considerate soltanto righe riferite
-- all'utente corrente.

-- Helper usato dalla funzione principale.

create or replace function public.menu_data_nuova(
  p_user_id uuid,
  p_percorso text,
  p_ultima_modifica timestamptz,
  p_fallback timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_ultima_modifica is not null
    and p_ultima_modifica > coalesce(
      (
        select a.ultimo_accesso
        from public.utente_ultimi_accessi a
        where a.user_id = p_user_id
          and a.percorso = p_percorso
      ),
      p_fallback
    );
$$;

revoke execute
on function public.menu_data_nuova(uuid, text, timestamptz, timestamptz)
from public;

-- E' una funzione di supporto usata soltanto da `menu_stato_novita`.
-- Non serve concederla ai ruoli client.


-- Funzione principale.

create or replace function public.menu_stato_novita()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_fallback timestamptz;

  v_news timestamptz;
  v_profilo timestamptz;
  v_insegnamenti timestamptz;
  v_mentee timestamptz;
  v_mentore timestamptz;
  v_risorse timestamptz;
  v_eventi timestamptz;
  v_house timestamptz;
  v_contatti timestamptz;

  v_bo_partecipanti timestamptz;
  v_bo_insegnamenti timestamptz;
  v_bo_anni timestamptz;
  v_bo_controllo timestamptz;
  v_bo_notifiche timestamptz;
  v_bo_questionari timestamptz;

  v_result jsonb := '{}'::jsonb;
begin
  if v_uid is null then
    return v_result;
  end if;

  select coalesce(u.last_sign_in_at, u.created_at, now())
  into v_fallback
  from auth.users u
  where u.id = v_uid;

  -- --------------------------------------------------------------------------
  -- SEZIONI PERSONALI / GENERALI
  -- --------------------------------------------------------------------------

  select max(n.updated_at)
  into v_news
  from public.news n
  where n.attiva is not false;

  select greatest(
    coalesce((
      select max(a.updated_at)
      from public.anagrafica a
      where a.user_id = v_uid
    ), '-infinity'::timestamptz),
    coalesce((
      select max(pa.updated_at)
      from public.partecipazioni_annuali pa
      where pa.user_id = v_uid
    ), '-infinity'::timestamptz)
  )
  into v_profilo;

  select max(i.updated_at)
  into v_insegnamenti
  from public.insegnamenti i
  where i.docente_id = v_uid;

  select greatest(
    coalesce((
      select max(m.updated_at)
      from public.mentoraggi m
      join public.insegnamenti i
        on i.id = m.insegnamento_id
      where i.docente_id = v_uid
    ), '-infinity'::timestamptz),
    coalesce((
      select max(mm.updated_at)
      from public.mentoraggio_mentori mm
      join public.mentoraggi m
        on m.id = mm.mentoraggio_id
      join public.insegnamenti i
        on i.id = m.insegnamento_id
      where i.docente_id = v_uid
    ), '-infinity'::timestamptz),
    coalesce((
      select max(i.updated_at)
      from public.insegnamenti i
      where i.docente_id = v_uid
    ), '-infinity'::timestamptz)
  )
  into v_mentee;

  select greatest(
    coalesce((
      select max(m.updated_at)
      from public.mentoraggi m
      join public.mentoraggio_mentori mm
        on mm.mentoraggio_id = m.id
      where mm.mentore_id = v_uid
    ), '-infinity'::timestamptz),
    coalesce((
      select max(mm.updated_at)
      from public.mentoraggio_mentori mm
      where mm.mentore_id = v_uid
    ), '-infinity'::timestamptz),
    coalesce((
      select max(i.updated_at)
      from public.insegnamenti i
      join public.mentoraggi m
        on m.insegnamento_id = i.id
      join public.mentoraggio_mentori mm
        on mm.mentoraggio_id = m.id
      where mm.mentore_id = v_uid
    ), '-infinity'::timestamptz)
  )
  into v_mentore;

  select max(r.updated_at)
  into v_risorse
  from public.risorse_mentoring r;

  select max(e.updated_at)
  into v_eventi
  from public.eventi e
  where e.attiva is not false;

  select greatest(
    coalesce((
      select max(h.updated_at)
      from public.house_of_mentore h
      where h.attiva is not false
    ), '-infinity'::timestamptz),
    coalesce((
      select max(o.updated_at)
      from public.house_of_mentore_opzioni o
      join public.house_of_mentore h
        on h.id = o.evento_id
      where h.attiva is not false
    ), '-infinity'::timestamptz)
  )
  into v_house;

  select max(a.updated_at)
  into v_contatti
  from public.anagrafica a;


  -- --------------------------------------------------------------------------
  -- BACKOFFICE
  -- --------------------------------------------------------------------------

  select greatest(
    coalesce((select max(a.updated_at) from public.anagrafica a),
             '-infinity'::timestamptz),
    coalesce((select max(ar.updated_at) from public.anagrafica_riservata ar),
             '-infinity'::timestamptz),
    coalesce((select max(pa.updated_at) from public.partecipazioni_annuali pa),
             '-infinity'::timestamptz)
  )
  into v_bo_partecipanti;

  select greatest(
    coalesce((select max(i.updated_at) from public.insegnamenti i),
             '-infinity'::timestamptz),
    coalesce((select max(m.updated_at) from public.mentoraggi m),
             '-infinity'::timestamptz),
    coalesce((select max(mm.updated_at) from public.mentoraggio_mentori mm),
             '-infinity'::timestamptz)
  )
  into v_bo_insegnamenti;

  select greatest(
    coalesce((select max(aa.updated_at) from public.anni_accademici aa),
             '-infinity'::timestamptz),
    coalesce((select max(pa.updated_at) from public.partecipazioni_annuali pa),
             '-infinity'::timestamptz)
  )
  into v_bo_anni;

  select greatest(
    coalesce(v_bo_partecipanti, '-infinity'::timestamptz),
    coalesce(v_bo_insegnamenti, '-infinity'::timestamptz),
    coalesce(v_eventi, '-infinity'::timestamptz),
    coalesce(v_house, '-infinity'::timestamptz)
  )
  into v_bo_controllo;

  select greatest(
    coalesce((select max(nm.updated_at) from public.notifiche_messaggi nm),
             '-infinity'::timestamptz),
    coalesce((select max(nr.updated_at) from public.notifiche_regole nr),
             '-infinity'::timestamptz)
  )
  into v_bo_notifiche;

  select greatest(
    coalesce((select max(qt.updated_at) from public.questionari_template qt),
             '-infinity'::timestamptz),
    coalesce((select max(qd.updated_at) from public.questionari_domande qd),
             '-infinity'::timestamptz)
  )
  into v_bo_questionari;


  -- --------------------------------------------------------------------------
  -- CONFRONTO CON L'ULTIMO ACCESSO
  -- --------------------------------------------------------------------------

  v_result := jsonb_build_object(
    '/news',
      public.menu_data_nuova(v_uid, '/news', v_news, v_fallback),
    '/profilo',
      public.menu_data_nuova(v_uid, '/profilo', v_profilo, v_fallback),
    '/insegnamento',
      public.menu_data_nuova(v_uid, '/insegnamento', v_insegnamenti, v_fallback),
    '/mentee',
      public.menu_data_nuova(v_uid, '/mentee', v_mentee, v_fallback),
    '/mentore',
      public.menu_data_nuova(v_uid, '/mentore', v_mentore, v_fallback),
    '/risorse-mentoring',
      public.menu_data_nuova(v_uid, '/risorse-mentoring', v_risorse, v_fallback),
    '/eventi',
      public.menu_data_nuova(v_uid, '/eventi', v_eventi, v_fallback),
    '/house-of-mentore',
      public.menu_data_nuova(v_uid, '/house-of-mentore', v_house, v_fallback),
    '/contatti',
      public.menu_data_nuova(v_uid, '/contatti', v_contatti, v_fallback),

    '/gestione/partecipanti',
      public.menu_data_nuova(
        v_uid,
        '/gestione/partecipanti',
        v_bo_partecipanti,
        v_fallback
      ),
    '/gestione/insegnamenti',
      public.menu_data_nuova(
        v_uid,
        '/gestione/insegnamenti',
        v_bo_insegnamenti,
        v_fallback
      ),
    '/gestione/anni-accademici',
      public.menu_data_nuova(
        v_uid,
        '/gestione/anni-accademici',
        v_bo_anni,
        v_fallback
      ),
    '/gestione/controllo-partecipanti',
      public.menu_data_nuova(
        v_uid,
        '/gestione/controllo-partecipanti',
        v_bo_controllo,
        v_fallback
      ),
    '/gestione/notifiche',
      public.menu_data_nuova(
        v_uid,
        '/gestione/notifiche',
        v_bo_notifiche,
        v_fallback
      ),
    '/gestione/questionari',
      public.menu_data_nuova(
        v_uid,
        '/gestione/questionari',
        v_bo_questionari,
        v_fallback
      )
  );

  return v_result;
end;
$$;


-- ============================================================================
-- 4. HELPER DI CONFRONTO
-- ============================================================================


revoke execute
on function public.menu_stato_novita()
from public;

grant execute
on function public.menu_stato_novita()
to authenticated;


-- ============================================================================
-- 5. VERIFICA
-- ============================================================================

-- Dopo l'esecuzione puoi controllare:
--
-- select * from public.utente_ultimi_accessi
-- order by user_id, percorso;
--
-- select public.menu_stato_novita();
