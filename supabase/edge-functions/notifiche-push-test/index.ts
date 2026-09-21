import { GoogleAuth } from 'npm:google-auth-library@9'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
    },
  })
}

function messaggioErrore(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  if (req.method !== 'POST') {
    return json({ ok: false, errore: 'Metodo non consentito' }, 405)
  }

  try {
    const secretAtteso = Deno.env.get('NOTIFICHE_CRON_SECRET')?.trim()
    const secretRicevuto = req.headers.get('x-cron-secret')?.trim()
    if (!secretAtteso || secretRicevuto !== secretAtteso) {
      return json({ ok: false, errore: 'Chiamata non autorizzata' }, 401)
    }

    const body = await req.json() as Record<string, unknown>
    const token = String(body.token ?? '').trim()
    const titolo = String(body.titolo ?? 'Test push').trim()
    const messaggio = String(
      body.messaggio ?? 'Notifica di prova dal Progetto Mentore',
    ).trim()

    if (!token) {
      return json({ ok: false, errore: 'Il campo token e obbligatorio' }, 400)
    }

    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if (!serviceAccountRaw) {
      throw new Error('Secret FIREBASE_SERVICE_ACCOUNT_JSON non configurato')
    }

    const serviceAccount = JSON.parse(serviceAccountRaw) as {
      project_id?: string
      client_email?: string
      private_key?: string
    }

    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON incompleto')
    }

    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    const accessToken = await auth.getAccessToken()
    if (!accessToken) {
      throw new Error('Impossibile ottenere il token OAuth di Firebase')
    }

    const rispostaFcm = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: titolo || 'Test push',
              body: messaggio,
            },
            data: {
              tipo: 'test',
              origine_tabella: 'test',
            },
          },
        }),
      },
    )

    const risposta = await rispostaFcm.json().catch(() => ({}))
    if (!rispostaFcm.ok) {
      return json(
        {
          ok: false,
          errore: 'FCM ha rifiutato la notifica',
          stato_fcm: rispostaFcm.status,
          risposta_fcm: risposta,
        },
        rispostaFcm.status,
      )
    }

    return json({
      ok: true,
      messaggio: 'Notifica push inviata',
      risposta_fcm: risposta,
    })
  } catch (error) {
    return json({ ok: false, errore: messaggioErrore(error) }, 500)
  }
})
