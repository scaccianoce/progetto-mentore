import { createClient } from 'npm:@supabase/supabase-js@2'

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

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null) {
    const value = error as Record<string, unknown>
    if (typeof value.message === 'string') return value.message
    try {
      return JSON.stringify(error)
    } catch (_) {
      return String(error)
    }
  }
  return String(error)
}

function parseSecretKey(): string {
  const direct = Deno.env.get('PROJECT_SECRET_KEY')?.trim()
  if (direct) return direct

  const mapRaw = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (mapRaw) {
    try {
      const values = JSON.parse(mapRaw)
      if (typeof values?.default === 'string' && values.default.length > 0) {
        return values.default
      }
    } catch (_) {
      // Messaggio esplicito sotto.
    }
  }

  throw new Error(
    'Secret key Supabase non configurata. Usa SUPABASE_SECRET_KEYS oppure PROJECT_SECRET_KEY.',
  )
}

function base64Url(bytes: Uint8Array): string {
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)))
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll(/\s/g, '')
  const binary = atob(clean)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

async function googleAccessToken(serviceAccount: Record<string, string>) {
  const now = Math.floor(Date.now() / 1000)
  const header = base64UrlJson({ alg: 'RS256', typ: 'JWT' })
  const payload = base64UrlJson({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })

  const unsigned = `${header}.${payload}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })

  const data = await response.json()
  if (!response.ok || typeof data.access_token !== 'string') {
    throw new Error(`OAuth Firebase non riuscito: ${JSON.stringify(data)}`)
  }
  return data.access_token as string
}

type Chiamante =
  | { tipo: 'cron' }
  | { tipo: 'utente'; userId: string }

async function verificaChiamante(
  req: Request,
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<Chiamante> {
  const cronSecret = Deno.env.get('NOTIFICHE_CRON_SECRET')?.trim()
  if (
    cronSecret &&
    req.headers.get('x-cron-secret') === cronSecret
  ) {
    return { tipo: 'cron' }
  }

  const authHeader = req.headers.get('Authorization')
  const apiKey = req.headers.get('apikey')
  if (!authHeader || !apiKey) throw new Error('Utente non autenticato')

  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, apiKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: userData, error: userError } = await userClient.auth.getUser()
  if (userError || !userData.user) throw new Error('Utente non autenticato')

  const { data: roleRow, error: roleError } = await supabaseAdmin
    .from('user_roles')
    .select('role')
    .eq('user_id', userData.user.id)
    .maybeSingle()

  if (roleError) throw roleError
  if (roleRow?.role !== 'owner' && roleRow?.role !== 'organizer') {
    throw new Error('Operazione consentita solo a owner o organizer')
  }

  return { tipo: 'utente', userId: userData.user.id }
}

async function inviaFcm(
  accessToken: string,
  projectId: string,
  token: string,
  messaggio: Record<string, unknown>,
) {
  const dataPayload: Record<string, string> = {
    messaggio_id: String(messaggio.id ?? ''),
    anno_accademico: String(messaggio.anno_accademico ?? ''),
    origine_tabella: String(messaggio.origine_tabella ?? ''),
    origine_id: String(messaggio.origine_id ?? ''),
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
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
            title: String(messaggio.titolo ?? 'Notifica'),
            body: String(messaggio.messaggio ?? ''),
          },
          data: dataPayload,
          android: {
            priority: 'high',
            notification: { sound: 'default' },
          },
          apns: {
            payload: { aps: { sound: 'default' } },
          },
          webpush: {
            notification: {
              title: String(messaggio.titolo ?? 'Notifica'),
              body: String(messaggio.messaggio ?? ''),
              icon: '/icons/Icon-192.png',
            },
            fcm_options: {
              link: '/#/notifiche',
            },
          },
        },
      }),
    },
  )

  const result = await response.json().catch(() => ({}))
  return { ok: response.ok, status: response.status, result }
}

async function generaDestinatari(
  supabaseAdmin: ReturnType<typeof createClient>,
  messaggioId: string,
) {
  const { data, error } = await supabaseAdmin.rpc(
    'notifiche_genera_destinatari',
    { p_messaggio_id: messaggioId },
  )
  if (error) throw error
  return Number(data ?? 0)
}

async function inviaMessaggio(
  supabaseAdmin: ReturnType<typeof createClient>,
  accessToken: string,
  serviceAccount: Record<string, string>,
  messaggio: Record<string, any>,
) {
  if (
    messaggio.programmata_per &&
    new Date(messaggio.programmata_per) > new Date()
  ) {
    return null
  }

  const destinatariGenerati = await generaDestinatari(
    supabaseAdmin,
    String(messaggio.id),
  )

  await supabaseAdmin
    .from('notifiche_messaggi')
    .update({ stato: 'in_invio' })
    .eq('id', messaggio.id)

  const { data: destinatari, error: destinatariError } = await supabaseAdmin
    .from('notifiche_destinatari')
    .select('id, user_id, stato')
    .eq('messaggio_id', messaggio.id)
    .in('stato', ['da_inviare', 'errore', 'senza_dispositivo'])

  if (destinatariError) throw destinatariError

  const userIds = [...new Set((destinatari ?? []).map((d) => d.user_id))]
  const attivi = new Set<string>()

  if (userIds.length > 0) {
    const { data: righeAttive, error: attiviError } = await supabaseAdmin
      .from('anagrafica_riservata')
      .select('user_id')
      .in('user_id', userIds)
      .eq('attivo', true)
    if (attiviError) throw attiviError
    for (const r of righeAttive ?? []) attivi.add(r.user_id)
  }

  let inviati = 0
  let errori = 0
  let senzaDispositivo = 0
  let esclusi = 0

  for (const destinatario of destinatari ?? []) {
    if (!attivi.has(destinatario.user_id)) {
      esclusi++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({ stato: 'escluso_inattivo', errore: null })
        .eq('id', destinatario.id)
      continue
    }

    const { data: dispositivi, error: dispositiviError } = await supabaseAdmin
      .from('notifiche_dispositivi')
      .select('id, token')
      .eq('user_id', destinatario.user_id)
      .eq('attivo', true)

    if (dispositiviError) throw dispositiviError

    if (!dispositivi || dispositivi.length === 0) {
      senzaDispositivo++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({ stato: 'senza_dispositivo', errore: null })
        .eq('id', destinatario.id)
      continue
    }

    let almenoUno = false
    const erroriToken: string[] = []

    for (const dispositivo of dispositivi) {
      const esito = await inviaFcm(
        accessToken,
        serviceAccount.project_id,
        dispositivo.token,
        messaggio,
      )

      if (esito.ok) {
        almenoUno = true
      } else {
        const testo = JSON.stringify(esito.result)
        erroriToken.push(testo)

        if (
          testo.includes('UNREGISTERED') ||
          testo.includes('registration-token-not-registered')
        ) {
          await supabaseAdmin
            .from('notifiche_dispositivi')
            .update({ attivo: false })
            .eq('id', dispositivo.id)
        }
      }
    }

    if (almenoUno) {
      inviati++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({
          stato: 'inviato',
          inviato_at: new Date().toISOString(),
          errore: null,
        })
        .eq('id', destinatario.id)
    } else {
      errori++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({
          stato: 'errore',
          errore: erroriToken.join('\n').slice(0, 4000),
        })
        .eq('id', destinatario.id)
    }
  }

  // Nessun destinatario effettivo: il processamento e comunque concluso.
  // Il dettaglio destinatari mostra chiaramente 0 righe.
  let stato = 'inviato'
  if (errori > 0 || senzaDispositivo > 0) {
    stato = inviati > 0 ? 'parziale' : 'errore'
  }

  await supabaseAdmin
    .from('notifiche_messaggi')
    .update({
      stato,
      inviata_at: new Date().toISOString(),
    })
    .eq('id', messaggio.id)

  return {
    messaggio_id: messaggio.id,
    destinatari_generati: destinatariGenerati,
    inviati,
    errori,
    senza_dispositivo: senzaDispositivo,
    esclusi_inattivi: esclusi,
    stato,
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }
  if (req.method !== 'POST') {
    return json({ error: 'Metodo non consentito' }, 405)
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    if (!supabaseUrl) throw new Error('SUPABASE_URL mancante')

    const secretKey = parseSecretKey()
    const supabaseAdmin = createClient(supabaseUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const chiamante = await verificaChiamante(req, supabaseAdmin)
    const body = await req.json().catch(() => ({}))
    const azione = body?.azione?.toString()
    const messaggioId = body?.messaggio_id?.toString()

    // Il Cron, prima di spedire la coda, crea i messaggi dovuti dalle regole
    // di tipo data e programmata.
    let materializzati = 0
    if (chiamante.tipo === 'cron' || azione === 'processa_coda') {
      if (chiamante.tipo !== 'cron') {
        throw new Error('processa_coda puo essere richiamata soltanto dal Cron')
      }
      const { data, error } = await supabaseAdmin.rpc(
        'notifiche_materializza_regole_temporali',
      )
      if (error) throw error
      materializzati = Number(data ?? 0)
    }

    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if (!serviceAccountRaw) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON non configurato nei Secrets')
    }

    const serviceAccount = JSON.parse(serviceAccountRaw) as Record<string, string>
    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON incompleto')
    }

    const accessToken = await googleAccessToken(serviceAccount)

    let messaggi: Array<Record<string, any>> = []

    if (messaggioId) {
      // Invio/retry manuale esplicito: ammette anche errore/parziale.
      const { data, error } = await supabaseAdmin
        .from('notifiche_messaggi')
        .select('*')
        .eq('id', messaggioId)
        .in('stato', [
          'da_inviare',
          'programmato',
          'errore',
          'parziale',
        ])
        .limit(1)
      if (error) throw error
      messaggi = data ?? []
    } else {
      // Worker automatico: non ritenta all'infinito i messaggi in errore.
      // Gli errori/parziali possono essere ritentati esplicitamente dal backoffice.
      const ora = new Date().toISOString()
      const { data, error } = await supabaseAdmin
        .from('notifiche_messaggi')
        .select('*')
        .in('stato', ['da_inviare', 'programmato'])
        .or(`programmata_per.is.null,programmata_per.lte.${ora}`)
        .order('created_at', { ascending: true })
        .limit(100)
      if (error) throw error
      messaggi = data ?? []
    }

    const riepilogo: Array<Record<string, unknown>> = []
    for (const messaggio of messaggi) {
      const esito = await inviaMessaggio(
        supabaseAdmin,
        accessToken,
        serviceAccount,
        messaggio,
      )
      if (esito) riepilogo.push(esito)
    }

    return json({
      ok: true,
      materializzati,
      processati: riepilogo.length,
      messaggi: riepilogo,
    })
  } catch (error) {
    console.error('ERRORE notifiche-invia:', error)
    return json({ error: errorMessage(error) }, 500)
  }
})
