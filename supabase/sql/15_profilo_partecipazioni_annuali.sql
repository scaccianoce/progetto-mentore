-- Storico delle partecipazioni annuali mostrato nella pagina Profilo.
-- Eseguire questo file sul progetto Supabase già esistente.

begin;

create or replace function public.partecipazioni_annuali_proprie()
returns setof public.partecipazioni_annuali
language sql
stable
security definer
set search_path = 'public'
as $function$
  select pa.*
  from public.partecipazioni_annuali pa
  where pa.user_id = auth.uid()
  order by pa.anno_accademico desc;
$function$;

revoke all privileges
on function public.partecipazioni_annuali_proprie()
from public, anon, authenticated;

grant execute
on function public.partecipazioni_annuali_proprie()
to authenticated;

commit;
