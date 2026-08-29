import 'package:flutter/material.dart';

import '../../app/app_core.dart';
import '../../app/app_session_controller.dart';
import 'login_controller.dart';

/// Pagina di autenticazione.
///
/// Contiene esclusivamente layout, validazione dei campi e componenti grafici.
/// Il processo di login e' delegato a [LoginController].
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.sessione,
  });

  final SessioneController sessione;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoginController(widget.sessione);
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Image.asset(
                            AppBranding.logoAsset,
                            height: 64,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Progetto Mentore per la Didattica',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const <String>[
                              AutofillHints.email,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: _validaEmail,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_controller.passwordVisibile,
                            autofillHints: const <String>[
                              AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) => _accedi(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _controller.passwordVisibile
                                    ? 'Nascondi password'
                                    : 'Mostra password',
                                onPressed:
                                    _controller.cambiaVisibilitaPassword,
                                icon: Icon(
                                  _controller.passwordVisibile
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: _validaPassword,
                          ),
                          if (_controller.errore case final String errore) ...[
                            const SizedBox(height: 12),
                            Text(
                              errore,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed:
                                _controller.caricamento ? null : _accedi,
                            child: _controller.caricamento
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Accedi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String? _validaEmail(String? valore) {
    final email = valore?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      return 'Inserisci un’email valida.';
    }
    return null;
  }

  String? _validaPassword(String? valore) {
    if (valore == null || valore.isEmpty) {
      return 'Inserisci la password.';
    }
    return null;
  }

  Future<void> _accedi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _controller.accedi(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }
}
