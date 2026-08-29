import 'package:flutter/foundation.dart';

import '../../app/app_session_controller.dart';

/// Controller della pagina Login.
///
/// Coordina esclusivamente il processo di autenticazione delegandolo a
/// [SessioneController]. Non contiene componenti UI e non accede direttamente
/// a Supabase o al database.
class LoginController extends ChangeNotifier {
  LoginController(this.sessione) {
    sessione.addListener(_aggiorna);
  }

  final SessioneController sessione;

  bool _passwordVisibile = false;

  bool get passwordVisibile => _passwordVisibile;
  bool get caricamento => sessione.caricamento;
  String? get errore => sessione.errore;

  /// Mostra o nasconde la password nella pagina.
  void cambiaVisibilitaPassword() {
    _passwordVisibile = !_passwordVisibile;
    notifyListeners();
  }

  /// Avvia l'autenticazione con le credenziali fornite dalla pagina.
  Future<void> accedi({
    required String email,
    required String password,
  }) {
    return sessione.accedi(
      email: email.trim(),
      password: password,
    );
  }

  void _aggiorna() => notifyListeners();

  @override
  void dispose() {
    sessione.removeListener(_aggiorna);
    super.dispose();
  }
}
