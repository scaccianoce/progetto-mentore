import { withSupabase } from 'npm:@supabase/server'

export default {
  fetch: withSupabase(
    { auth: 'secret:google_sheet_sync' },

    async (req, ctx) => {
      try {
        const payload = await req.json()

        const mentoraggioId = payload.record?.id

        if (!mentoraggioId) {
          throw new Error('mentoraggio_id mancante')
        }

        const { data, error } = await ctx.supabaseAdmin
          .from('mentoraggi_google_sheet')
          .select(`
            mentoraggio_id,
            email_unipa,
            data_visita_1,
            data_visita_2,
            data_focus_group,
            data_incontro_finale,
            data_invio_scheda
          `)
          .eq('mentoraggio_id', mentoraggioId)
          .maybeSingle()

        if (error) {
          throw error
        }

        if (!data) {
          throw new Error(
            `Mentoraggio ${mentoraggioId} non trovato`
          )
        }

        if (!data.email_unipa) {
          throw new Error(
            `Email UniPa mancante per ${mentoraggioId}`
          )
        }

        const scriptUrl = Deno.env.get('GOOGLE_SCRIPT_URL')
        const scriptSecret = Deno.env.get('GOOGLE_SCRIPT_SECRET')

        if (!scriptUrl) {
          throw new Error('GOOGLE_SCRIPT_URL mancante')
        }

        if (!scriptSecret) {
          throw new Error('GOOGLE_SCRIPT_SECRET mancante')
        }

        const response = await fetch(scriptUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            secret: scriptSecret,
            email: data.email_unipa,
            data_visita_1: data.data_visita_1 ?? '',
            data_visita_2: data.data_visita_2 ?? '',
            data_focus_group: data.data_focus_group ?? '',
            data_incontro_finale:
              data.data_incontro_finale ?? '',
            data_invio_scheda:
              data.data_invio_scheda ?? '',
          }),
        })

        const testo = await response.text()

        let risultato: any

        try {
          risultato = JSON.parse(testo)
        } catch {
          throw new Error(
            `Risposta Apps Script non valida: ${testo}`
          )
        }

        if (!response.ok) {
          throw new Error(
            `Errore HTTP Apps Script ${response.status}: ${testo}`
          )
        }

        if (!risultato.ok) {
          throw new Error(
            risultato.error ??
              'Errore sconosciuto restituito da Apps Script'
          )
        }

        return Response.json({
          ok: true,
          mentoraggio_id: mentoraggioId,
          email: data.email_unipa,
          riga_google: risultato.riga,
        })
      } catch (error) {
        console.error(error)

        return Response.json(
          {
            ok: false,
            error:
              error instanceof Error
                ? error.message
                : 'Errore sconosciuto',
          },
          { status: 500 },
        )
      }
    },
  ),
}
