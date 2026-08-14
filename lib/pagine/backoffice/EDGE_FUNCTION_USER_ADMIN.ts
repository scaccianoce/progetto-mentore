// Deploy come Supabase Edge Function: backoffice-user-admin
// NON viene eseguito da Flutter. La service role resta esclusivamente server-side.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') return json({ error: 'Metodo non consentito' }, 405)

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader.startsWith('Bearer ')) return json({ error: 'Non autenticato' }, 401)

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: authData, error: authError } = await callerClient.auth.getUser()
    if (authError || !authData.user) return json({ error: 'Sessione non valida' }, 401)

    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    const callerId = authData.user.id
    const { data: callerRoleRow, error: roleError } = await admin
      .from('user_roles')
      .select('role')
      .eq('user_id', callerId)
      .single()
    if (roleError) throw roleError
    const callerRole = String(callerRoleRow.role)
    if (callerRole !== 'owner' && callerRole !== 'organizer') {
      return json({ error: 'Operazione non autorizzata' }, 403)
    }

    const body = await req.json()
    const action = String(body.action ?? '')

    // Le operazioni globali su auth.users sono riservate all'owner.
    if (action === 'list_users') {
      if (callerRole !== 'owner') return json({ error: 'Operazione riservata all owner' }, 403)
      const page = Number(body.page ?? 1)
      const perPage = Math.min(Number(body.per_page ?? 1000), 1000)
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage })
      if (error) throw error
      return json({ users: data.users, page, per_page: perPage }, 200)
    }

    if (action === 'create') {
      const email = String(body.email ?? '').trim()
      const password = String(body.password ?? '')
      const input = { ...(body.anagrafica ?? {}) } as Record<string, unknown>
      if (!email || password.length < 8) {
        return json({ error: 'Email o password temporanea non valide' }, 400)
      }

      // Evita di inviare null inutili: in questo modo i DEFAULT PostgreSQL
      // continuano a funzionare. user_id/email vengono imposti dal server.
      const anagrafica: Record<string, unknown> = {}
      for (const [key, value] of Object.entries(input)) {
        if (key === 'user_id' || key === 'created_at' || key === 'updated_at') continue
        if (value !== null && value !== undefined) anagrafica[key] = value
      }

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      })
      if (createError || !created.user) throw createError ?? new Error('Utente non creato')

      const userId = created.user.id
      anagrafica.user_id = userId
      anagrafica.email_unipa = email

      // Le tre scritture applicative sono fatte lato server con service role.
      // In caso di errore viene eseguito un rollback compensativo, incluso Auth.
      try {
        const { error: anagraficaError } = await admin
          .from('anagrafica')
          .insert(anagrafica)
        if (anagraficaError) throw anagraficaError

        const { error: riservataError } = await admin
          .from('anagrafica_riservata')
          .insert({ user_id: userId, attivo: true })
        if (riservataError) throw riservataError

        const { error: roleInsertError } = await admin
          .from('user_roles')
          .insert({ user_id: userId, role: 'participant' })
        if (roleInsertError) throw roleInsertError
      } catch (e) {
        await admin.from('user_roles').delete().eq('user_id', userId)
        await admin.from('anagrafica_riservata').delete().eq('user_id', userId)
        await admin.from('anagrafica').delete().eq('user_id', userId)
        await admin.auth.admin.deleteUser(userId)
        throw e
      }
      return json({ user_id: userId }, 200)
    }

    if (action === 'reset_password') {
      const targetId = String(body.user_id ?? '')
      const password = String(body.password ?? '')
      if (!targetId || password.length < 8) return json({ error: 'Utente o password non validi' }, 400)
      const { data: targetRoleRow, error: targetRoleError } = await admin
        .from('user_roles').select('role').eq('user_id', targetId).maybeSingle()
      if (targetRoleError) throw targetRoleError
      const targetRole = targetRoleRow?.role == null ? '' : String(targetRoleRow.role)
      if (callerRole === 'organizer' && targetRole !== 'participant') {
        return json({ error: 'Un organizer puo reimpostare solo partecipanti' }, 403)
      }
      const { error } = await admin.auth.admin.updateUserById(targetId, { password })
      if (error) throw error
      return json({ ok: true }, 200)
    }

    if (action === 'update_participant_email') {
      const targetId = String(body.user_id ?? '')
      const email = String(body.email ?? '').trim()
      if (!targetId || !email) return json({ error: 'Utente o email non validi' }, 400)
      const { data: targetRoleRow, error: targetRoleError } = await admin
        .from('user_roles').select('role').eq('user_id', targetId).maybeSingle()
      if (targetRoleError) throw targetRoleError
      const targetRole = targetRoleRow?.role == null ? '' : String(targetRoleRow.role)
      if (callerRole === 'organizer' && targetRole !== 'participant') {
        return json({ error: 'Un organizer puo modificare solo partecipanti' }, 403)
      }
      const { data: oldUser, error: getError } = await admin.auth.admin.getUserById(targetId)
      if (getError || !oldUser.user) throw getError ?? new Error('Utente Auth non trovato')
      const oldEmail = oldUser.user.email ?? ''
      const { error: authUpdateError } = await admin.auth.admin.updateUserById(targetId, {
        email,
        email_confirm: true,
      })
      if (authUpdateError) throw authUpdateError
      const { error: dbUpdateError } = await admin
        .from('anagrafica').update({ email_unipa: email }).eq('user_id', targetId)
      if (dbUpdateError) {
        if (oldEmail) await admin.auth.admin.updateUserById(targetId, { email: oldEmail, email_confirm: true })
        throw dbUpdateError
      }
      return json({ ok: true }, 200)
    }

    if (action === 'delete_participant') {
      const targetId = String(body.user_id ?? '')
      if (!targetId) return json({ error: 'Utente non valido' }, 400)
      if (targetId === callerId) return json({ error: 'Non puoi eliminare il tuo stesso account' }, 400)
      const { data: targetRoleRow, error: targetRoleError } = await admin
        .from('user_roles').select('role').eq('user_id', targetId).maybeSingle()
      if (targetRoleError) throw targetRoleError
      const targetRole = targetRoleRow?.role == null ? '' : String(targetRoleRow.role)
      if (callerRole === 'organizer' && targetRole !== 'participant') {
        return json({ error: 'Un organizer puo eliminare solo partecipanti' }, 403)
      }
      // Prima le tabelle applicative: eventuali FK storiche bloccano la
      // cancellazione senza lasciare un utente applicativo privo di Auth.
      const { error: roleDeleteError } = await admin.from('user_roles').delete().eq('user_id', targetId)
      if (roleDeleteError) throw roleDeleteError
      const { error: reservedDeleteError } = await admin.from('anagrafica_riservata').delete().eq('user_id', targetId)
      if (reservedDeleteError) throw reservedDeleteError
      const { error: registryDeleteError } = await admin.from('anagrafica').delete().eq('user_id', targetId)
      if (registryDeleteError) throw registryDeleteError
      const { error: authDeleteError } = await admin.auth.admin.deleteUser(targetId, false)
      if (authDeleteError) throw authDeleteError
      return json({ ok: true }, 200)
    }

    if (['update_email', 'confirm_email', 'set_banned', 'delete_user'].includes(action)) {
      if (callerRole !== 'owner') return json({ error: 'Operazione riservata all owner' }, 403)
      const targetId = String(body.user_id ?? '')
      if (!targetId) return json({ error: 'Utente non valido' }, 400)
      if (targetId === callerId && (action === 'set_banned' || action === 'delete_user')) {
        return json({ error: 'Non puoi disabilitare o eliminare il tuo stesso account' }, 400)
      }

      if (action === 'update_email') {
        const email = String(body.email ?? '').trim()
        if (!email) return json({ error: 'Email non valida' }, 400)
        const { error } = await admin.auth.admin.updateUserById(targetId, { email })
        if (error) throw error
      } else if (action === 'confirm_email') {
        const { error } = await admin.auth.admin.updateUserById(targetId, { email_confirm: true })
        if (error) throw error
      } else if (action === 'set_banned') {
        const banned = body.banned === true
        const { error } = await admin.auth.admin.updateUserById(targetId, {
          ban_duration: banned ? '876000h' : 'none',
        })
        if (error) throw error
      } else if (action === 'delete_user') {
        const { error } = await admin.auth.admin.deleteUser(targetId, false)
        if (error) throw error
      }
      return json({ ok: true }, 200)
    }

    return json({ error: 'Azione non riconosciuta' }, 400)
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500)
  }
})

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
  })
}
