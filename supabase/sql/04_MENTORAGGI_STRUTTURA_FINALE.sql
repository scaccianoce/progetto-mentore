-- ============================================================================
-- MENTORAGGI - STRUTTURA FINALE
-- Migrazione distruttiva pensata per il DB di test.
--
-- Modello finale:
--   insegnamenti       = identita stabile dell'insegnamento
--   mentoraggi         = attivita annuale di mentoraggio dell'insegnamento
--   mentoraggio_mentori = partecipanti che svolgono ruolo mentor/senior/etc.
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1. Assicura che i campi annuali esistano in mentoraggi con lo stesso tipo
--    che avevano in insegnamenti.
-- --------------------------------------------------------------------------
do $$
declare
  v_colonna text;
  v_tipo text;
begin
  foreach v_colonna in array array[
    'data_inizio',
    'data_fine',
    'anno_accademico',
    'numero_studenti',
    'sede',
    'note',
    'svolgimento',
    'giorni_orari_lezioni'
  ]
  loop
    select pg_catalog.format_type(a.atttypid, a.atttypmod)
      into v_tipo
    from pg_catalog.pg_attribute a
    where a.attrelid = 'public.insegnamenti'::regclass
      and a.attname = v_colonna
      and a.attnum > 0
      and not a.attisdropped;

    if v_tipo is not null and not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'mentoraggi'
        and column_name = v_colonna
    ) then
      execute format(
        'alter table public.mentoraggi add column %I %s',
        v_colonna,
        v_tipo
      );
    end if;
  end loop;
end
$$;

alter table public.mentoraggi
  add column if not exists scheda_sintesi_pdf_url text;

-- --------------------------------------------------------------------------
-- 2. Copia definitiva dei dati annuali ancora presenti in insegnamenti.
-- --------------------------------------------------------------------------
update public.mentoraggi m
set
  data_inizio = coalesce(m.data_inizio, i.data_inizio),
  data_fine = coalesce(m.data_fine, i.data_fine),
  anno_accademico = coalesce(m.anno_accademico, i.anno_accademico),
  numero_studenti = coalesce(m.numero_studenti, i.numero_studenti),
  sede = coalesce(m.sede, i.sede),
  note = coalesce(m.note, i.note),
  svolgimento = coalesce(m.svolgimento, i.svolgimento),
  giorni_orari_lezioni = coalesce(
    m.giorni_orari_lezioni,
    i.giorni_orari_lezioni
  )
from public.insegnamenti i
where i.id = m.insegnamento_id;

-- --------------------------------------------------------------------------
-- 3. Vincoli della nuova struttura.
-- --------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1
    from public.mentoraggi
    where anno_accademico is null
  ) then
    raise exception 'Esistono mentoraggi senza anno_accademico: completarli prima di proseguire.';
  end if;

  if exists (
    select 1
    from public.mentoraggi
    group by insegnamento_id, anno_accademico
    having count(*) > 1
  ) then
    raise exception 'Esistono duplicati insegnamento_id + anno_accademico.';
  end if;
end
$$;

alter table public.mentoraggi
  alter column anno_accademico set not null;

create unique index if not exists mentoraggi_insegnamento_anno_unique
  on public.mentoraggi(insegnamento_id, anno_accademico);

create index if not exists mentoraggi_anno_idx
  on public.mentoraggi(anno_accademico);

create index if not exists mentoraggi_insegnamento_idx
  on public.mentoraggi(insegnamento_id);

create index if not exists mentoraggio_mentori_mentoraggio_idx
  on public.mentoraggio_mentori(mentoraggio_id);

create index if not exists mentoraggio_mentori_mentore_idx
  on public.mentoraggio_mentori(mentore_id);

-- FK anno accademico.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.mentoraggi'::regclass
      and conname = 'mentoraggi_anno_accademico_fk'
  ) then
    alter table public.mentoraggi
      add constraint mentoraggi_anno_accademico_fk
      foreign key (anno_accademico)
      references public.anni_accademici(codice)
      on update cascade
      on delete restrict;
  end if;
end
$$;

-- --------------------------------------------------------------------------
-- 4. Rimuove definitivamente da insegnamenti i campi annuali.
-- --------------------------------------------------------------------------
alter table public.insegnamenti
  drop column if exists data_inizio,
  drop column if exists data_fine,
  drop column if exists anno_accademico,
  drop column if exists numero_studenti,
  drop column if exists sede,
  drop column if exists note,
  drop column if exists svolgimento,
  drop column if exists giorni_orari_lezioni,
  drop column if exists gia_mentorato;

-- --------------------------------------------------------------------------
-- 5. Funzioni di dominio.
-- --------------------------------------------------------------------------
create or replace function public.mentoraggio_backoffice()
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
      and ur.role::text in ('owner', 'organizer')
  );
$$;

create or replace function public.mentoraggio_anno_corrente(p_mentoraggio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.mentoraggi m
    join public.anni_accademici aa
      on aa.codice = m.anno_accademico
    where m.id = p_mentoraggio_id
      and aa.corrente is true
  );
$$;

create or replace function public.mentoraggio_utente_associato(
  p_mentoraggio_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.mentoraggio_mentori mm
    where mm.mentoraggio_id = p_mentoraggio_id
      and mm.mentore_id = p_user_id
  );
$$;

create or replace function public.mentoraggio_utente_mentee(
  p_mentoraggio_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.mentoraggi m
    join public.insegnamenti i
      on i.id = m.insegnamento_id
    where m.id = p_mentoraggio_id
      and i.docente_id = p_user_id
  );
$$;

-- --------------------------------------------------------------------------
-- 6. Letture sicure.
--    Il mentee non riceve mai colonne che iniziano con "osservazioni".
-- --------------------------------------------------------------------------
create or replace function public.mentoraggi_del_mentee()
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
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
$$;

create or replace function public.mentoraggi_del_mentore()
returns setof public.mentoraggi
language sql
stable
security definer
set search_path = public
as $$
  select distinct m.*
  from public.mentoraggi m
  join public.mentoraggio_mentori mm
    on mm.mentoraggio_id = m.id
  where mm.mentore_id = auth.uid()
  order by m.anno_accademico desc, m.id;
$$;

-- --------------------------------------------------------------------------
-- 7. Aggiornamento generico controllato: MENTEE.
-- --------------------------------------------------------------------------
create or replace function public.mentoraggio_aggiorna_mentee(
  p_mentoraggio_id uuid,
  p_valori jsonb
)
returns public.mentoraggi
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 8. Aggiornamento generico controllato: MENTOR/SENIOR/QUALSIASI RUOLO
--    presente in mentoraggio_mentori.
-- --------------------------------------------------------------------------
create or replace function public.mentoraggio_aggiorna_mentore(
  p_mentoraggio_id uuid,
  p_valori jsonb
)
returns public.mentoraggi
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 9. Aggiornamento backoffice, inclusi anno e scheda_sintesi_pdf_url.
-- --------------------------------------------------------------------------
create or replace function public.mentoraggio_aggiorna_backoffice(
  p_mentoraggio_id uuid,
  p_valori jsonb
)
returns public.mentoraggi
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- --------------------------------------------------------------------------
-- 10. RLS mentoraggi.
--     Il mentee NON ha SELECT diretto: legge tramite mentoraggi_del_mentee(),
--     che elimina osservazioni_*.
-- --------------------------------------------------------------------------
alter table public.mentoraggi enable row level security;

do $$
declare
  p record;
begin
  for p in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'mentoraggi'
  loop
    execute format('drop policy if exists %I on public.mentoraggi', p.policyname);
  end loop;
end
$$;

create policy mentoraggi_select_team_backoffice
on public.mentoraggi
for select
to authenticated
using (
  public.mentoraggio_backoffice()
  or public.mentoraggio_utente_associato(id, auth.uid())
);

create policy mentoraggi_insert_backoffice
on public.mentoraggi
for insert
to authenticated
with check (public.mentoraggio_backoffice());

create policy mentoraggi_update_autorizzati
on public.mentoraggi
for update
to authenticated
using (
  public.mentoraggio_backoffice()
  or public.mentoraggio_utente_associato(id, auth.uid())
  or public.mentoraggio_utente_mentee(id, auth.uid())
)
with check (
  public.mentoraggio_backoffice()
  or public.mentoraggio_utente_associato(id, auth.uid())
  or public.mentoraggio_utente_mentee(id, auth.uid())
);

create policy mentoraggi_delete_backoffice
on public.mentoraggi
for delete
to authenticated
using (public.mentoraggio_backoffice());

-- Le RPC SECURITY DEFINER applicano il controllo delle colonne.
revoke all on function public.mentoraggio_backoffice() from public;
revoke all on function public.mentoraggio_anno_corrente(uuid) from public;
revoke all on function public.mentoraggio_utente_associato(uuid, uuid) from public;
revoke all on function public.mentoraggio_utente_mentee(uuid, uuid) from public;
revoke all on function public.mentoraggi_del_mentee() from public;
revoke all on function public.mentoraggi_del_mentore() from public;
revoke all on function public.mentoraggio_aggiorna_mentee(uuid, jsonb) from public;
revoke all on function public.mentoraggio_aggiorna_mentore(uuid, jsonb) from public;
revoke all on function public.mentoraggio_aggiorna_backoffice(uuid, jsonb) from public;

grant execute on function public.mentoraggio_backoffice() to authenticated, service_role;
grant execute on function public.mentoraggio_anno_corrente(uuid) to authenticated, service_role;
grant execute on function public.mentoraggio_utente_associato(uuid, uuid) to authenticated, service_role;
grant execute on function public.mentoraggio_utente_mentee(uuid, uuid) to authenticated, service_role;
grant execute on function public.mentoraggi_del_mentee() to authenticated;
grant execute on function public.mentoraggi_del_mentore() to authenticated;
grant execute on function public.mentoraggio_aggiorna_mentee(uuid, jsonb) to authenticated;
grant execute on function public.mentoraggio_aggiorna_mentore(uuid, jsonb) to authenticated;
grant execute on function public.mentoraggio_aggiorna_backoffice(uuid, jsonb) to authenticated;

grant select, insert, update, delete on public.mentoraggi to authenticated, service_role;

-- --------------------------------------------------------------------------
-- 11. Disattiva eventuali vecchie regole notifiche che puntano ai campi
--     annuali rimossi da insegnamenti. Vanno ricreate dalla maschera Regole
--     usando `mentoraggi` come tabella principale.
-- --------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.notifiche_regole') is not null then
    update public.notifiche_regole
    set attiva = false,
        configurazione = coalesce(configurazione, '{}'::jsonb) ||
          jsonb_build_object(
            'nota_migrazione',
            'Ricreare la regola usando mentoraggi come tabella principale.'
          )
    where tabella = 'insegnamenti'
      and campo_data in (
        'data_inizio',
        'data_fine'
      );
  end if;
end
$$;

-- --------------------------------------------------------------------------
-- 12. Verifica finale.
-- --------------------------------------------------------------------------
select
  m.id as mentoraggio_id,
  m.anno_accademico,
  m.insegnamento_id,
  i.docente_id,
  m.data_inizio,
  m.data_fine,
  m.numero_studenti,
  m.sede,
  m.svolgimento,
  m.scheda_sintesi_pdf_url
from public.mentoraggi m
join public.insegnamenti i on i.id = m.insegnamento_id
order by m.anno_accademico desc, i.docente_id;
