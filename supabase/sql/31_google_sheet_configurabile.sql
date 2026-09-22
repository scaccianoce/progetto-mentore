-- ============================================================================
-- 31 - CONFIGURAZIONE DINAMICA GOOGLE SHEET
-- Le sorgenti sono viste esplicitamente autorizzate e devono esporre una
-- colonna identificativa e una email. I secret sono conservati in Vault.
-- ============================================================================

create table if not exists public.google_sheet_sorgenti (
  nome_view text primary key,
  descrizione text not null,
  campo_id_default text not null,
  campo_email_default text not null default 'email_unipa',
  attiva boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.google_sheet_configurazioni (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  script_url text not null,
  sheet_url text not null,
  secret_vault_id uuid not null,
  sorgente_view text not null references public.google_sheet_sorgenti(nome_view),
  campo_id text not null,
  campo_email text not null,
  attiva boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.google_sheet_mappature (
  id uuid primary key default gen_random_uuid(),
  configurazione_id uuid not null
    references public.google_sheet_configurazioni(id) on delete cascade,
  campo_sorgente text not null,
  colonna_google text not null,
  ordine integer not null default 0,
  created_at timestamptz not null default now(),
  unique (configurazione_id, campo_sorgente),
  unique (configurazione_id, colonna_google)
);

create unique index if not exists google_sheet_una_config_attiva_sorgente
  on public.google_sheet_configurazioni (sorgente_view)
  where attiva;

alter table public.google_sheet_sorgenti enable row level security;
alter table public.google_sheet_configurazioni enable row level security;
alter table public.google_sheet_mappature enable row level security;

revoke all on table public.google_sheet_sorgenti from public, anon, authenticated;
revoke all on table public.google_sheet_configurazioni from public, anon, authenticated;
revoke all on table public.google_sheet_mappature from public, anon, authenticated;
grant all on table public.google_sheet_sorgenti to service_role;
grant all on table public.google_sheet_configurazioni to service_role;
grant all on table public.google_sheet_mappature to service_role;

insert into public.google_sheet_sorgenti (
  nome_view, descrizione, campo_id_default, campo_email_default
) values (
  'mentoraggi_google_sheet',
  'Mentoraggi collegati al docente tramite email UniPa',
  'mentoraggio_id',
  'email_unipa'
)
on conflict (nome_view) do update set
  descrizione = excluded.descrizione,
  campo_id_default = excluded.campo_id_default,
  campo_email_default = excluded.campo_email_default,
  attiva = true;

create or replace function public.google_sheet_sorgenti_elenco()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'pg_catalog'
as $function$
begin
  if not public.app_owner(auth.uid()) then
    raise exception 'Operazione riservata al proprietario';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'nome_view', s.nome_view,
        'descrizione', s.descrizione,
        'campo_id_default', s.campo_id_default,
        'campo_email_default', s.campo_email_default,
        'campi', coalesce((
          select jsonb_agg(c.column_name order by c.ordinal_position)
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = s.nome_view
        ), '[]'::jsonb)
      ) order by s.nome_view
    )
    from public.google_sheet_sorgenti s
    where s.attiva
  ), '[]'::jsonb);
end;
$function$;

create or replace function public.google_sheet_configurazioni_elenco()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
begin
  if not public.app_owner(auth.uid()) then
    raise exception 'Operazione riservata al proprietario';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'nome', c.nome,
        'script_url', c.script_url,
        'sheet_url', c.sheet_url,
        'sorgente_view', c.sorgente_view,
        'campo_id', c.campo_id,
        'campo_email', c.campo_email,
        'attiva', c.attiva,
        'secret_configurato', c.secret_vault_id is not null,
        'updated_at', c.updated_at,
        'mappature', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'campo_sorgente', m.campo_sorgente,
              'colonna_google', m.colonna_google,
              'ordine', m.ordine
            ) order by m.ordine, m.campo_sorgente
          )
          from public.google_sheet_mappature m
          where m.configurazione_id = c.id
        ), '[]'::jsonb)
      ) order by c.nome
    )
    from public.google_sheet_configurazioni c
  ), '[]'::jsonb);
end;
$function$;

create or replace function public.google_sheet_configurazione_salva(
  p_id uuid,
  p_nome text,
  p_script_url text,
  p_sheet_url text,
  p_secret text,
  p_sorgente_view text,
  p_campo_id text,
  p_campo_email text,
  p_attiva boolean,
  p_mappature jsonb
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'vault', 'pg_catalog'
as $function$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_secret_id uuid;
  v_mappa jsonb;
  v_ordine integer := 0;
begin
  if not public.app_owner(auth.uid()) then
    raise exception 'Operazione riservata al proprietario';
  end if;

  p_nome := btrim(p_nome);
  p_script_url := btrim(p_script_url);
  p_sheet_url := nullif(btrim(p_sheet_url), '');
  p_secret := nullif(btrim(p_secret), '');
  p_sorgente_view := btrim(p_sorgente_view);
  p_campo_id := btrim(p_campo_id);
  p_campo_email := btrim(p_campo_email);

  if p_nome is null or p_nome = '' then
    raise exception 'Nome obbligatorio';
  end if;
  if p_script_url is null
     or p_script_url !~ '^https://script\.google\.com/' then
    raise exception 'Inserire l URL /exec di Google Apps Script';
  end if;
  if p_sheet_url is null
     or p_sheet_url !~ '^https://docs\.google\.com/spreadsheets/' then
    raise exception 'Inserire un link valido al foglio Google';
  end if;
  if p_sorgente_view is null or p_sorgente_view = ''
     or p_campo_id is null or p_campo_id = ''
     or p_campo_email is null or p_campo_email = '' then
    raise exception 'Sorgente, campo identificativo ed email sono obbligatori';
  end if;
  if not exists (
    select 1 from public.google_sheet_sorgenti
    where nome_view = p_sorgente_view and attiva
  ) then
    raise exception 'Sorgente non autorizzata';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = p_sorgente_view
      and column_name = p_campo_id
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = p_sorgente_view
      and column_name = p_campo_email
  ) then
    raise exception 'Campo identificativo o email non valido';
  end if;
  if jsonb_typeof(coalesce(p_mappature, '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_mappature, '[]'::jsonb)) = 0 then
    raise exception 'Aggiungere almeno una corrispondenza';
  end if;

  select secret_vault_id into v_secret_id
  from public.google_sheet_configurazioni where id = p_id;

  if v_secret_id is null then
    if p_secret is null then raise exception 'Secret obbligatorio'; end if;
    v_secret_id := vault.create_secret(
      p_secret,
      'google_sheet_config_' || v_id::text,
      'Secret Apps Script configurazione ' || p_nome
    );
  elsif p_secret is not null then
    perform vault.update_secret(v_secret_id, p_secret);
  end if;

  insert into public.google_sheet_configurazioni (
    id, nome, script_url, sheet_url, secret_vault_id, sorgente_view,
    campo_id, campo_email, attiva, created_by
  ) values (
    v_id, p_nome, p_script_url, p_sheet_url, v_secret_id, p_sorgente_view,
    p_campo_id, p_campo_email, coalesce(p_attiva, false), auth.uid()
  )
  on conflict (id) do update set
    nome = excluded.nome,
    script_url = excluded.script_url,
    sheet_url = excluded.sheet_url,
    secret_vault_id = excluded.secret_vault_id,
    sorgente_view = excluded.sorgente_view,
    campo_id = excluded.campo_id,
    campo_email = excluded.campo_email,
    attiva = excluded.attiva,
    updated_at = now();

  delete from public.google_sheet_mappature where configurazione_id = v_id;
  for v_mappa in select value from jsonb_array_elements(p_mappature)
  loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = p_sorgente_view
        and column_name = btrim(v_mappa->>'campo_sorgente')
    ) then
      raise exception 'Campo sorgente non valido: %', v_mappa->>'campo_sorgente';
    end if;
    if nullif(btrim(v_mappa->>'colonna_google'), '') is null then
      raise exception 'Nome colonna Google obbligatorio';
    end if;

    insert into public.google_sheet_mappature (
      configurazione_id, campo_sorgente, colonna_google, ordine
    ) values (
      v_id,
      btrim(v_mappa->>'campo_sorgente'),
      btrim(v_mappa->>'colonna_google'),
      v_ordine
    );
    v_ordine := v_ordine + 1;
  end loop;

  return v_id;
end;
$function$;

create or replace function public.google_sheet_configurazione_elimina(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'vault'
as $function$
declare
  v_secret_id uuid;
begin
  if not public.app_owner(auth.uid()) then
    raise exception 'Operazione riservata al proprietario';
  end if;
  delete from public.google_sheet_configurazioni
  where id = p_id returning secret_vault_id into v_secret_id;
  if v_secret_id is not null then
    delete from vault.secrets where id = v_secret_id;
    return true;
  end if;
  return false;
end;
$function$;

create or replace function public.google_sheet_configurazione_runtime(
  p_id uuid default null,
  p_sorgente_view text default null
)
returns jsonb
language sql
stable security definer
set search_path to 'public', 'vault'
as $function$
  select jsonb_build_object(
    'id', c.id,
    'script_url', c.script_url,
    'sheet_url', c.sheet_url,
    'script_secret', v.decrypted_secret,
    'sorgente_view', c.sorgente_view,
    'campo_id', c.campo_id,
    'campo_email', c.campo_email,
    'mappature', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'campo_sorgente', m.campo_sorgente,
          'colonna_google', m.colonna_google
        ) order by m.ordine
      ) from public.google_sheet_mappature m
      where m.configurazione_id = c.id
    ), '[]'::jsonb)
  )
  from public.google_sheet_configurazioni c
  join vault.decrypted_secrets v on v.id = c.secret_vault_id
  where c.attiva
    and (p_id is null or c.id = p_id)
    and (p_sorgente_view is null or c.sorgente_view = p_sorgente_view)
  order by c.updated_at desc
  limit 1;
$function$;

revoke all on function public.google_sheet_sorgenti_elenco() from public, anon;
revoke all on function public.google_sheet_configurazioni_elenco() from public, anon;
revoke all on function public.google_sheet_configurazione_salva(uuid,text,text,text,text,text,text,text,boolean,jsonb) from public, anon;
revoke all on function public.google_sheet_configurazione_elimina(uuid) from public, anon;
revoke all on function public.google_sheet_configurazione_runtime(uuid,text) from public, anon, authenticated;

grant execute on function public.google_sheet_sorgenti_elenco() to authenticated;
grant execute on function public.google_sheet_configurazioni_elenco() to authenticated;
grant execute on function public.google_sheet_configurazione_salva(uuid,text,text,text,text,text,text,text,boolean,jsonb) to authenticated;
grant execute on function public.google_sheet_configurazione_elimina(uuid) to authenticated;
grant execute on function public.google_sheet_configurazione_runtime(uuid,text) to service_role;

notify pgrst, 'reload schema';
