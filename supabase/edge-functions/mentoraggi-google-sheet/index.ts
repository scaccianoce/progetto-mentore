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

        const { data: configurazione, error: configurazioneError } =
          await ctx.supabaseAdmin.rpc(
            'google_sheet_configurazione_runtime',
            {
              p_sorgente_view: 'mentoraggi_google_sheet',
            },
          )

        // Consente di distribuire la funzione anche prima della migrazione 31:
        // in quel breve intervallo continua a usare i secret di ambiente.
        if (
          configurazioneError &&
          configurazioneError.code !== 'PGRST202' &&
          configurazioneError.code !== '42883'
        ) {
          throw configurazioneError
        }

        const mappaturePredefinite = [
          'data_visita_1',
          'data_visita_2',
          'data_focus_group',
          'data_incontro_finale',
          'data_invio_scheda',
        ].map((campo) => ({
          campo_sorgente: campo,
          colonna_google: campo,
        }))

        const runtime = configurazione as Record<string, unknown> | null
        const sorgente = String(
          runtime?.sorgente_view ?? 'mentoraggi_google_sheet',
        )
        const campoId = String(runtime?.campo_id ?? 'mentoraggio_id')
        const campoEmail = String(runtime?.campo_email ?? 'email_unipa')
        const mappature = Array.isArray(runtime?.mappature)
          ? runtime.mappature as Array<Record<string, unknown>>
          : mappaturePredefinite

        const identificatoreValido = /^[a-z_][a-z0-9_]*$/
        const campi = [
          campoId,
          campoEmail,
          ...mappature.map((m) => String(m.campo_sorgente ?? '')),
        ]
        if (
          !identificatoreValido.test(sorgente) ||
          campi.some((campo) => !identificatoreValido.test(campo))
        ) {
          throw new Error('Configurazione sorgente non valida')
        }

        const { data, error } = await ctx.supabaseAdmin
          .from(sorgente)
          .select([...new Set(campi)].join(','))
          .eq(campoId, mentoraggioId)
          .maybeSingle()

        if (error) throw error
        if (!data) {
          throw new Error(`Mentoraggio ${mentoraggioId} non trovato`)
        }

        const email = String(data[campoEmail] ?? '').trim().toLowerCase()
        if (!email) {
          throw new Error(`Email UniPa mancante per ${mentoraggioId}`)
        }

        const scriptUrl = String(
          runtime?.script_url ?? Deno.env.get('GOOGLE_SCRIPT_URL') ?? '',
        ).trim()
        const scriptSecret = String(
          runtime?.script_secret ?? Deno.env.get('GOOGLE_SCRIPT_SECRET') ?? '',
        ).trim()
        const sheetUrl = String(runtime?.sheet_url ?? '').trim()

        if (!scriptUrl) {
          throw new Error('GOOGLE_SCRIPT_URL mancante')
        }

        if (!scriptSecret) {
          throw new Error('GOOGLE_SCRIPT_SECRET mancante')
        }

        const valori: Record<string, unknown> = {}
        const valoriLegacy: Record<string, unknown> = {}
        let colonnaEmail = 'email'
        for (const mappa of mappature) {
          const campo = String(mappa.campo_sorgente ?? '')
          const colonna = String(mappa.colonna_google ?? '').trim()
          if (!campo || !colonna) continue
          valori[colonna] = data[campo] ?? ''
          valoriLegacy[campo] = data[campo] ?? ''
          if (campo === campoEmail) colonnaEmail = colonna
        }

        const response = await fetch(scriptUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            secret: scriptSecret,
            email,
            sheet_url: sheetUrl,
            colonna_email: colonnaEmail,
            valori,
            ...valoriLegacy,
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
          configurazione_id: runtime?.id ?? null,
          email,
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
