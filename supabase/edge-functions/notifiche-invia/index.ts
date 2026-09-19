import { createClient } from 'npm:@supabase/supabase-js@2'
import nodemailer from 'npm:nodemailer@6'

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

type SmtpConfig = {
  host: string
  port: number
  secure: boolean
  user: string
  pass: string
  fromEmail: string
  replyTo?: string
}

type FcmConfig = {
  accessToken: string
  projectId: string
}

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

  const accessToken = authHeader.replace(/^Bearer\s+/i, '').trim()
  if (!accessToken) throw new Error('Token utente mancante')

  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, apiKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: userData, error: userError } =
    await userClient.auth.getUser(accessToken)
  if (userError || !userData.user) {
    throw new Error(
      `Token utente non valido: ${userError?.message ?? 'utente assente'}`,
    )
  }

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

function parseBool(value: string | undefined, fallback: boolean): boolean {
  if (!value) return fallback
  const normalized = value.trim().toLowerCase()
  if (['1', 'true', 'yes', 'y', 'on'].includes(normalized)) return true
  if (['0', 'false', 'no', 'n', 'off'].includes(normalized)) return false
  return fallback
}

function parseSmtpConfig(): SmtpConfig | null {
  const host = Deno.env.get('SMTP_HOST')?.trim() || 'smtp.aruba.it'
  const portRaw = Deno.env.get('SMTP_PORT')?.trim() || '465'
  const secure = parseBool(Deno.env.get('SMTP_SECURE'), portRaw === '465')
  const user = Deno.env.get('SMTP_USER')?.trim()
  const pass = Deno.env.get('SMTP_PASS')?.trim()
  const fromEmail = Deno.env.get('SMTP_FROM_EMAIL')?.trim()
  const replyTo = Deno.env.get('SMTP_REPLY_TO')?.trim()

  const port = Number(portRaw)
  if (!Number.isFinite(port) || port <= 0) return null
  if (!user || !pass || !fromEmail) return null

  return {
    host,
    port,
    secure,
    user,
    pass,
    fromEmail,
    replyTo: replyTo || undefined,
  }
}

async function inviaSmtpEmail(
  transporter: any,
  config: SmtpConfig,
  to: string,
  subject: string,
  textBody: string,
) {
  const payload: Record<string, unknown> = {
    from: config.fromEmail,
    to,
    subject,
    text: textBody,
  }
  if (config.replyTo) payload.replyTo = config.replyTo

  try {
    const result = await transporter.sendMail(payload)
    return { ok: true, status: 200, result }
  } catch (error) {
    return {
      ok: false,
      status: 500,
      result: { message: errorMessage(error) },
    }
  }
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

async function pianificaEmailMessaggio(
  supabaseAdmin: ReturnType<typeof createClient>,
  messaggioId: string,
) {
  const { data, error } = await supabaseAdmin.rpc(
    'notifiche_email_pianifica_messaggio',
    {
      p_messaggio_id: messaggioId,
      p_limite_giornaliero: 90,
    },
  )
  if (error) throw error

  const oggi = new Date().toISOString().slice(0, 10)
  const { count, error: countError } = await supabaseAdmin
    .from('notifiche_destinatari')
    .select('*', { count: 'exact', head: true })
    .eq('messaggio_id', messaggioId)
    .eq('email_stato', 'in_coda')
    .lte('email_programmata_per', oggi)

  if (countError) throw countError

  return {
    pianificate: Number(data ?? 0),
    pronteOggi: Number(count ?? 0),
  }
}

async function inviaEmailMessaggio(
  supabaseAdmin: ReturnType<typeof createClient>,
  messaggio: Record<string, any>,
  smtpConfig: SmtpConfig | null,
) {
  const oggi = new Date().toISOString().slice(0, 10)
  const nowIso = new Date().toISOString()

  const { data: candidati, error: candidatiError } = await supabaseAdmin
    .from('notifiche_destinatari')
    .select('id, user_id, email_tentativi')
    .eq('messaggio_id', messaggio.id)
    .eq('email_stato', 'in_coda')
    .lte('email_programmata_per', oggi)

  if (candidatiError) throw candidatiError

  const userIds = [
    ...new Set((candidati ?? []).map((d: { user_id: string }) => d.user_id)),
  ]
  const emailPerUtente = new Map<string, string>()

  if (userIds.length > 0) {
    const { data: anagrafiche, error: anagraficheError } = await supabaseAdmin
      .from('anagrafica')
      .select('user_id, email_unipa')
      .in('user_id', userIds)
    if (anagraficheError) throw anagraficheError

    for (const r of anagrafiche ?? []) {
      const email = r.email_unipa?.toString().trim()
      if (email) emailPerUtente.set(r.user_id, email)
    }
  }

  let inviate = 0
  let fallite = 0
  let senzaEmail = 0
  const transporter = smtpConfig
    ? nodemailer.createTransport({
        host: smtpConfig.host,
        port: smtpConfig.port,
        secure: smtpConfig.secure,
        auth: {
          user: smtpConfig.user,
          pass: smtpConfig.pass,
        },
      })
    : null

  for (const candidato of candidati ?? []) {
    const tentativi = Number(candidato.email_tentativi ?? 0)
    const emailDestinatario = emailPerUtente.get(candidato.user_id)

    if (!emailDestinatario) {
      senzaEmail++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({
          email_stato: 'fallita',
          email_tentativi: tentativi + 1,
          email_errore: 'Email destinatario assente in anagrafica.',
        })
        .eq('id', candidato.id)
      continue
    }

    if (!smtpConfig || !transporter) {
      fallite++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({
          email_stato: 'fallita',
          email_tentativi: tentativi + 1,
          email_errore: 'SMTP non configurato (SMTP_USER/SMTP_PASS/SMTP_FROM_EMAIL).',
        })
        .eq('id', candidato.id)
      continue
    }

    const esito = await inviaSmtpEmail(
      transporter,
      smtpConfig,
      emailDestinatario,
      String(messaggio.titolo ?? 'Notifica'),
      String(messaggio.messaggio ?? ''),
    )

    if (esito.ok) {
      inviate++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({
          email_stato: 'inviata',
          email_tentativi: tentativi + 1,
          email_inviata_at: nowIso,
          email_errore: null,
        })
        .eq('id', candidato.id)
    } else {
      fallite++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({
          email_stato: 'fallita',
          email_tentativi: tentativi + 1,
          email_errore: JSON.stringify(esito.result).slice(0, 4000),
        })
        .eq('id', candidato.id)
    }
  }

  return {
    pronte: (candidati ?? []).length,
    inviate,
    fallite,
    senza_email: senzaEmail,
  }
}

async function inviaMessaggio(
  supabaseAdmin: ReturnType<typeof createClient>,
  messaggio: Record<string, any>,
  fcmConfig: FcmConfig | null,
  smtpConfig: SmtpConfig | null,
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

  const inviaPush = messaggio.invia_push !== false
  const inviaEmail = messaggio.invia_email === true

  let emailPianificate = 0
  let emailPronteOggi = 0
  if (inviaEmail) {
    // Compatibilita': alcuni flussi legacy generano destinatari con
    // email_stato='non_richiesta' anche quando il messaggio richiede email.
    // Li riallineiamo prima della pianificazione.
    const { error: riallineaEmailError } = await supabaseAdmin
      .from('notifiche_destinatari')
      .update({ email_stato: 'da_inviare' })
      .eq('messaggio_id', messaggio.id)
      .eq('email_stato', 'non_richiesta')
    if (riallineaEmailError) throw riallineaEmailError

    const email = await pianificaEmailMessaggio(
      supabaseAdmin,
      String(messaggio.id),
    )
    emailPianificate = email.pianificate
    emailPronteOggi = email.pronteOggi
  }

  const esitoEmail = inviaEmail
    ? await inviaEmailMessaggio(supabaseAdmin, messaggio, smtpConfig)
    : { pronte: 0, inviate: 0, fallite: 0, senza_email: 0 }

  if (!inviaPush && !inviaEmail) {
    await supabaseAdmin
      .from('notifiche_messaggi')
      .update({
        stato: 'errore',
        inviata_at: new Date().toISOString(),
      })
      .eq('id', messaggio.id)

    return {
      messaggio_id: messaggio.id,
      destinatari_generati: destinatariGenerati,
      inviati: 0,
      errori: 1,
      senza_dispositivo: 0,
      esclusi_inattivi: 0,
      email_pianificate: 0,
      email_pronte_oggi: 0,
      email_inviate: 0,
      email_fallite: 0,
      email_senza_indirizzo: 0,
      stato: 'errore',
      nota: 'Nessun canale abilitato (invia_push/invia_email).',
    }
  }

  if (!inviaPush) {
    await supabaseAdmin
      .from('notifiche_destinatari')
      .update({
        push_stato: 'non_richiesta',
        push_errore: null,
      })
      .eq('messaggio_id', messaggio.id)

    const haErroriEmail = esitoEmail.fallite > 0 || esitoEmail.senza_email > 0
    const haEmailPendenti = emailPianificate > esitoEmail.inviate
    const stato = haErroriEmail
      ? (esitoEmail.inviate > 0 ? 'parziale' : 'errore')
      : (haEmailPendenti ? 'programmato' : 'inviato')
    await supabaseAdmin
      .from('notifiche_messaggi')
      .update({
        stato,
        inviata_at: stato === 'inviato' ? new Date().toISOString() : null,
      })
      .eq('id', messaggio.id)

    return {
      messaggio_id: messaggio.id,
      destinatari_generati: destinatariGenerati,
      inviati: 0,
      errori: 0,
      senza_dispositivo: 0,
      esclusi_inattivi: 0,
      email_pianificate: emailPianificate,
      email_pronte_oggi: emailPronteOggi,
      email_inviate: esitoEmail.inviate,
      email_fallite: esitoEmail.fallite,
      email_senza_indirizzo: esitoEmail.senza_email,
      stato,
      nota: 'Canale push disattivato. Email processate via Resend.',
    }
  }

  if (!fcmConfig) {
    throw new Error(
      'Push richiesto ma FIREBASE_SERVICE_ACCOUNT_JSON non disponibile o non valido.',
    )
  }

  await supabaseAdmin
    .from('notifiche_messaggi')
    .update({ stato: 'in_invio' })
    .eq('id', messaggio.id)

  const { data: destinatari, error: destinatariError } = await supabaseAdmin
    .from('notifiche_destinatari')
    .select('id, user_id, push_stato')
    .eq('messaggio_id', messaggio.id)
    .in('push_stato', ['da_inviare', 'fallita'])

  if (destinatariError) throw destinatariError

  const userIds = [
    ...new Set((destinatari ?? []).map((d: { user_id: string }) => d.user_id)),
  ]
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
        .update({
          stato: 'escluso_inattivo',
          push_stato: 'esclusa',
          errore: null,
          push_errore: null,
        })
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
        .update({
          stato: 'senza_dispositivo',
          push_stato: 'esclusa',
          errore: null,
          push_errore: null,
        })
        .eq('id', destinatario.id)
      continue
    }

    let almenoUno = false
    const erroriToken: string[] = []

    for (const dispositivo of dispositivi) {
      const esito = await inviaFcm(
        fcmConfig.accessToken,
        fcmConfig.projectId,
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
          push_stato: 'inviata',
          inviato_at: new Date().toISOString(),
          push_inviata_at: new Date().toISOString(),
          errore: null,
          push_errore: null,
        })
        .eq('id', destinatario.id)
    } else {
      errori++
      await supabaseAdmin
        .from('notifiche_destinatari')
        .update({
          stato: 'errore',
          push_stato: 'fallita',
          errore: erroriToken.join('\n').slice(0, 4000),
          push_errore: erroriToken.join('\n').slice(0, 4000),
        })
        .eq('id', destinatario.id)
    }
  }

  // Nessun destinatario effettivo: il processamento e comunque concluso.
  // Il dettaglio destinatari mostra chiaramente 0 righe.
  let stato = 'inviato'
  const haErroriPush = errori > 0 || senzaDispositivo > 0
  const haErroriEmail = esitoEmail.fallite > 0 || esitoEmail.senza_email > 0
  const haEmailPendenti = emailPianificate > esitoEmail.inviate

  if (haErroriPush || haErroriEmail) {
    stato = (inviati > 0 || esitoEmail.inviate > 0) ? 'parziale' : 'errore'
  } else if (haEmailPendenti) {
    stato = 'programmato'
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
    email_pianificate: emailPianificate,
    email_pronte_oggi: emailPronteOggi,
    email_inviate: esitoEmail.inviate,
    email_fallite: esitoEmail.fallite,
    email_senza_indirizzo: esitoEmail.senza_email,
    stato,
  }
}

Deno.serve(async (req: Request) => {
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
          'in_invio',
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

    const smtpConfig = parseSmtpConfig()

    const servePush = messaggi.some((m) => m.invia_push !== false)
    let fcmConfig: FcmConfig | null = null
    if (servePush) {
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
      fcmConfig = {
        accessToken,
        projectId: serviceAccount.project_id,
      }
    }

    const riepilogo: Array<Record<string, unknown>> = []
    for (const messaggio of messaggi) {
      const esito = await inviaMessaggio(
        supabaseAdmin,
        messaggio,
        fcmConfig,
        smtpConfig,
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
