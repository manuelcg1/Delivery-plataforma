import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import 'auth_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final tenant = TextEditingController(text: 'elite'),
      email = TextEditingController(),
      password = TextEditingController(),
      first = TextEditingController(),
      last = TextEditingController();
  bool register = false;
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final error = auth.error;
    final apiBaseUrl = ref.watch(configProvider).apiBaseUrl;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.delivery_dining,
                    color: Color(0xFF2563EB),
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    register ? 'Crea tu cuenta' : 'Bienvenido',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: tenant,
                    decoration: const InputDecoration(
                      labelText: 'Código de empresa',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (register) ...[
                    TextField(
                      controller: first,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: last,
                      decoration: const InputDecoration(labelText: 'Apellido'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error is AppException
                            ? error.message
                            : 'No se pudo completar la operación',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Servidor: $apiBaseUrl',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => register
                            ? ref
                                .read(authControllerProvider.notifier)
                                .register(
                                  tenant.text,
                                  first.text,
                                  last.text,
                                  email.text,
                                  password.text,
                                )
                            : ref.read(authControllerProvider.notifier).login(
                                  tenant.text,
                                  email.text,
                                  password.text,
                                ),
                    child: Text(
                      auth.isLoading
                          ? 'Procesando…'
                          : register
                              ? 'Registrarme'
                              : 'Ingresar',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => register = !register),
                    child: Text(
                      register ? 'Ya tengo una cuenta' : 'Crear una cuenta',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
