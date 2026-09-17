export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      abilitazioni_modifica: {
        Row: {
          abilitata: boolean
          abilitata_at: string | null
          abilitata_da: string | null
          ambito: Database["public"]["Enums"]["ambito_modifica"]
          anno_accademico: string
          revocata_at: string | null
          richiesta_at: string
          scade_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          abilitata?: boolean
          abilitata_at?: string | null
          abilitata_da?: string | null
          ambito: Database["public"]["Enums"]["ambito_modifica"]
          anno_accademico: string
          revocata_at?: string | null
          richiesta_at?: string
          scade_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          abilitata?: boolean
          abilitata_at?: string | null
          abilitata_da?: string | null
          ambito?: Database["public"]["Enums"]["ambito_modifica"]
          anno_accademico?: string
          revocata_at?: string | null
          richiesta_at?: string
          scade_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "abilitazioni_modifica_anno_accademico_fkey"
            columns: ["anno_accademico"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
          {
            foreignKeyName: "abilitazioni_modifica_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "anagrafica"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "abilitazioni_modifica_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "notifiche_utenti_attivi"
            referencedColumns: ["user_id"]
          },
        ]
      }
      anagrafica: {
        Row: {
          anno_prima_partecipazione: string | null
          cellulare: string | null
          cod_ssd: string | null
          cognome: string
          created_at: string
          dipartimento: string | null
          email_unipa: string
          fascia_eta: Database["public"]["Enums"]["fascia_eta"] | null
          nome: string
          pagina_personale_unipa: string | null
          ruolo_accademico:
            | Database["public"]["Enums"]["ruolo_accademico"]
            | null
          ufficio: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          anno_prima_partecipazione?: string | null
          cellulare?: string | null
          cod_ssd?: string | null
          cognome: string
          created_at?: string
          dipartimento?: string | null
          email_unipa: string
          fascia_eta?: Database["public"]["Enums"]["fascia_eta"] | null
          nome: string
          pagina_personale_unipa?: string | null
          ruolo_accademico?:
            | Database["public"]["Enums"]["ruolo_accademico"]
            | null
          ufficio?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          anno_prima_partecipazione?: string | null
          cellulare?: string | null
          cod_ssd?: string | null
          cognome?: string
          created_at?: string
          dipartimento?: string | null
          email_unipa?: string
          fascia_eta?: Database["public"]["Enums"]["fascia_eta"] | null
          nome?: string
          pagina_personale_unipa?: string | null
          ruolo_accademico?:
            | Database["public"]["Enums"]["ruolo_accademico"]
            | null
          ufficio?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "anagrafica_anno_prima_partecipazione_fkey"
            columns: ["anno_prima_partecipazione"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
          {
            foreignKeyName: "anagrafica_cod_ssd_fkey"
            columns: ["cod_ssd"]
            isOneToOne: false
            referencedRelation: "ssd"
            referencedColumns: ["cod_ssd"]
          },
        ]
      }
      anagrafica_riservata: {
        Row: {
          attivo: boolean
          note_storiche: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          attivo?: boolean
          note_storiche?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          attivo?: boolean
          note_storiche?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "anagrafica_riservata_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "anagrafica"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "anagrafica_riservata_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "notifiche_utenti_attivi"
            referencedColumns: ["user_id"]
          },
        ]
      }
      anni_accademici: {
        Row: {
          codice: string
          corrente: boolean
          data_fine: string | null
          data_inizio: string | null
          stato: string
          updated_at: string
        }
        Insert: {
          codice: string
          corrente?: boolean
          data_fine?: string | null
          data_inizio?: string | null
          stato?: string
          updated_at?: string
        }
        Update: {
          codice?: string
          corrente?: boolean
          data_fine?: string | null
          data_inizio?: string | null
          stato?: string
          updated_at?: string
        }
        Relationships: []
      }
      eventi: {
        Row: {
          anno_accademico: string
          attiva: boolean | null
          created_at: string
          data_apertura_iscrizioni: string | null
          data_chiusura_iscrizioni: string | null
          data_evento: string
          descrizione: string | null
          id: string
          locandina_url: string | null
          luogo: string | null
          modalita: Database["public"]["Enums"]["modalita_svolgimento"]
          moderatori: string | null
          note_organizzative: string | null
          relatori: string | null
          tipologia: Database["public"]["Enums"]["tipologia_evento"]
          titolo: string
          updated_at: string
        }
        Insert: {
          anno_accademico: string
          attiva?: boolean | null
          created_at?: string
          data_apertura_iscrizioni?: string | null
          data_chiusura_iscrizioni?: string | null
          data_evento: string
          descrizione?: string | null
          id?: string
          locandina_url?: string | null
          luogo?: string | null
          modalita: Database["public"]["Enums"]["modalita_svolgimento"]
          moderatori?: string | null
          note_organizzative?: string | null
          relatori?: string | null
          tipologia: Database["public"]["Enums"]["tipologia_evento"]
          titolo: string
          updated_at?: string
        }
        Update: {
          anno_accademico?: string
          attiva?: boolean | null
          created_at?: string
          data_apertura_iscrizioni?: string | null
          data_chiusura_iscrizioni?: string | null
          data_evento?: string
          descrizione?: string | null
          id?: string
          locandina_url?: string | null
          luogo?: string | null
          modalita?: Database["public"]["Enums"]["modalita_svolgimento"]
          moderatori?: string | null
          note_organizzative?: string | null
          relatori?: string | null
          tipologia?: Database["public"]["Enums"]["tipologia_evento"]
          titolo?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "eventi_anno_accademico_fkey"
            columns: ["anno_accademico"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
        ]
      }
      house_of_mentore: {
        Row: {
          anno_accademico: string
          attiva: boolean
          created_at: string
          data_evento: string | null
          descrizione: string | null
          id: string
          iscrizioni_aperte: boolean
          locandina_url: string | null
          luogo: string | null
          titolo: string
          updated_at: string
        }
        Insert: {
          anno_accademico: string
          attiva?: boolean
          created_at?: string
          data_evento?: string | null
          descrizione?: string | null
          id?: string
          iscrizioni_aperte?: boolean
          locandina_url?: string | null
          luogo?: string | null
          titolo: string
          updated_at?: string
        }
        Update: {
          anno_accademico?: string
          attiva?: boolean
          created_at?: string
          data_evento?: string | null
          descrizione?: string | null
          id?: string
          iscrizioni_aperte?: boolean
          locandina_url?: string | null
          luogo?: string | null
          titolo?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "house_of_mentore_anno_accademico_fkey"
            columns: ["anno_accademico"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
        ]
      }
      house_of_mentore_opzioni: {
        Row: {
          descrizione: string
          evento_id: string
          id: string
          ordine_visualizzazione: number
          updated_at: string
        }
        Insert: {
          descrizione: string
          evento_id: string
          id?: string
          ordine_visualizzazione?: number
          updated_at?: string
        }
        Update: {
          descrizione?: string
          evento_id?: string
          id?: string
          ordine_visualizzazione?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "house_of_mentore_opzioni_evento_id_fkey"
            columns: ["evento_id"]
            isOneToOne: false
            referencedRelation: "house_of_mentore"
            referencedColumns: ["id"]
          },
        ]
      }
      import_insegnamenti: {
        Row: {
          anno_erogazione: Database["public"]["Enums"]["anno_erogazione"] | null
          cds: string | null
          cfu: number | null
          created_at: string
          email_docente: string
          errore: string | null
          id: number
          importato: boolean
          imported_at: string | null
          insegnamento: string
          insegnamento_id: string | null
          mentoraggio_id: string | null
          ore: number | null
          semestre: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at: string
        }
        Insert: {
          anno_erogazione?:
            | Database["public"]["Enums"]["anno_erogazione"]
            | null
          cds?: string | null
          cfu?: number | null
          created_at?: string
          email_docente: string
          errore?: string | null
          id?: never
          importato?: boolean
          imported_at?: string | null
          insegnamento: string
          insegnamento_id?: string | null
          mentoraggio_id?: string | null
          ore?: number | null
          semestre: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at?: string
        }
        Update: {
          anno_erogazione?:
            | Database["public"]["Enums"]["anno_erogazione"]
            | null
          cds?: string | null
          cfu?: number | null
          created_at?: string
          email_docente?: string
          errore?: string | null
          id?: never
          importato?: boolean
          imported_at?: string | null
          insegnamento?: string
          insegnamento_id?: string | null
          mentoraggio_id?: string | null
          ore?: number | null
          semestre?: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at?: string
        }
        Relationships: []
      }
      import_partecipanti: {
        Row: {
          cellulare: string | null
          cognome: string | null
          created_at: string
          dipartimento: string | null
          email_unipa: string
          errore: string | null
          fascia_eta: Database["public"]["Enums"]["fascia_eta"] | null
          id: number
          importato: boolean
          imported_at: string | null
          nome: string | null
          password_temporanea: string
          ruolo_accademico:
            | Database["public"]["Enums"]["ruolo_accademico"]
            | null
          ufficio: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          cellulare?: string | null
          cognome?: string | null
          created_at?: string
          dipartimento?: string | null
          email_unipa: string
          errore?: string | null
          fascia_eta?: Database["public"]["Enums"]["fascia_eta"] | null
          id?: never
          importato?: boolean
          imported_at?: string | null
          nome?: string | null
          password_temporanea: string
          ruolo_accademico?:
            | Database["public"]["Enums"]["ruolo_accademico"]
            | null
          ufficio?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          cellulare?: string | null
          cognome?: string | null
          created_at?: string
          dipartimento?: string | null
          email_unipa?: string
          errore?: string | null
          fascia_eta?: Database["public"]["Enums"]["fascia_eta"] | null
          id?: never
          importato?: boolean
          imported_at?: string | null
          nome?: string | null
          password_temporanea?: string
          ruolo_accademico?:
            | Database["public"]["Enums"]["ruolo_accademico"]
            | null
          ufficio?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      insegnamenti: {
        Row: {
          anno_erogazione: Database["public"]["Enums"]["anno_erogazione"] | null
          cds: string | null
          cfu: number | null
          created_at: string
          docente_id: string
          id: string
          insegnamento: string
          ore: number | null
          semestre: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at: string
        }
        Insert: {
          anno_erogazione?:
            | Database["public"]["Enums"]["anno_erogazione"]
            | null
          cds?: string | null
          cfu?: number | null
          created_at?: string
          docente_id: string
          id?: string
          insegnamento: string
          ore?: number | null
          semestre: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at?: string
        }
        Update: {
          anno_erogazione?:
            | Database["public"]["Enums"]["anno_erogazione"]
            | null
          cds?: string | null
          cfu?: number | null
          created_at?: string
          docente_id?: string
          id?: string
          insegnamento?: string
          ore?: number | null
          semestre?: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "insegnamenti_docente_id_fkey"
            columns: ["docente_id"]
            isOneToOne: false
            referencedRelation: "anagrafica"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "insegnamenti_docente_id_fkey"
            columns: ["docente_id"]
            isOneToOne: false
            referencedRelation: "notifiche_utenti_attivi"
            referencedColumns: ["user_id"]
          },
        ]
      }
      mentoraggi: {
        Row: {
          anno_accademico: string
          azioni_miglioramento: string | null
          created_at: string
          data_fine: string | null
          data_focus_group: string | null
          data_incontro_finale: string | null
          data_inizio: string | null
          data_invio_scheda: string | null
          data_visita_1: string | null
          data_visita_2: string | null
          data_visita_3: string | null
          data_visita_4: string | null
          giorni_orari_lezioni: string | null
          id: string
          insegnamento_id: string
          link_questionario: string | null
          note: string | null
          numero_studenti: number | null
          osservazioni_aula: string | null
          osservazioni_focus_group: string | null
          scheda_sintesi: string | null
          scheda_sintesi_pdf_url: string | null
          sede: string | null
          stato: Database["public"]["Enums"]["stato_mentoraggio"]
          svolgimento:
            | Database["public"]["Enums"]["modalita_svolgimento"]
            | null
          updated_at: string
        }
        Insert: {
          anno_accademico: string
          azioni_miglioramento?: string | null
          created_at?: string
          data_fine?: string | null
          data_focus_group?: string | null
          data_incontro_finale?: string | null
          data_inizio?: string | null
          data_invio_scheda?: string | null
          data_visita_1?: string | null
          data_visita_2?: string | null
          data_visita_3?: string | null
          data_visita_4?: string | null
          giorni_orari_lezioni?: string | null
          id?: string
          insegnamento_id: string
          link_questionario?: string | null
          note?: string | null
          numero_studenti?: number | null
          osservazioni_aula?: string | null
          osservazioni_focus_group?: string | null
          scheda_sintesi?: string | null
          scheda_sintesi_pdf_url?: string | null
          sede?: string | null
          stato?: Database["public"]["Enums"]["stato_mentoraggio"]
          svolgimento?:
            | Database["public"]["Enums"]["modalita_svolgimento"]
            | null
          updated_at?: string
        }
        Update: {
          anno_accademico?: string
          azioni_miglioramento?: string | null
          created_at?: string
          data_fine?: string | null
          data_focus_group?: string | null
          data_incontro_finale?: string | null
          data_inizio?: string | null
          data_invio_scheda?: string | null
          data_visita_1?: string | null
          data_visita_2?: string | null
          data_visita_3?: string | null
          data_visita_4?: string | null
          giorni_orari_lezioni?: string | null
          id?: string
          insegnamento_id?: string
          link_questionario?: string | null
          note?: string | null
          numero_studenti?: number | null
          osservazioni_aula?: string | null
          osservazioni_focus_group?: string | null
          scheda_sintesi?: string | null
          scheda_sintesi_pdf_url?: string | null
          sede?: string | null
          stato?: Database["public"]["Enums"]["stato_mentoraggio"]
          svolgimento?:
            | Database["public"]["Enums"]["modalita_svolgimento"]
            | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "mentoraggi_anno_accademico_fk"
            columns: ["anno_accademico"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
          {
            foreignKeyName: "mentoraggi_insegnamento_id_fkey"
            columns: ["insegnamento_id"]
            isOneToOne: false
            referencedRelation: "insegnamenti"
            referencedColumns: ["id"]
          },
        ]
      }
      mentoraggio_mentori: {
        Row: {
          assegnato_il: string
          mentoraggio_id: string
          mentore_id: string
          tipo: Database["public"]["Enums"]["tipo_mentore"]
          updated_at: string
        }
        Insert: {
          assegnato_il?: string
          mentoraggio_id: string
          mentore_id: string
          tipo?: Database["public"]["Enums"]["tipo_mentore"]
          updated_at?: string
        }
        Update: {
          assegnato_il?: string
          mentoraggio_id?: string
          mentore_id?: string
          tipo?: Database["public"]["Enums"]["tipo_mentore"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "mentoraggio_mentori_mentoraggio_id_fkey"
            columns: ["mentoraggio_id"]
            isOneToOne: false
            referencedRelation: "mentoraggi"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mentoraggio_mentori_mentoraggio_id_fkey"
            columns: ["mentoraggio_id"]
            isOneToOne: false
            referencedRelation: "mentoraggi_google_sheet"
            referencedColumns: ["mentoraggio_id"]
          },
          {
            foreignKeyName: "mentoraggio_mentori_mentore_id_fkey"
            columns: ["mentore_id"]
            isOneToOne: false
            referencedRelation: "anagrafica"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "mentoraggio_mentori_mentore_id_fkey"
            columns: ["mentore_id"]
            isOneToOne: false
            referencedRelation: "notifiche_utenti_attivi"
            referencedColumns: ["user_id"]
          },
        ]
      }
      news: {
        Row: {
          attiva: boolean | null
          created_at: string | null
          data_pubblicazione: string | null
          id: number
          testo: string | null
          titolo: string
          updated_at: string
        }
        Insert: {
          attiva?: boolean | null
          created_at?: string | null
          data_pubblicazione?: string | null
          id?: never
          testo?: string | null
          titolo: string
          updated_at?: string
        }
        Update: {
          attiva?: boolean | null
          created_at?: string | null
          data_pubblicazione?: string | null
          id?: never
          testo?: string | null
          titolo?: string
          updated_at?: string
        }
        Relationships: []
      }
      notifiche_destinatari: {
        Row: {
          created_at: string
          errore: string | null
          id: string
          inviato_at: string | null
          letto_at: string | null
          messaggio_id: string
          stato: Database["public"]["Enums"]["notifiche_stato_destinatario"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          errore?: string | null
          id?: string
          inviato_at?: string | null
          letto_at?: string | null
          messaggio_id: string
          stato?: Database["public"]["Enums"]["notifiche_stato_destinatario"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          errore?: string | null
          id?: string
          inviato_at?: string | null
          letto_at?: string | null
          messaggio_id?: string
          stato?: Database["public"]["Enums"]["notifiche_stato_destinatario"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifiche_destinatari_messaggio_fk"
            columns: ["messaggio_id"]
            isOneToOne: false
            referencedRelation: "notifiche_messaggi"
            referencedColumns: ["id"]
          },
        ]
      }
      notifiche_dispositivi: {
        Row: {
          attivo: boolean
          created_at: string
          id: string
          piattaforma: Database["public"]["Enums"]["notifiche_piattaforma"]
          token: string
          ultimo_accesso: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          attivo?: boolean
          created_at?: string
          id?: string
          piattaforma: Database["public"]["Enums"]["notifiche_piattaforma"]
          token: string
          ultimo_accesso?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          attivo?: boolean
          created_at?: string
          id?: string
          piattaforma?: Database["public"]["Enums"]["notifiche_piattaforma"]
          token?: string
          ultimo_accesso?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      notifiche_messaggi: {
        Row: {
          anno_accademico: string
          chiave_univoca: string | null
          creata_da: string | null
          created_at: string
          destinatari: Database["public"]["Enums"]["notifiche_tipo_destinatari"]
          destinatari_configurazione: Json
          id: string
          inviata_at: string | null
          messaggio: string
          origine_id: string | null
          origine_tabella: string | null
          programmata_per: string | null
          regola_id: string | null
          stato: Database["public"]["Enums"]["notifiche_stato_messaggio"]
          titolo: string
          updated_at: string
        }
        Insert: {
          anno_accademico?: string
          chiave_univoca?: string | null
          creata_da?: string | null
          created_at?: string
          destinatari: Database["public"]["Enums"]["notifiche_tipo_destinatari"]
          destinatari_configurazione?: Json
          id?: string
          inviata_at?: string | null
          messaggio: string
          origine_id?: string | null
          origine_tabella?: string | null
          programmata_per?: string | null
          regola_id?: string | null
          stato?: Database["public"]["Enums"]["notifiche_stato_messaggio"]
          titolo: string
          updated_at?: string
        }
        Update: {
          anno_accademico?: string
          chiave_univoca?: string | null
          creata_da?: string | null
          created_at?: string
          destinatari?: Database["public"]["Enums"]["notifiche_tipo_destinatari"]
          destinatari_configurazione?: Json
          id?: string
          inviata_at?: string | null
          messaggio?: string
          origine_id?: string | null
          origine_tabella?: string | null
          programmata_per?: string | null
          regola_id?: string | null
          stato?: Database["public"]["Enums"]["notifiche_stato_messaggio"]
          titolo?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifiche_messaggi_anno_fk"
            columns: ["anno_accademico"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
          {
            foreignKeyName: "notifiche_messaggi_regola_fk"
            columns: ["regola_id"]
            isOneToOne: false
            referencedRelation: "notifiche_regole"
            referencedColumns: ["id"]
          },
        ]
      }
      notifiche_regole: {
        Row: {
          attiva: boolean
          campo_data: string | null
          codice: string
          configurazione: Json
          created_at: string
          data_programmata: string | null
          descrizione: string
          destinatari: Database["public"]["Enums"]["notifiche_tipo_destinatari"]
          id: string
          messaggio_template: string
          offset_giorni: number
          tabella: string
          tipo_attivazione: Database["public"]["Enums"]["notifiche_tipo_attivazione"]
          titolo_template: string
          updated_at: string
        }
        Insert: {
          attiva?: boolean
          campo_data?: string | null
          codice: string
          configurazione?: Json
          created_at?: string
          data_programmata?: string | null
          descrizione: string
          destinatari: Database["public"]["Enums"]["notifiche_tipo_destinatari"]
          id?: string
          messaggio_template: string
          offset_giorni?: number
          tabella: string
          tipo_attivazione: Database["public"]["Enums"]["notifiche_tipo_attivazione"]
          titolo_template: string
          updated_at?: string
        }
        Update: {
          attiva?: boolean
          campo_data?: string | null
          codice?: string
          configurazione?: Json
          created_at?: string
          data_programmata?: string | null
          descrizione?: string
          destinatari?: Database["public"]["Enums"]["notifiche_tipo_destinatari"]
          id?: string
          messaggio_template?: string
          offset_giorni?: number
          tabella?: string
          tipo_attivazione?: Database["public"]["Enums"]["notifiche_tipo_attivazione"]
          titolo_template?: string
          updated_at?: string
        }
        Relationships: []
      }
      partecipazioni_annuali: {
        Row: {
          aggiornato_da: string | null
          anno_accademico: string
          cambiare_mentee_seguiti: string | null
          cambiare_mentore: boolean | null
          confermato_at: string | null
          confermato_da: string | null
          created_at: string
          disponibile_mentoring_esami: boolean | null
          note: string | null
          note_attivita_mentore: string | null
          note_sui_mentori: string | null
          preferenza_periodo_mentore:
            | Database["public"]["Enums"]["preferenza_periodo_mentore_enum"]
            | null
          richiesta_at: string
          risposta_at: string | null
          segnalazioni_suggerimenti: string | null
          solo_mentore: boolean
          stato: Database["public"]["Enums"]["stato_partecipazione_annuale"]
          updated_at: string
          user_id: string
          valutazione_mentori_precedenti: number | null
        }
        Insert: {
          aggiornato_da?: string | null
          anno_accademico: string
          cambiare_mentee_seguiti?: string | null
          cambiare_mentore?: boolean | null
          confermato_at?: string | null
          confermato_da?: string | null
          created_at?: string
          disponibile_mentoring_esami?: boolean | null
          note?: string | null
          note_attivita_mentore?: string | null
          note_sui_mentori?: string | null
          preferenza_periodo_mentore?:
            | Database["public"]["Enums"]["preferenza_periodo_mentore_enum"]
            | null
          richiesta_at?: string
          risposta_at?: string | null
          segnalazioni_suggerimenti?: string | null
          solo_mentore?: boolean
          stato?: Database["public"]["Enums"]["stato_partecipazione_annuale"]
          updated_at?: string
          user_id: string
          valutazione_mentori_precedenti?: number | null
        }
        Update: {
          aggiornato_da?: string | null
          anno_accademico?: string
          cambiare_mentee_seguiti?: string | null
          cambiare_mentore?: boolean | null
          confermato_at?: string | null
          confermato_da?: string | null
          created_at?: string
          disponibile_mentoring_esami?: boolean | null
          note?: string | null
          note_attivita_mentore?: string | null
          note_sui_mentori?: string | null
          preferenza_periodo_mentore?:
            | Database["public"]["Enums"]["preferenza_periodo_mentore_enum"]
            | null
          richiesta_at?: string
          risposta_at?: string | null
          segnalazioni_suggerimenti?: string | null
          solo_mentore?: boolean
          stato?: Database["public"]["Enums"]["stato_partecipazione_annuale"]
          updated_at?: string
          user_id?: string
          valutazione_mentori_precedenti?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "partecipazioni_annuali_anno_accademico_fkey"
            columns: ["anno_accademico"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
          {
            foreignKeyName: "partecipazioni_annuali_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "anagrafica"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "partecipazioni_annuali_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "notifiche_utenti_attivi"
            referencedColumns: ["user_id"]
          },
        ]
      }
      partecipazioni_eventi: {
        Row: {
          data_iscrizione: string
          evento_id: string
          partecipante_id: string
          presente: boolean
          presente_impostato_at: string | null
          presente_impostato_da: string | null
          updated_at: string
        }
        Insert: {
          data_iscrizione?: string
          evento_id: string
          partecipante_id: string
          presente?: boolean
          presente_impostato_at?: string | null
          presente_impostato_da?: string | null
          updated_at?: string
        }
        Update: {
          data_iscrizione?: string
          evento_id?: string
          partecipante_id?: string
          presente?: boolean
          presente_impostato_at?: string | null
          presente_impostato_da?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "partecipazioni_eventi_evento_id_fkey"
            columns: ["evento_id"]
            isOneToOne: false
            referencedRelation: "eventi"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partecipazioni_eventi_partecipante_id_fkey"
            columns: ["partecipante_id"]
            isOneToOne: false
            referencedRelation: "anagrafica"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "partecipazioni_eventi_partecipante_id_fkey"
            columns: ["partecipante_id"]
            isOneToOne: false
            referencedRelation: "notifiche_utenti_attivi"
            referencedColumns: ["user_id"]
          },
        ]
      }
      partecipazioni_house_of_mentore: {
        Row: {
          data_iscrizione: string
          evento_id: string
          opzione_id: string
          partecipante_id: string
          presente: boolean | null
          updated_at: string
        }
        Insert: {
          data_iscrizione?: string
          evento_id: string
          opzione_id: string
          partecipante_id: string
          presente?: boolean | null
          updated_at?: string
        }
        Update: {
          data_iscrizione?: string
          evento_id?: string
          opzione_id?: string
          partecipante_id?: string
          presente?: boolean | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "partecipazioni_house_of_mentore_evento_id_fkey"
            columns: ["evento_id"]
            isOneToOne: false
            referencedRelation: "house_of_mentore"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partecipazioni_house_of_mentore_partecipante_id_fkey"
            columns: ["partecipante_id"]
            isOneToOne: false
            referencedRelation: "anagrafica"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "partecipazioni_house_of_mentore_partecipante_id_fkey"
            columns: ["partecipante_id"]
            isOneToOne: false
            referencedRelation: "notifiche_utenti_attivi"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "partecipazioni_house_opzione_evento_fk"
            columns: ["opzione_id", "evento_id"]
            isOneToOne: false
            referencedRelation: "house_of_mentore_opzioni"
            referencedColumns: ["id", "evento_id"]
          },
        ]
      }
      questionari: {
        Row: {
          aperto: boolean
          created_at: string
          created_by: string | null
          data_apertura: string | null
          data_chiusura: string | null
          evento_id: string | null
          id: string
          mentoraggio_id: string | null
          provider: Database["public"]["Enums"]["questionario_provider"]
          pubblico_token: string | null
          template_id: string
          titolo: string
          token_pubblico: string | null
          updated_at: string
          url_esterno: string | null
        }
        Insert: {
          aperto?: boolean
          created_at?: string
          created_by?: string | null
          data_apertura?: string | null
          data_chiusura?: string | null
          evento_id?: string | null
          id?: string
          mentoraggio_id?: string | null
          provider: Database["public"]["Enums"]["questionario_provider"]
          pubblico_token?: string | null
          template_id: string
          titolo: string
          token_pubblico?: string | null
          updated_at?: string
          url_esterno?: string | null
        }
        Update: {
          aperto?: boolean
          created_at?: string
          created_by?: string | null
          data_apertura?: string | null
          data_chiusura?: string | null
          evento_id?: string | null
          id?: string
          mentoraggio_id?: string | null
          provider?: Database["public"]["Enums"]["questionario_provider"]
          pubblico_token?: string | null
          template_id?: string
          titolo?: string
          token_pubblico?: string | null
          updated_at?: string
          url_esterno?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "questionari_evento_id_fkey"
            columns: ["evento_id"]
            isOneToOne: false
            referencedRelation: "eventi"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questionari_mentoraggio_id_fkey"
            columns: ["mentoraggio_id"]
            isOneToOne: false
            referencedRelation: "mentoraggi"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questionari_mentoraggio_id_fkey"
            columns: ["mentoraggio_id"]
            isOneToOne: false
            referencedRelation: "mentoraggi_google_sheet"
            referencedColumns: ["mentoraggio_id"]
          },
          {
            foreignKeyName: "questionari_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "questionari_template"
            referencedColumns: ["id"]
          },
        ]
      }
      questionari_compilazioni: {
        Row: {
          id: string
          inviato_at: string
          questionario_id: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          id?: string
          inviato_at?: string
          questionario_id: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          id?: string
          inviato_at?: string
          questionario_id?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "questionari_compilazioni_questionario_id_fkey"
            columns: ["questionario_id"]
            isOneToOne: false
            referencedRelation: "questionari"
            referencedColumns: ["id"]
          },
        ]
      }
      questionari_domande: {
        Row: {
          created_at: string
          id: string
          obbligatoria: boolean
          opzioni: Json | null
          ordine: number
          template_id: string
          testo: string
          tipo: Database["public"]["Enums"]["questionario_tipo_domanda"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          obbligatoria?: boolean
          opzioni?: Json | null
          ordine: number
          template_id: string
          testo: string
          tipo: Database["public"]["Enums"]["questionario_tipo_domanda"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          obbligatoria?: boolean
          opzioni?: Json | null
          ordine?: number
          template_id?: string
          testo?: string
          tipo?: Database["public"]["Enums"]["questionario_tipo_domanda"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "questionari_domande_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "questionari_template"
            referencedColumns: ["id"]
          },
        ]
      }
      questionari_risposte: {
        Row: {
          compilazione_id: string
          domanda_id: string
          id: string
          updated_at: string
          valore: Json | null
        }
        Insert: {
          compilazione_id: string
          domanda_id: string
          id?: string
          updated_at?: string
          valore?: Json | null
        }
        Update: {
          compilazione_id?: string
          domanda_id?: string
          id?: string
          updated_at?: string
          valore?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "questionari_risposte_compilazione_id_fkey"
            columns: ["compilazione_id"]
            isOneToOne: false
            referencedRelation: "questionari_compilazioni"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questionari_risposte_domanda_id_fkey"
            columns: ["domanda_id"]
            isOneToOne: false
            referencedRelation: "questionari_domande"
            referencedColumns: ["id"]
          },
        ]
      }
      questionari_template: {
        Row: {
          attivo: boolean
          created_at: string
          created_by: string | null
          descrizione: string | null
          destinatario: Database["public"]["Enums"]["questionario_destinatario"]
          id: string
          predefinito: boolean
          titolo: string
          updated_at: string
          versione: number
        }
        Insert: {
          attivo?: boolean
          created_at?: string
          created_by?: string | null
          descrizione?: string | null
          destinatario: Database["public"]["Enums"]["questionario_destinatario"]
          id?: string
          predefinito?: boolean
          titolo: string
          updated_at?: string
          versione?: number
        }
        Update: {
          attivo?: boolean
          created_at?: string
          created_by?: string | null
          descrizione?: string | null
          destinatario?: Database["public"]["Enums"]["questionario_destinatario"]
          id?: string
          predefinito?: boolean
          titolo?: string
          updated_at?: string
          versione?: number
        }
        Relationships: []
      }
      risorse_mentoring: {
        Row: {
          anno_accademico: string | null
          attivo: boolean
          categoria: string
          created_at: string
          descrizione: string | null
          dimensione_bytes: number | null
          id: string
          nome_file: string
          ordine: number
          storage_path: string
          titolo: string
          updated_at: string
          uploaded_by: string | null
        }
        Insert: {
          anno_accademico?: string | null
          attivo?: boolean
          categoria: string
          created_at?: string
          descrizione?: string | null
          dimensione_bytes?: number | null
          id?: string
          nome_file: string
          ordine?: number
          storage_path: string
          titolo: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Update: {
          anno_accademico?: string | null
          attivo?: boolean
          categoria?: string
          created_at?: string
          descrizione?: string | null
          dimensione_bytes?: number | null
          id?: string
          nome_file?: string
          ordine?: number
          storage_path?: string
          titolo?: string
          updated_at?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "risorse_mentoring_anno_accademico_fkey"
            columns: ["anno_accademico"]
            isOneToOne: false
            referencedRelation: "anni_accademici"
            referencedColumns: ["codice"]
          },
        ]
      }
      ssd: {
        Row: {
          area: string
          cod_ssd: string
          gsd: string
          updated_at: string
        }
        Insert: {
          area: string
          cod_ssd: string
          gsd: string
          updated_at?: string
        }
        Update: {
          area?: string
          cod_ssd?: string
          gsd?: string
          updated_at?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
          user_id: string
        }
        Insert: {
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
          user_id: string
        }
        Update: {
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      utente_ultimi_accessi: {
        Row: {
          percorso: string
          ultimo_accesso: string
          user_id: string
        }
        Insert: {
          percorso: string
          ultimo_accesso?: string
          user_id: string
        }
        Update: {
          percorso?: string
          ultimo_accesso?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      mentoraggi_google_sheet: {
        Row: {
          data_focus_group: string | null
          data_incontro_finale: string | null
          data_invio_scheda: string | null
          data_visita_1: string | null
          data_visita_2: string | null
          email_unipa: string | null
          mentoraggio_id: string | null
        }
        Relationships: []
      }
      notifiche_utenti_attivi: {
        Row: {
          cognome: string | null
          email_unipa: string | null
          nome: string | null
          role: Database["public"]["Enums"]["app_role"] | null
          user_id: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      abilitazione_modifica_imposta: {
        Args: {
          p_abilitata: boolean
          p_ambito: Database["public"]["Enums"]["ambito_modifica"]
          p_anno_accademico: string
          p_scade_at?: string
          p_user_id: string
        }
        Returns: undefined
      }
      anagrafica_e_attiva: { Args: { p_user_id: string }; Returns: boolean }
      anno_accademico_attivo: { Args: never; Returns: string }
      anno_accademico_corrente: { Args: never; Returns: string }
      anno_accademico_gestione_insegnamenti: { Args: never; Returns: string }
      anno_accademico_preparazione: { Args: never; Returns: string }
      app_backoffice_admin: { Args: { p_user_id?: string }; Returns: boolean }
      app_database_schema: { Args: never; Returns: Json }
      app_is_owner: { Args: never; Returns: boolean }
      app_owner: { Args: { p_user_id?: string }; Returns: boolean }
      has_role: {
        Args: { allowed_roles: Database["public"]["Enums"]["app_role"][] }
        Returns: boolean
      }
      imposta_anno_accademico_corrente:
        | {
            Args: { p_codice: string }
            Returns: {
              error: true
            } & "Could not choose the best candidate function between: public.imposta_anno_accademico_corrente(p_codice => text), public.imposta_anno_accademico_corrente(p_codice => varchar). Try renaming the parameters or the function itself in the database so function overloading can be resolved"
          }
        | {
            Args: { p_codice: string }
            Returns: {
              error: true
            } & "Could not choose the best candidate function between: public.imposta_anno_accademico_corrente(p_codice => text), public.imposta_anno_accademico_corrente(p_codice => varchar). Try renaming the parameters or the function itself in the database so function overloading can be resolved"
          }
      imposta_stato_anno_accademico: {
        Args: { p_codice: string; p_stato: string }
        Returns: undefined
      }
      insegnamenti_miei: {
        Args: never
        Returns: {
          anno_erogazione: Database["public"]["Enums"]["anno_erogazione"] | null
          cds: string | null
          cfu: number | null
          created_at: string
          docente_id: string
          id: string
          insegnamento: string
          ore: number | null
          semestre: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "insegnamenti"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      insegnamento_crea_per_anno: {
        Args: { p_anno_accademico?: string; p_valori: Json }
        Returns: Json
      }
      insegnamento_modifica_autorizzata: {
        Args: {
          p_anno_accademico?: string
          p_insegnamento_id: string
          p_valori: Json
        }
        Returns: {
          anno_erogazione: Database["public"]["Enums"]["anno_erogazione"] | null
          cds: string | null
          cfu: number | null
          created_at: string
          docente_id: string
          id: string
          insegnamento: string
          ore: number | null
          semestre: Database["public"]["Enums"]["semestre_erogazione"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "insegnamenti"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      insegnamento_seleziona_per_anno: {
        Args: { p_anno_accademico?: string; p_insegnamento_id: string }
        Returns: Json
      }
      insegnamento_stato_annuale: {
        Args: { p_anno_accademico?: string }
        Returns: Json
      }
      is_docente_del_mentoraggio: {
        Args: { p_mentoraggio_id: string }
        Returns: boolean
      }
      is_mentore_assegnato: {
        Args: { p_mentoraggio_id: string }
        Returns: boolean
      }
      is_mentore_di_insegnamento: {
        Args: { p_insegnamento_id: string }
        Returns: boolean
      }
      mentoraggi_del_mentee: { Args: never; Returns: Json[] }
      mentoraggi_del_mentore: {
        Args: never
        Returns: {
          anno_accademico: string
          azioni_miglioramento: string | null
          created_at: string
          data_fine: string | null
          data_focus_group: string | null
          data_incontro_finale: string | null
          data_inizio: string | null
          data_invio_scheda: string | null
          data_visita_1: string | null
          data_visita_2: string | null
          data_visita_3: string | null
          data_visita_4: string | null
          giorni_orari_lezioni: string | null
          id: string
          insegnamento_id: string
          link_questionario: string | null
          note: string | null
          numero_studenti: number | null
          osservazioni_aula: string | null
          osservazioni_focus_group: string | null
          scheda_sintesi: string | null
          scheda_sintesi_pdf_url: string | null
          sede: string | null
          stato: Database["public"]["Enums"]["stato_mentoraggio"]
          svolgimento:
            | Database["public"]["Enums"]["modalita_svolgimento"]
            | null
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "mentoraggi"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      mentoraggio_aggiorna_backoffice: {
        Args: { p_mentoraggio_id: string; p_valori: Json }
        Returns: {
          anno_accademico: string
          azioni_miglioramento: string | null
          created_at: string
          data_fine: string | null
          data_focus_group: string | null
          data_incontro_finale: string | null
          data_inizio: string | null
          data_invio_scheda: string | null
          data_visita_1: string | null
          data_visita_2: string | null
          data_visita_3: string | null
          data_visita_4: string | null
          giorni_orari_lezioni: string | null
          id: string
          insegnamento_id: string
          link_questionario: string | null
          note: string | null
          numero_studenti: number | null
          osservazioni_aula: string | null
          osservazioni_focus_group: string | null
          scheda_sintesi: string | null
          scheda_sintesi_pdf_url: string | null
          sede: string | null
          stato: Database["public"]["Enums"]["stato_mentoraggio"]
          svolgimento:
            | Database["public"]["Enums"]["modalita_svolgimento"]
            | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "mentoraggi"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      mentoraggio_aggiorna_mentee: {
        Args: { p_mentoraggio_id: string; p_valori: Json }
        Returns: {
          anno_accademico: string
          azioni_miglioramento: string | null
          created_at: string
          data_fine: string | null
          data_focus_group: string | null
          data_incontro_finale: string | null
          data_inizio: string | null
          data_invio_scheda: string | null
          data_visita_1: string | null
          data_visita_2: string | null
          data_visita_3: string | null
          data_visita_4: string | null
          giorni_orari_lezioni: string | null
          id: string
          insegnamento_id: string
          link_questionario: string | null
          note: string | null
          numero_studenti: number | null
          osservazioni_aula: string | null
          osservazioni_focus_group: string | null
          scheda_sintesi: string | null
          scheda_sintesi_pdf_url: string | null
          sede: string | null
          stato: Database["public"]["Enums"]["stato_mentoraggio"]
          svolgimento:
            | Database["public"]["Enums"]["modalita_svolgimento"]
            | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "mentoraggi"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      mentoraggio_aggiorna_mentore: {
        Args: { p_mentoraggio_id: string; p_valori: Json }
        Returns: {
          anno_accademico: string
          azioni_miglioramento: string | null
          created_at: string
          data_fine: string | null
          data_focus_group: string | null
          data_incontro_finale: string | null
          data_inizio: string | null
          data_invio_scheda: string | null
          data_visita_1: string | null
          data_visita_2: string | null
          data_visita_3: string | null
          data_visita_4: string | null
          giorni_orari_lezioni: string | null
          id: string
          insegnamento_id: string
          link_questionario: string | null
          note: string | null
          numero_studenti: number | null
          osservazioni_aula: string | null
          osservazioni_focus_group: string | null
          scheda_sintesi: string | null
          scheda_sintesi_pdf_url: string | null
          sede: string | null
          stato: Database["public"]["Enums"]["stato_mentoraggio"]
          svolgimento:
            | Database["public"]["Enums"]["modalita_svolgimento"]
            | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "mentoraggi"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      mentoraggio_anno_corrente: {
        Args: { p_mentoraggio_id: string }
        Returns: boolean
      }
      mentoraggio_backoffice: { Args: never; Returns: boolean }
      mentoraggio_scheda_sintesi_imposta: {
        Args: { p_mentoraggio_id: string; p_storage_path: string }
        Returns: undefined
      }
      mentoraggio_utente_associato: {
        Args: { p_mentoraggio_id: string; p_user_id?: string }
        Returns: boolean
      }
      mentoraggio_utente_mentee: {
        Args: { p_mentoraggio_id: string; p_user_id?: string }
        Returns: boolean
      }
      menu_data_nuova: {
        Args: {
          p_fallback: string
          p_percorso: string
          p_ultima_modifica: string
          p_user_id: string
        }
        Returns: boolean
      }
      menu_registra_accesso: {
        Args: { p_percorso: string }
        Returns: undefined
      }
      menu_stato_novita: { Args: never; Returns: Json }
      notifiche_aggiorna_trigger_regole: { Args: never; Returns: number }
      notifiche_amministratore: { Args: never; Returns: boolean }
      notifiche_anno_corrente: { Args: never; Returns: string }
      notifiche_condizione_relazionale_ok: {
        Args: {
          p_campo_id_principale?: string
          p_condizione: Json
          p_record: Json
          p_tabella_principale: string
        }
        Returns: boolean
      }
      notifiche_condizioni_ok: {
        Args: { p_configurazione: Json; p_record: Json }
        Returns: boolean
      }
      notifiche_condizioni_regola_ok: {
        Args: {
          p_configurazione: Json
          p_record: Json
          p_tabella_principale: string
        }
        Returns: boolean
      }
      notifiche_config_destinatari_regola: {
        Args: {
          p_anno: string
          p_configurazione: Json
          p_destinatari: string
          p_record: Json
        }
        Returns: Json
      }
      notifiche_conta_destinatari: {
        Args: { p_messaggio_id: string }
        Returns: number
      }
      notifiche_crea_messaggio_da_regola: {
        Args: {
          p_data_riferimento?: string
          p_evento?: string
          p_record?: Json
          p_regola_id: string
        }
        Returns: string
      }
      notifiche_dettaglio_destinatari: {
        Args: { p_messaggio_id: string }
        Returns: {
          cognome: string
          email_unipa: string
          errore: string
          inviato_at: string
          letto_at: string
          nome: string
          stato: string
          user_id: string
        }[]
      }
      notifiche_disattiva_dispositivo: {
        Args: { p_token: string }
        Returns: boolean
      }
      notifiche_elenco_utenti_attivi: {
        Args: never
        Returns: {
          cognome: string
          email_unipa: string
          nome: string
          role: string
          user_id: string
        }[]
      }
      notifiche_genera_destinatari: {
        Args: { p_messaggio_id: string }
        Returns: number
      }
      notifiche_inserisci_destinatari_relazionali: {
        Args: { p_configurazione: Json; p_messaggio_id: string }
        Returns: number
      }
      notifiche_materializza_regole_temporali: { Args: never; Returns: number }
      notifiche_puo_gestire: { Args: never; Returns: boolean }
      notifiche_registra_dispositivo: {
        Args: { p_piattaforma: string; p_token: string }
        Returns: string
      }
      notifiche_render_template: {
        Args: { p_record: Json; p_template: string }
        Returns: string
      }
      notifiche_segna_letta: {
        Args: { p_destinatario_id: string }
        Returns: undefined
      }
      notifiche_utente_amministratore: { Args: never; Returns: boolean }
      notifiche_utente_attivo: { Args: { p_user_id: string }; Returns: boolean }
      notifiche_valore_condizione_ok: {
        Args: { p_atteso?: string; p_operatore: string; p_valore: Json }
        Returns: boolean
      }
      partecipazione_annuale_imposta: {
        Args: {
          p_anno_accademico: string
          p_note?: string
          p_stato: string
          p_user_id: string
        }
        Returns: undefined
      }
      partecipazione_annuale_rispondi: {
        Args: { p_anno_accademico?: string; p_partecipa: boolean }
        Returns: Json
      }
      partecipazione_annuale_stato: {
        Args: { p_anno_accademico?: string }
        Returns: Json
      }
      partecipazioni_annuali_genera: {
        Args: { p_anno_destinazione: string; p_anno_sorgente?: string }
        Returns: number
      }
      partecipazioni_annuali_proprie: {
        Args: never
        Returns: {
          aggiornato_da: string | null
          anno_accademico: string
          cambiare_mentee_seguiti: string | null
          cambiare_mentore: boolean | null
          confermato_at: string | null
          confermato_da: string | null
          created_at: string
          disponibile_mentoring_esami: boolean | null
          note: string | null
          note_attivita_mentore: string | null
          note_sui_mentori: string | null
          preferenza_periodo_mentore:
            | Database["public"]["Enums"]["preferenza_periodo_mentore_enum"]
            | null
          richiesta_at: string
          risposta_at: string | null
          segnalazioni_suggerimenti: string | null
          solo_mentore: boolean
          stato: Database["public"]["Enums"]["stato_partecipazione_annuale"]
          updated_at: string
          user_id: string
          valutazione_mentori_precedenti: number | null
        }[]
        SetofOptions: {
          from: "*"
          to: "partecipazioni_annuali"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      puo_modificare: {
        Args: {
          p_ambito: Database["public"]["Enums"]["ambito_modifica"]
          p_anno_accademico: string
        }
        Returns: boolean
      }
      puo_modificare_corrente: {
        Args: { p_ambito: Database["public"]["Enums"]["ambito_modifica"] }
        Returns: boolean
      }
      questionario_mentoraggio_link_imposta: {
        Args: { p_mentoraggio_id: string; p_url: string }
        Returns: undefined
      }
      questionario_pubblico_carica: { Args: { p_token: string }; Returns: Json }
      questionario_pubblico_invia: {
        Args: { p_risposte: Json; p_token: string }
        Returns: string
      }
      questionario_pubblico_leggi: { Args: { p_token: string }; Returns: Json }
      questionario_risultati_mentoraggio: {
        Args: { p_mentoraggio_id: string }
        Returns: Json
      }
      questionario_sintesi_mentoraggio: {
        Args: { p_mentoraggio_id: string }
        Returns: Json
      }
      richiedi_abilitazione: {
        Args: { p_ambito: Database["public"]["Enums"]["ambito_modifica"] }
        Returns: undefined
      }
      utente_ha_abilitazione: {
        Args: {
          p_ambito: Database["public"]["Enums"]["ambito_modifica"]
          p_anno_accademico: string
          p_user_id?: string
        }
        Returns: boolean
      }
      utente_owner_organizer: { Args: { p_user_id?: string }; Returns: boolean }
    }
    Enums: {
      ambito_modifica:
        | "anagrafica"
        | "insegnamento"
        | "insegnamento_selezione"
        | "insegnamento_creazione"
        | "insegnamento_modifica"
        | "insegnamento_non_richiesto"
      anno_erogazione:
        | "1° anno"
        | "2° anno"
        | "3° anno"
        | "4° anno"
        | "5° anno"
        | "6° anno"
      app_role: "owner" | "organizer" | "participant"
      fascia_eta: "<35" | "35-40" | "41-50" | "51-60" | "61-70" | ">70"
      modalita_svolgimento: "In presenza" | "A distanza" | "Misto"
      notifiche_piattaforma: "android" | "ios" | "web"
      notifiche_stato_destinatario:
        | "da_inviare"
        | "inviato"
        | "letto"
        | "errore"
        | "escluso_inattivo"
        | "senza_dispositivo"
      notifiche_stato_messaggio:
        | "bozza"
        | "programmato"
        | "da_inviare"
        | "in_invio"
        | "inviato"
        | "parziale"
        | "annullato"
        | "errore"
      notifiche_tipo_attivazione: "insert" | "update" | "data" | "programmata"
      notifiche_tipo_destinatari:
        | "tutti"
        | "participant"
        | "mentor"
        | "senior"
        | "mentee"
        | "mentor_senior"
        | "mentor_senior_mentee"
        | "iscritti_evento"
        | "iscritti_house_of_mentore"
        | "anno_accademico"
        | "manuale"
        | "relazionale"
      numero_mentoraggi_precedenti: "1 volta" | "2 volte" | "3 o più volte"
      preferenza_periodo_mentore_enum:
        | "Soltanto nel primo semestre"
        | "Soltanto nel secondo semestre"
        | "Una volta per semestre"
        | "Soltanto in uno dei due semestri, non è importante quale"
        | "Indifferente"
      questionario_destinatario: "partecipanti" | "studenti"
      questionario_provider: "interno" | "pubblico"
      questionario_tipo_domanda:
        | "testo_breve"
        | "testo_lungo"
        | "booleano"
        | "scelta_singola"
        | "scala"
      ruolo_accademico: "PO" | "PA" | "RU" | "RTT" | "RTDb" | "RTDa" | "altro"
      semestre_erogazione: "I semestre" | "Annuale" | "II semestre"
      stato_mentoraggio: "Non iniziato" | "In corso" | "Completato"
      stato_partecipazione_annuale:
        | "da_contattare"
        | "confermato"
        | "rinuncia"
        | "nuovo"
        | "sospeso"
      tipo_mentore: "senior" | "mentor"
      tipologia_evento:
        | "Incontro di approfondimento"
        | "Seminario"
        | "Workshop"
        | "Altro"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      ambito_modifica: [
        "anagrafica",
        "insegnamento",
        "insegnamento_selezione",
        "insegnamento_creazione",
        "insegnamento_modifica",
        "insegnamento_non_richiesto",
      ],
      anno_erogazione: [
        "1° anno",
        "2° anno",
        "3° anno",
        "4° anno",
        "5° anno",
        "6° anno",
      ],
      app_role: ["owner", "organizer", "participant"],
      fascia_eta: ["<35", "35-40", "41-50", "51-60", "61-70", ">70"],
      modalita_svolgimento: ["In presenza", "A distanza", "Misto"],
      notifiche_piattaforma: ["android", "ios", "web"],
      notifiche_stato_destinatario: [
        "da_inviare",
        "inviato",
        "letto",
        "errore",
        "escluso_inattivo",
        "senza_dispositivo",
      ],
      notifiche_stato_messaggio: [
        "bozza",
        "programmato",
        "da_inviare",
        "in_invio",
        "inviato",
        "parziale",
        "annullato",
        "errore",
      ],
      notifiche_tipo_attivazione: ["insert", "update", "data", "programmata"],
      notifiche_tipo_destinatari: [
        "tutti",
        "participant",
        "mentor",
        "senior",
        "mentee",
        "mentor_senior",
        "mentor_senior_mentee",
        "iscritti_evento",
        "iscritti_house_of_mentore",
        "anno_accademico",
        "manuale",
        "relazionale",
      ],
      numero_mentoraggi_precedenti: ["1 volta", "2 volte", "3 o più volte"],
      preferenza_periodo_mentore_enum: [
        "Soltanto nel primo semestre",
        "Soltanto nel secondo semestre",
        "Una volta per semestre",
        "Soltanto in uno dei due semestri, non è importante quale",
        "Indifferente",
      ],
      questionario_destinatario: ["partecipanti", "studenti"],
      questionario_provider: ["interno", "pubblico"],
      questionario_tipo_domanda: [
        "testo_breve",
        "testo_lungo",
        "booleano",
        "scelta_singola",
        "scala",
      ],
      ruolo_accademico: ["PO", "PA", "RU", "RTT", "RTDb", "RTDa", "altro"],
      semestre_erogazione: ["I semestre", "Annuale", "II semestre"],
      stato_mentoraggio: ["Non iniziato", "In corso", "Completato"],
      stato_partecipazione_annuale: [
        "da_contattare",
        "confermato",
        "rinuncia",
        "nuovo",
        "sospeso",
      ],
      tipo_mentore: ["senior", "mentor"],
      tipologia_evento: [
        "Incontro di approfondimento",
        "Seminario",
        "Workshop",
        "Altro",
      ],
    },
  },
} as const
