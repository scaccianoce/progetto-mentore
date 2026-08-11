import 'package:flutter/material.dart';

import '../../sessione_controller.dart';

class LoginController extends ChangeNotifier {
  LoginController(this.sessione) {
    sessione.addListener(_aggiorna);
  }

  final SessioneController sessione;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _passwordVisibile = false;

  bool get passwordVisibile => _passwordVisibile;
  bool get caricamento => sessione.caricamento;
  String? get errore => sessione.errore;

  void cambiaVisibilitaPassword() {
    _passwordVisibile = !_passwordVisibile;
    notifyListeners();
  }

  Future<void> accedi() {
    return sessione.accedi(
      email: emailController.text,
      password: passwordController.text,
    );
  }

  void _aggiorna() => notifyListeners();

  @override
  void dispose() {
    sessione.removeListener(_aggiorna);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
