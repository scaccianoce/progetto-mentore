import { createClient } from 'npm:@supabase/supabase-js@^2'
import { corsHeaders } from 'npm:@supabase/supabase-js@^2/cors'

// ============================================================================
// CONFIGURAZIONE SUPABASE
// ============================================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// ============================================================================
// CLIENT AMMINISTRATIVO
//
// La service_role resta esclusivamente lato server.
// Viene usata per:
// - Supabase Authentication admin;
// - anagrafica;
// - anagrafica_riservata;
// - user_roles;
// - partecipazioni_annuali;
// - import_partecipanti;
// - insegnamenti;
// - mentoraggi;
// - import_insegnamenti.
// ============================================================================

const admin = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
)

// ============================================================================
// RISPOSTE JSON
// ============================================================================

function jsonResponse(
  data: unknown,
  status = 200,
) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    },
  )
}

// ============================================================================
// NORMALIZZAZIONE ERRORI
//
// Evita messaggi poco utili come:
//   [object Object]
// ============================================================================

function messaggioErrore(
  error: unknown,
): string {
  if (error instanceof Error) {
    return error.message
  }

  if (typeof error === 'string') {
    return error
  }

  if (
    error !== null &&
    typeof error === 'object'
  ) {
    const obj =
      error as Record<string, unknown>

    if (
      typeof obj.message === 'string' &&
      obj.message.trim().isNotEmpty
    ) {
      return obj.message
    }

    if (
      typeof obj.error_description === 'string'
    ) {
      return obj.error_description
    }

    try {
      return JSON.stringify(error)
    } catch (_) {
      return 'Errore non serializzabile.'
    }
  }

  return String(error)
}

// ============================================================================
// IDENTIFICAZIONE E AUTORIZZAZIONE DEL CHIAMANTE
// ============================================================================

async function getCaller(
  req: Request,
) {
  const authHeader =
    req.headers.get('Authorization')

  if (!authHeader) {
    throw new Error(
      'Authorization header mancante.',
    )
  }

  const userClient =
    createClient(
      SUPABASE_URL,
      SUPABASE_ANON_KEY,
      {
        global: {
          headers: {
            Authorization: authHeader,
          },
        },
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    )

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser()

  if (
    userError ||
    !user
  ) {
    throw new Error(
      `Utente non autenticato: ${
        userError?.message ??
        'token non valido'
      }`,
    )
  }

  const {
    data: roleRow,
    error: roleError,
  } = await admin
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .maybeSingle()

  if (roleError) {
    throw new Error(
      `Impossibile leggere il ruolo: ${roleError.message}`,
    )
  }

  const role =
    roleRow?.role?.toString()

  if (
    role !== 'owner' &&
    role !== 'organizer'
  ) {
    throw new Error(
      'Utente non autorizzato al backoffice. ' +
      `Ruolo: ${role ?? 'nessuno'}`,
    )
  }

  return {
    user,
    role,
  }
}

// ============================================================================
// RUOLO DI UN UTENTE TARGET
// ============================================================================

async function getTargetRole(
  userId: string,
) {
  const {
    data,
    error,
  } = await admin
    .from('user_roles')
    .select('role')
    .eq('user_id', userId)
    .maybeSingle()

  if (error) {
    throw new Error(
      `Impossibile leggere il ruolo dell'utente: ${error.message}`,
    )
  }

  return (
    data?.role?.toString() ??
    'participant'
  )
}

// ============================================================================
// PERMESSI SU ALTRO UTENTE
//
// owner:
//   può amministrare tutti.
//
// organizer:
//   può amministrare esclusivamente participant.
// ============================================================================

async function verificaPermessoSuUtente(
  callerRole: string,
  targetUserId: string,
) {
  if (callerRole === 'owner') {
    return
  }

  const targetRole =
    await getTargetRole(
      targetUserId,
    )

  if (targetRole !== 'participant') {
    throw new Error(
      'Un organizer può amministrare soltanto utenti participant.',
    )
  }
}

// ============================================================================
// ROLLBACK CREAZIONE UTENTE
// ============================================================================

async function rollbackUtente(
  userId: string,
) {
  await admin
    .from('partecipazioni_annuali')
    .delete()
    .eq('user_id', userId)

  await admin
    .from('user_roles')
    .delete()
    .eq('user_id', userId)

  await admin
    .from('anagrafica_riservata')
    .delete()
    .eq('user_id', userId)

  await admin
    .from('anagrafica')
    .delete()
    .eq('user_id', userId)

  await admin.auth.admin
    .deleteUser(userId)
}

// ============================================================================
// SERVER
// ============================================================================

Deno.serve(
  async (
    req: Request,
  ) => {
    // ========================================================================
    // CORS
    // ========================================================================

    if (req.method === 'OPTIONS') {
      return new Response(
        'ok',
        {
          headers: corsHeaders,
        },
      )
    }

    try {
      if (req.method !== 'POST') {
        return jsonResponse(
          {
            error:
              'Metodo non consentito.',
          },
          405,
        )
      }

      const caller =
        await getCaller(req)

      const body =
        await req.json()

      const action =
        body?.action?.toString()

      if (!action) {
        return jsonResponse(
          {
            error:
              'Parametro action mancante.',
          },
          400,
        )
      }

      // ======================================================================
      // LIST USERS
      // Solo owner.
      // ======================================================================

      if (action === 'list_users') {
        if (caller.role !== 'owner') {
          return jsonResponse(
            {
              error:
                'Solo owner può visualizzare tutti gli Users.',
            },
            403,
          )
        }

        const page =
          Number(body.page ?? 1)

        const perPage =
          Number(body.per_page ?? 1000)

        const {
          data,
          error,
        } = await admin.auth.admin
          .listUsers({
            page,
            perPage,
          })

        if (error) {
          throw new Error(
            `Elenco Authentication: ${error.message}`,
          )
        }

        return jsonResponse({
          users:
            data.users.map(
              (user) => ({
                id:
                  user.id,

                email:
                  user.email,

                phone:
                  user.phone,

                created_at:
                  user.created_at,

                updated_at:
                  user.updated_at,

                last_sign_in_at:
                  user.last_sign_in_at,

                email_confirmed_at:
                  user.email_confirmed_at,

                phone_confirmed_at:
                  user.phone_confirmed_at,

                confirmed_at:
                  user.confirmed_at,

                banned_until:
                  user.banned_until,

                user_metadata:
                  user.user_metadata,

                app_metadata:
                  user.app_metadata,
              }),
            ),
        })
      }

      // ======================================================================
      // CREATE USER / CREATE PARTICIPANT
      //
      // Crea:
      // 1. Authentication;
      // 2. anagrafica;
      // 3. anagrafica_riservata;
      // 4. user_roles.
      //
      // La partecipazione annuale viene gestita separatamente.
      // ======================================================================

      if (
        action === 'create_user' ||
        action === 'create_participant'
      ) {
        const email =
          body.email
            ?.toString()
            .trim()

        const password =
          body.password
            ?.toString()

        if (!email) {
          return jsonResponse(
            {
              error:
                'Email obbligatoria.',
            },
            400,
          )
        }

        if (
          !password ||
          password.length < 6
        ) {
          return jsonResponse(
            {
              error:
                'La password temporanea deve contenere almeno 6 caratteri.',
            },
            400,
          )
        }

        const anagrafica =
          body.anagrafica &&
          typeof body.anagrafica ===
            'object'
            ? {
                ...body.anagrafica,
              }
            : {}

        const anagraficaRiservata =
          body.anagrafica_riservata &&
          typeof body.anagrafica_riservata ===
            'object'
            ? {
                ...body
                  .anagrafica_riservata,
              }
            : {}

        const {
          data: authData,
          error: authError,
        } = await admin.auth.admin
          .createUser({
            email,
            password,
            email_confirm: true,
          })

        if (
          authError ||
          !authData.user
        ) {
          throw new Error(
            `Authentication: ${
              authError?.message ??
              'impossibile creare l’utente'
            }`,
          )
        }

        const userId =
          authData.user.id

        try {
          // -------------------------------------------------------------------
          // ANAGRAFICA
          // -------------------------------------------------------------------

          const {
            error:
              anagraficaError,
          } = await admin
            .from('anagrafica')
            .insert({
              ...anagrafica,

              user_id:
                userId,

              email_unipa:
                anagrafica.email_unipa ??
                email,
            })

          if (anagraficaError) {
            throw new Error(
              `Anagrafica: ${anagraficaError.message}`,
            )
          }

          // -------------------------------------------------------------------
          // ANAGRAFICA RISERVATA
          //
          // Usiamo UPSERT perché nel DB può esistere un trigger che crea
          // automaticamente la riga quando nasce auth.users.
          // -------------------------------------------------------------------

          const {
            error:
              riservataError,
          } = await admin
            .from(
              'anagrafica_riservata',
            )
            .upsert(
              {
                ...anagraficaRiservata,

                user_id:
                  userId,

                attivo:
                  anagraficaRiservata
                    .attivo ??
                  true,
              },
              {
                onConflict:
                  'user_id',
              },
            )

          if (riservataError) {
            throw new Error(
              'Anagrafica riservata: ' +
              riservataError.message,
            )
          }

          // -------------------------------------------------------------------
          // USER ROLE
          // -------------------------------------------------------------------

          const {
            error: roleError,
          } = await admin
            .from('user_roles')
            .insert({
              user_id:
                userId,

              role:
                'participant',
            })

          if (roleError) {
            throw new Error(
              `Ruolo: ${roleError.message}`,
            )
          }

          return jsonResponse({
            ok: true,

            user: {
              id:
                userId,

              email:
                authData.user.email,
            },
          })
        } catch (error) {
          await rollbackUtente(
            userId,
          )

          throw error
        }
      }

      // ======================================================================
      // RESET PASSWORD
      // ======================================================================

      if (action === 'reset_password') {
        const userId =
          body.user_id
            ?.toString()

        const password =
          body.password
            ?.toString()

        if (!userId) {
          return jsonResponse(
            {
              error:
                'user_id obbligatorio.',
            },
            400,
          )
        }

        if (
          !password ||
          password.length < 6
        ) {
          return jsonResponse(
            {
              error:
                'La nuova password deve contenere almeno 6 caratteri.',
            },
            400,
          )
        }

        await verificaPermessoSuUtente(
          caller.role,
          userId,
        )

        const {
          data,
          error,
        } = await admin.auth.admin
          .updateUserById(
            userId,
            {
              password,
            },
          )

        if (error) {
          throw new Error(
            `Reset password: ${error.message}`,
          )
        }

        return jsonResponse({
          ok: true,
          user:
            data.user,
        })
      }

      // ======================================================================
      // UPDATE EMAIL
      // ======================================================================

      if (
        action === 'update_email' ||
        action ===
          'update_participant_email'
      ) {
        const userId =
          body.user_id
            ?.toString()

        const email =
          body.email
            ?.toString()
            .trim()

        if (
          !userId ||
          !email
        ) {
          return jsonResponse(
            {
              error:
                'user_id ed email sono obbligatori.',
            },
            400,
          )
        }

        await verificaPermessoSuUtente(
          caller.role,
          userId,
        )

        const {
          data,
          error,
        } = await admin.auth.admin
          .updateUserById(
            userId,
            {
              email,
            },
          )

        if (error) {
          throw new Error(
            'Aggiornamento email Authentication: ' +
            error.message,
          )
        }

        const {
          error:
            anagraficaError,
        } = await admin
          .from('anagrafica')
          .update({
            email_unipa:
              email,
          })
          .eq(
            'user_id',
            userId,
          )

        if (anagraficaError) {
          throw new Error(
            'Email Auth aggiornata, ' +
            'ma anagrafica non sincronizzata: ' +
            anagraficaError.message,
          )
        }

        return jsonResponse({
          ok: true,
          user:
            data.user,
        })
      }

      // ======================================================================
      // CONFIRM EMAIL
      // Solo owner.
      // ======================================================================

      if (action === 'confirm_email') {
        if (caller.role !== 'owner') {
          return jsonResponse(
            {
              error:
                'Solo owner può confermare manualmente una email.',
            },
            403,
          )
        }

        const userId =
          body.user_id
            ?.toString()

        if (!userId) {
          return jsonResponse(
            {
              error:
                'user_id obbligatorio.',
            },
            400,
          )
        }

        const {
          data,
          error,
        } = await admin.auth.admin
          .updateUserById(
            userId,
            {
              email_confirm:
                true,
            },
          )

        if (error) {
          throw new Error(
            `Conferma email: ${error.message}`,
          )
        }

        return jsonResponse({
          ok: true,
          user:
            data.user,
        })
      }

      // ======================================================================
      // ATTIVA / DISATTIVA ACCOUNT
      //
      // Supporta:
      // - set_banned
      // - set_active
      // - ban_user
      // - unban_user
      //
      // Sincronizza:
      // - Supabase Authentication;
      // - anagrafica_riservata.attivo.
      // ======================================================================

      if (
        action === 'set_banned' ||
        action === 'set_active' ||
        action === 'ban_user' ||
        action === 'unban_user'
      ) {
        const userId =
          body.user_id
            ?.toString()

        if (!userId) {
          return jsonResponse(
            {
              error:
                'user_id obbligatorio.',
            },
            400,
          )
        }

        if (
          userId ===
          caller.user.id
        ) {
          return jsonResponse(
            {
              error:
                'Non puoi disabilitare il tuo stesso account.',
            },
            400,
          )
        }

        await verificaPermessoSuUtente(
          caller.role,
          userId,
        )

        let attivo: boolean

        if (action === 'ban_user') {
          attivo = false
        } else if (
          action === 'unban_user'
        ) {
          attivo = true
        } else if (
          action === 'set_banned'
        ) {
          attivo =
            body.banned !== true
        } else {
          attivo =
            body.active === true
        }

        const {
          data,
          error:
            authError,
        } = await admin.auth.admin
          .updateUserById(
            userId,
            {
              ban_duration:
                attivo
                  ? 'none'
                  : '876000h',
            },
          )

        if (authError) {
          throw new Error(
            `Impossibile ${
              attivo
                ? 'riabilitare'
                : 'disabilitare'
            } Authentication: ${
              authError.message
            }`,
          )
        }

        const {
          error:
            riservataError,
        } = await admin
          .from(
            'anagrafica_riservata',
          )
          .upsert(
            {
              user_id:
                userId,

              attivo,
            },
            {
              onConflict:
                'user_id',
            },
          )

        if (riservataError) {
          // rollback Authentication
          await admin.auth.admin
            .updateUserById(
              userId,
              {
                ban_duration:
                  attivo
                    ? '876000h'
                    : 'none',
              },
            )

          throw new Error(
            'Authentication aggiornata, ' +
            'ma impossibile sincronizzare ' +
            'anagrafica_riservata.attivo: ' +
            riservataError.message,
          )
        }

        return jsonResponse({
          ok: true,
          attivo,
          user:
            data.user,
        })
      }

      // ======================================================================
      // DELETE USER
      // Solo owner.
      // ======================================================================

      if (
        action === 'delete_user' ||
        action ===
          'delete_participant'
      ) {
        if (caller.role !== 'owner') {
          return jsonResponse(
            {
              error:
                'Solo owner può eliminare un utente.',
            },
            403,
          )
        }

        const userId =
          body.user_id
            ?.toString()

        if (!userId) {
          return jsonResponse(
            {
              error:
                'user_id obbligatorio.',
            },
            400,
          )
        }

        if (
          userId ===
          caller.user.id
        ) {
          return jsonResponse(
            {
              error:
                'Non puoi eliminare il tuo stesso account.',
            },
            400,
          )
        }

        // Prima Authentication.
        // Eventuali FK possono correttamente impedire la cancellazione.
        const {
          error:
            authDeleteError,
        } = await admin.auth.admin
          .deleteUser(
            userId,
          )

        if (authDeleteError) {
          throw new Error(
            'Impossibile eliminare Authentication: ' +
            authDeleteError.message,
          )
        }

        // Pulizia residua, utile se alcune FK non sono CASCADE.
        await admin
          .from('user_roles')
          .delete()
          .eq(
            'user_id',
            userId,
          )

        await admin
          .from(
            'anagrafica_riservata',
          )
          .delete()
          .eq(
            'user_id',
            userId,
          )

        await admin
          .from('anagrafica')
          .delete()
          .eq(
            'user_id',
            userId,
          )

        return jsonResponse({
          ok: true,
        })
      }

      // ======================================================================
      // IMPORT PARTECIPANTI
      //
      // Solo owner.
      //
      // Legge import_partecipanti e crea:
      // - auth.users;
      // - anagrafica;
      // - anagrafica_riservata;
      // - user_roles;
      // - partecipazioni_annuali.
      // ======================================================================

      if (
        action ===
        'import_participants'
      ) {
        if (caller.role !== 'owner') {
          return jsonResponse(
            {
              error:
                'Solo owner può eseguire l’importazione massiva.',
            },
            403,
          )
        }

        const annoAccademico =
          body.anno_accademico
            ?.toString()
            .trim() ??
          '2026-27'

        // ---------------------------------------------------------------------
        // Verifica anno accademico.
        // ---------------------------------------------------------------------

        const {
          data:
            annoRow,
          error:
            annoError,
        } = await admin
          .from(
            'anni_accademici',
          )
          .select('codice')
          .eq(
            'codice',
            annoAccademico,
          )
          .maybeSingle()

        if (annoError) {
          throw new Error(
            'Verifica anno accademico: ' +
            annoError.message,
          )
        }

        if (!annoRow) {
          return jsonResponse(
            {
              error:
                `Anno accademico ${annoAccademico} inesistente.`,
            },
            400,
          )
        }

        // ---------------------------------------------------------------------
        // Legge righe ancora da importare.
        // ---------------------------------------------------------------------

        const {
          data:
            righe,
          error:
            righeError,
        } = await admin
          .from(
            'import_partecipanti',
          )
          .select()
          .eq(
            'importato',
            false,
          )
          .order('id')

        if (righeError) {
          throw new Error(
            'Lettura import_partecipanti: ' +
            righeError.message,
          )
        }

        if (
          !righe ||
          righe.length === 0
        ) {
          return jsonResponse({
            ok: true,
            totale: 0,
            creati: 0,
            errori: 0,
            dettagli: [],
          })
        }

        let creati = 0
        let errori = 0

        const dettagli:
          Array<
            Record<
              string,
              unknown
            >
          > = []

        for (
          const riga of righe
        ) {
          const email =
            riga.email_unipa
              ?.toString()
              .trim()

          const password =
            riga.password_temporanea
              ?.toString()

          let userId:
            string |
            null = null

          try {
            if (!email) {
              throw new Error(
                'Email mancante.',
              )
            }

            if (
              !password ||
              password.length < 8
            ) {
              throw new Error(
                'Password temporanea non valida: minimo 8 caratteri.',
              )
            }

            if (
              !riga.cognome
                ?.toString()
                .trim()
            ) {
              throw new Error(
                'Cognome mancante.',
              )
            }

            if (
              !riga.nome
                ?.toString()
                .trim()
            ) {
              throw new Error(
                'Nome mancante.',
              )
            }

            // -----------------------------------------------------------------
            // Controlla se l'email esiste già.
            // -----------------------------------------------------------------

            const {
              data:
                emailEsistente,
              error:
                verificaEmailError,
            } = await admin
              .from('anagrafica')
              .select(
                'user_id,email_unipa',
              )
              .ilike(
                'email_unipa',
                email,
              )
              .maybeSingle()

            if (verificaEmailError) {
              throw new Error(
                'Controllo email esistente: ' +
                verificaEmailError.message,
              )
            }

            if (emailEsistente) {
              throw new Error(
                `Email già presente in anagrafica: ${email}`,
              )
            }

            // -----------------------------------------------------------------
            // Authentication
            // -----------------------------------------------------------------

            const {
              data:
                authData,
              error:
                authError,
            } = await admin.auth.admin
              .createUser({
                email,
                password,
                email_confirm:
                  true,
              })

            if (
              authError ||
              !authData.user
            ) {
              throw new Error(
                `Authentication: ${
                  authError?.message ??
                  'impossibile creare utente'
                }`,
              )
            }

            userId =
              authData.user.id

            // -----------------------------------------------------------------
            // Prepara i dati di anagrafica eliminando i campi tecnici della
            // staging.
            // -----------------------------------------------------------------

            const {
              id: _id,

              password_temporanea:
                _password,

              importato:
                _importato,

              user_id:
                _userIdStaging,

              errore:
                _errore,

              created_at:
                _createdAt,

              imported_at:
                _importedAt,

              ...datiAnagrafica
            } = riga

            delete datiAnagrafica.user_id

            // -----------------------------------------------------------------
            // Anagrafica
            // -----------------------------------------------------------------

            const {
              error:
                anagraficaError,
            } = await admin
              .from('anagrafica')
              .insert({
                ...datiAnagrafica,

                user_id:
                  userId,

                email_unipa:
                  email,
              })

            if (anagraficaError) {
              throw new Error(
                `Anagrafica: ${anagraficaError.message}`,
              )
            }

            // -----------------------------------------------------------------
            // Anagrafica riservata
            // -----------------------------------------------------------------

            const {
              error:
                riservataError,
            } = await admin
              .from(
                'anagrafica_riservata',
              )
              .upsert(
                {
                  user_id:
                    userId,

                  attivo:
                    true,
                },
                {
                  onConflict:
                    'user_id',
                },
              )

            if (riservataError) {
              throw new Error(
                'Anagrafica riservata: ' +
                riservataError.message,
              )
            }

            // -----------------------------------------------------------------
            // Ruolo
            // -----------------------------------------------------------------

            const {
              error:
                ruoloError,
            } = await admin
              .from(
                'user_roles',
              )
              .insert({
                user_id:
                  userId,

                role:
                  'participant',
              })

            if (ruoloError) {
              throw new Error(
                `Ruolo: ${ruoloError.message}`,
              )
            }

            // -----------------------------------------------------------------
            // Partecipazione annuale
            // -----------------------------------------------------------------

            const {
              error:
                partecipazioneError,
            } = await admin
              .from(
                'partecipazioni_annuali',
              )
              .upsert(
                {
                  user_id:
                    userId,

                  anno_accademico:
                    annoAccademico,

                  stato:
                    'confermato',

                  confermato_at:
                    new Date()
                      .toISOString(),
                },
                {
                  onConflict:
                    'user_id,anno_accademico',
                },
              )

            if (
              partecipazioneError
            ) {
              throw new Error(
                'Partecipazione annuale: ' +
                partecipazioneError.message,
              )
            }

            // -----------------------------------------------------------------
            // Staging completata
            // -----------------------------------------------------------------

            const {
              error:
                stagingError,
            } = await admin
              .from(
                'import_partecipanti',
              )
              .update({
                importato:
                  true,

                user_id:
                  userId,

                errore:
                  null,

                imported_at:
                  new Date()
                    .toISOString(),
              })
              .eq(
                'id',
                riga.id,
              )

            if (stagingError) {
              throw new Error(
                'Aggiornamento staging: ' +
                stagingError.message,
              )
            }

            creati++

            dettagli.push({
              email,
              stato:
                'creato',
              user_id:
                userId,
            })
          } catch (error) {
            errori++

            const messaggio =
              messaggioErrore(
                error,
              )

            if (userId) {
              await rollbackUtente(
                userId,
              )
            }

            await admin
              .from(
                'import_partecipanti',
              )
              .update({
                importato:
                  false,

                user_id:
                  null,

                errore:
                  messaggio,
              })
              .eq(
                'id',
                riga.id,
              )

            dettagli.push({
              email:
                email ??
                '(email mancante)',

              stato:
                'errore',

              errore:
                messaggio,
            })
          }
        }

        return jsonResponse({
          ok:
            errori === 0,

          totale:
            righe.length,

          creati,

          errori,

          dettagli,
        })
      }

      // ======================================================================
      // IMPORT INSEGNAMENTI
      //
      // Solo owner.
      //
      // Il file di staging usa email_docente come identificatore leggibile.
      //
      // Per ogni riga:
      // 1. trova il docente in anagrafica tramite email;
      // 2. crea l'insegnamento stabile;
      // 3. crea il mentoraggio per l'anno selezionato;
      // 4. salva insegnamento_id e mentoraggio_id nella staging.
      //
      // Campi stabili di insegnamenti:
      // - insegnamento;
      // - semestre;
      // - cfu;
      // - ore;
      // - cds;
      // - anno_erogazione.
      //
      // I dati annuali appartengono invece a mentoraggi.
      // ======================================================================

      if (
        action ===
        'import_insegnamenti'
      ) {
        if (caller.role !== 'owner') {
          return jsonResponse(
            {
              error:
                'Solo owner può eseguire l’importazione massiva degli insegnamenti.',
            },
            403,
          )
        }

        const annoAccademico =
          body.anno_accademico
            ?.toString()
            .trim() ??
          '2026-27'

        // ---------------------------------------------------------------------
        // Verifica esistenza anno accademico.
        // ---------------------------------------------------------------------

        const {
          data:
            annoRow,
          error:
            annoError,
        } = await admin
          .from(
            'anni_accademici',
          )
          .select('codice')
          .eq(
            'codice',
            annoAccademico,
          )
          .maybeSingle()

        if (annoError) {
          throw new Error(
            'Verifica anno accademico: ' +
            annoError.message,
          )
        }

        if (!annoRow) {
          return jsonResponse(
            {
              error:
                `Anno accademico ${annoAccademico} inesistente.`,
            },
            400,
          )
        }

        // ---------------------------------------------------------------------
        // Legge le righe non ancora importate.
        // ---------------------------------------------------------------------

        const {
          data:
            righe,
          error:
            righeError,
        } = await admin
          .from(
            'import_insegnamenti',
          )
          .select()
          .eq(
            'importato',
            false,
          )
          .order('id')

        if (righeError) {
          throw new Error(
            'Lettura import_insegnamenti: ' +
            righeError.message,
          )
        }

        if (
          !righe ||
          righe.length === 0
        ) {
          return jsonResponse({
            ok: true,
            totale: 0,
            creati: 0,
            errori: 0,
            dettagli: [],
          })
        }

        let creati = 0
        let errori = 0

        const dettagli:
          Array<
            Record<
              string,
              unknown
            >
          > = []

        for (
          const riga of righe
        ) {
          const emailDocente =
            riga.email_docente
              ?.toString()
              .trim()

          const nomeInsegnamento =
            riga.insegnamento
              ?.toString()
              .trim()

          let insegnamentoId:
            string |
            null = null

          let mentoraggioId:
            string |
            null = null

          try {
            // -----------------------------------------------------------------
            // Validazione campi obbligatori di insegnamenti.
            // -----------------------------------------------------------------

            if (!emailDocente) {
              throw new Error(
                'Email docente mancante.',
              )
            }

            if (!nomeInsegnamento) {
              throw new Error(
                'Nome insegnamento mancante.',
              )
            }

            if (
              riga.semestre ===
                null ||
              riga.semestre ===
                undefined
            ) {
              throw new Error(
                'Semestre mancante.',
              )
            }

            // -----------------------------------------------------------------
            // Trova docente tramite email.
            // -----------------------------------------------------------------

            const {
              data:
                docente,
              error:
                docenteError,
            } = await admin
              .from('anagrafica')
              .select(
                'user_id,email_unipa',
              )
              .ilike(
                'email_unipa',
                emailDocente,
              )
              .maybeSingle()

            if (docenteError) {
              throw new Error(
                'Ricerca docente: ' +
                docenteError.message,
              )
            }

            if (!docente) {
              throw new Error(
                `Docente non trovato per email: ${emailDocente}`,
              )
            }

            const docenteId =
              docente.user_id
                ?.toString()

            if (!docenteId) {
              throw new Error(
                `user_id mancante per docente ${emailDocente}`,
              )
            }

            // -----------------------------------------------------------------
            // Crea insegnamento.
            // -----------------------------------------------------------------

            const {
              data:
                insegnamentoCreato,
              error:
                insegnamentoError,
            } = await admin
              .from(
                'insegnamenti',
              )
              .insert({
                docente_id:
                  docenteId,

                insegnamento:
                  nomeInsegnamento,

                semestre:
                  riga.semestre,

                cfu:
                  riga.cfu,

                ore:
                  riga.ore,

                cds:
                  riga.cds,

                anno_erogazione:
                  riga.anno_erogazione,
              })
              .select('id')
              .single()

            if (insegnamentoError) {
              // Questo errore è tipico di un vecchio trigger che crea
              // automaticamente mentoraggi senza anno_accademico.
              if (
                insegnamentoError.message
                  .includes(
                    'anno_accademico',
                  ) &&
                insegnamentoError.message
                  .includes(
                    'mentoraggi',
                  )
              ) {
                throw new Error(
                  'Insegnamento: esiste probabilmente un trigger legacy ' +
                  'su insegnamenti che tenta di creare automaticamente ' +
                  'un mentoraggio senza anno_accademico. ' +
                  'Il trigger deve essere rimosso con la nuova struttura.',
                )
              }

              throw new Error(
                'Insegnamento: ' +
                insegnamentoError.message,
              )
            }

            insegnamentoId =
              insegnamentoCreato.id
                ?.toString()

            if (!insegnamentoId) {
              throw new Error(
                'ID insegnamento non restituito.',
              )
            }

            // -----------------------------------------------------------------
            // Crea mentoraggio annuale.
            //
            // anno_accademico è esplicito.
            //
            // Gli altri dati annuali potranno essere compilati dal docente
            // oppure dal backoffice.
            //
            // NOTA:
            // mentoraggi.stato deve avere un DEFAULT nel DB.
            // -----------------------------------------------------------------

            const {
              data:
                mentoraggioCreato,
              error:
                mentoraggioError,
            } = await admin
              .from(
                'mentoraggi',
              )
              .insert({
                insegnamento_id:
                  insegnamentoId,

                anno_accademico:
                  annoAccademico,
              })
              .select('id')
              .single()

            if (mentoraggioError) {
              throw new Error(
                'Mentoraggio: ' +
                mentoraggioError.message,
              )
            }

            mentoraggioId =
              mentoraggioCreato.id
                ?.toString()

            if (!mentoraggioId) {
              throw new Error(
                'ID mentoraggio non restituito.',
              )
            }

            // -----------------------------------------------------------------
            // Aggiorna staging.
            // -----------------------------------------------------------------

            const {
              error:
                stagingError,
            } = await admin
              .from(
                'import_insegnamenti',
              )
              .update({
                importato:
                  true,

                insegnamento_id:
                  insegnamentoId,

                mentoraggio_id:
                  mentoraggioId,

                errore:
                  null,

                imported_at:
                  new Date()
                    .toISOString(),
              })
              .eq(
                'id',
                riga.id,
              )

            if (stagingError) {
              throw new Error(
                'Aggiornamento import_insegnamenti: ' +
                stagingError.message,
              )
            }

            creati++

            dettagli.push({
              email_docente:
                emailDocente,

              insegnamento:
                nomeInsegnamento,

              stato:
                'creato',

              insegnamento_id:
                insegnamentoId,

              mentoraggio_id:
                mentoraggioId,
            })
          } catch (error) {
            errori++

            const messaggio =
              messaggioErrore(
                error,
              )

            // -----------------------------------------------------------------
            // Rollback della singola riga.
            //
            // Se è stato creato il mentoraggio lo eliminiamo prima
            // dell'insegnamento.
            // -----------------------------------------------------------------

            if (mentoraggioId) {
              await admin
                .from(
                  'mentoraggi',
                )
                .delete()
                .eq(
                  'id',
                  mentoraggioId,
                )
            }

            if (insegnamentoId) {
              await admin
                .from(
                  'insegnamenti',
                )
                .delete()
                .eq(
                  'id',
                  insegnamentoId,
                )
            }

            await admin
              .from(
                'import_insegnamenti',
              )
              .update({
                importato:
                  false,

                insegnamento_id:
                  null,

                mentoraggio_id:
                  null,

                errore:
                  messaggio,

                imported_at:
                  null,
              })
              .eq(
                'id',
                riga.id,
              )

            dettagli.push({
              email_docente:
                emailDocente ??
                '(email mancante)',

              insegnamento:
                nomeInsegnamento ??
                '(insegnamento mancante)',

              stato:
                'errore',

              errore:
                messaggio,
            })
          }
        }

        return jsonResponse({
          ok:
            errori === 0,

          totale:
            righe.length,

          creati,

          errori,

          dettagli,
        })
      }

      // ======================================================================
      // AZIONE NON RICONOSCIUTA
      // ======================================================================

      return jsonResponse(
        {
          error:
            `Azione non riconosciuta: ${action}`,
        },
        400,
      )
    } catch (error) {
      const messaggio =
        messaggioErrore(
          error,
        )

      console.error(
        'backoffice-user-admin:',
        error,
      )

      return jsonResponse(
        {
          error:
            messaggio,
        },
        500,
      )
    }
  },
)