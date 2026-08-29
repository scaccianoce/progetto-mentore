// Punto di esportazione del nuovo livello dati.
//
// Durante la migrazione i vecchi repository possono continuare a esistere,
// ma i nuovi controller dovrebbero importare questo file e usare
// [DatabaseRepository] per l'accesso alle tabelle.
export 'repository_database.dart';
export 'repository_notifiche.dart';
