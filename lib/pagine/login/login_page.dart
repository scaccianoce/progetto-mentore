import 'package:flutter/material.dart';

import '../../sessione_controller.dart';
import 'login_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.sessione});

  final SessioneController sessione;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoginController(widget.sessione);
  }

  @override
  void dispose() {
    _controller.dispose();
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
              builder: (BuildContext context, Widget? child) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Icon(
                            Icons.school_outlined,
                            size: 54,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Progetto Mentore per la Didattica',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _controller.emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const <String>[AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (String? valore) {
                              final String email = valore?.trim() ?? '';
                              return email.contains('@')
                                  ? null
                                  : 'Inserisci un’email valida.';
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _controller.passwordController,
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
                                onPressed: _controller.cambiaVisibilitaPassword,
                                icon: Icon(
                                  _controller.passwordVisibile
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (String? valore) {
                              return valore == null || valore.isEmpty
                                  ? 'Inserisci la password.'
                                  : null;
                            },
                          ),
                          if (_controller.errore case final String errore) ...[
                            const SizedBox(height: 12),
                            Text(
                              errore,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _controller.caricamento ? null : _accedi,
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

  Future<void> _accedi() async {
    if (_formKey.currentState?.validate() ?? false) {
      await _controller.accedi();
    }
  }
}
