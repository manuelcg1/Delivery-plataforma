import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import 'auth_controller.dart';

const _navy = Color(0xFF06163A);
const _orange = Color(0xFFFF7C00);
const _border = Color(0xFFE5E7EB);
const _primaryText = Color(0xFF111827);
const _secondaryText = Color(0xFF6B7280);

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with SingleTickerProviderStateMixin {
  final tenant = TextEditingController(text: 'elite');
  final email = TextEditingController();
  final password = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  late final AnimationController entrance;
  bool register = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    tenant.dispose();
    email.dispose();
    password.dispose();
    first.dispose();
    last.dispose();
    entrance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (register) {
      await ref.read(authControllerProvider.notifier).register(
            tenant.text,
            first.text,
            last.text,
            email.text,
            password.text,
          );
    } else {
      await ref.read(authControllerProvider.notifier).login(
            tenant.text,
            email.text,
            password.text,
          );
    }
  }

  void _toggleMode() {
    setState(() => register = !register);
    entrance.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final apiBaseUrl = ref.watch(configProvider).apiBaseUrl;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth >= 700 &&
                constraints.maxWidth > constraints.maxHeight;
            final compact =
                keyboardOpen || landscape || constraints.maxHeight < 780;
            final hero = _LoginHero(compact: compact);
            final form = _AuthFormCard(
              compact: compact,
              register: register,
              tenant: tenant,
              first: first,
              last: last,
              email: email,
              password: password,
              obscurePassword: obscurePassword,
              loading: auth.isLoading,
              error: auth.error,
              apiBaseUrl: apiBaseUrl,
              onTogglePassword: () =>
                  setState(() => obscurePassword = !obscurePassword),
              onSubmit: _submit,
              onToggleMode: _toggleMode,
            );
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: keyboardOpen ? 16 : 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: landscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: hero),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child:
                                  _Entrance(animation: entrance, child: form),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          hero,
                          Transform.translate(
                            offset: Offset(0, compact ? -28 : -36),
                            child: _Entrance(animation: entrance, child: form),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: compact ? 205 : 250,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/branding/cerka-login-hero-v2.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            Positioned(
              top: compact ? 16 : 24,
              left: 24,
              child: const _CerkaBrand(),
            ),
            Positioned(
              left: 24,
              top: compact ? 92 : 104,
              right: compact ? 185 : 165,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Bienvenido!',
                      maxLines: 1,
                      style: TextStyle(
                          color: _primaryText,
                          fontSize: 23,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Inicia sesión para\ncontinuar',
                      style: TextStyle(
                          color: Color(0xFF4B5563),
                          height: 1.45,
                          fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CerkaBrand extends StatelessWidget {
  const _CerkaBrand();

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'CERKA Delivery',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('C',
                  style: TextStyle(
                      color: _primaryText,
                      fontSize: 38,
                      height: .8,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 7),
              const Text('CERKA',
                  style: TextStyle(
                      color: _primaryText,
                      fontSize: 22,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w900)),
            ]),
            const Padding(
              padding: EdgeInsets.only(left: 47, top: 3),
              child: Text('DELIVERY',
                  style: TextStyle(
                      color: _primaryText,
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.compact,
    required this.register,
    required this.tenant,
    required this.first,
    required this.last,
    required this.email,
    required this.password,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.apiBaseUrl,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onToggleMode,
  });
  final bool compact, register, obscurePassword, loading;
  final TextEditingController tenant, first, last, email, password;
  final Object? error;
  final String apiBaseUrl;
  final VoidCallback onTogglePassword, onSubmit, onToggleMode;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 22 : 28,
            compact ? 18 : 24,
            compact ? 22 : 28,
            compact ? 14 : 22,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(compact ? 34 : 42),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1406163A),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: compact ? 40 : 48,
                  height: compact ? 40 : 48,
                  margin: EdgeInsets.only(bottom: compact ? 4 : 8),
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFF7E6), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, color: _orange),
                ),
                Text(register ? 'Crear cuenta' : 'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _primaryText,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: compact ? 4 : 8),
                Center(
                  child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(4))),
                ),
                SizedBox(height: compact ? 12 : 18),
                _CerkaTextField(
                  controller: tenant,
                  label: 'Código de empresa',
                  icon: Icons.business_rounded,
                  textInputAction: TextInputAction.next,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: register
                      ? Padding(
                          key: const ValueKey('register-fields'),
                          padding: EdgeInsets.only(top: compact ? 10 : 14),
                          child: Column(children: [
                            _CerkaTextField(
                              controller: first,
                              label: 'Nombre',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                            ),
                            SizedBox(height: compact ? 10 : 14),
                            _CerkaTextField(
                              controller: last,
                              label: 'Apellido',
                              icon: Icons.badge_outlined,
                              textInputAction: TextInputAction.next,
                            ),
                          ]),
                        )
                      : const SizedBox.shrink(key: ValueKey('login-fields')),
                ),
                SizedBox(height: compact ? 10 : 14),
                _CerkaTextField(
                  controller: email,
                  label: 'Correo electrónico',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                SizedBox(height: compact ? 10 : 14),
                _CerkaTextField(
                  controller: password,
                  label: 'Ingresa tu contraseña',
                  semanticLabel: 'Contraseña',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => loading ? null : onSubmit(),
                  suffix: IconButton(
                    tooltip: obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: onTogglePassword,
                    icon: Icon(obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
                if (!register)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('¿Olvidaste tu contraseña?',
                          style: TextStyle(
                              color: _orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error is AppException
                          ? (error! as AppException).message
                          : 'No se pudo completar la operación',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14),
                    ),
                  ),
                ],
                SizedBox(height: compact ? 12 : 18),
                _PrimaryAuthButton(
                  loading: loading,
                  label: register ? 'Registrarme' : 'Ingresar',
                  onPressed: onSubmit,
                ),
                SizedBox(height: compact ? 2 : 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(register ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?',
                        style: const TextStyle(
                            color: _secondaryText, fontSize: 14)),
                    TextButton(
                      onPressed: loading ? null : onToggleMode,
                      style: TextButton.styleFrom(
                        foregroundColor: _orange,
                        minimumSize: const Size(48, 48),
                      ),
                      child:
                          Text(register ? 'Inicia sesión' : 'Crear una cuenta'),
                    ),
                  ],
                ),
                if (kDebugMode) ...[
                  SizedBox(height: compact ? 2 : 8),
                  Text('Servidor: $apiBaseUrl',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: _secondaryText, fontSize: 11)),
                ],
              ],
            ),
          ),
        ),
      );
}

class _CerkaTextField extends StatefulWidget {
  const _CerkaTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.semanticLabel,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.autofillHints,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final String? semanticLabel;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_CerkaTextField> createState() => _CerkaTextFieldState();
}

class _CerkaTextFieldState extends State<_CerkaTextField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.semanticLabel ?? widget.label,
              style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: MediaQuery.sizeOf(context).height < 780 ? 4 : 6),
          Semantics(
            textField: true,
            label: widget.semanticLabel ?? widget.label,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: focusNode.hasFocus
                    ? const [
                        BoxShadow(color: Color(0x20FF7C00), blurRadius: 12)
                      ]
                    : const [],
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: focusNode,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                obscureText: widget.obscureText,
                autofillHints: widget.autofillHints,
                onSubmitted: widget.onSubmitted,
                style: const TextStyle(color: _primaryText, fontSize: 16),
                decoration: InputDecoration(
                  hintText: widget.label,
                  hintStyle:
                      const TextStyle(color: _secondaryText, fontSize: 16),
                  prefixIcon: Icon(widget.icon,
                      color: focusNode.hasFocus ? _orange : _secondaryText),
                  suffixIcon: widget.suffix,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  constraints: const BoxConstraints(minHeight: 52),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: loading ? 'Procesando' : label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: loading
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x35FF7C00),
                      blurRadius: 16,
                      offset: Offset(0, 7),
                    )
                  ],
          ),
          child: FilledButton(
            onPressed: loading ? null : onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFFFFB800),
              disabledBackgroundColor: const Color(0xFFFFC58F),
              foregroundColor: _navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: loading
                  ? const SizedBox.square(
                      key: ValueKey('loading'),
                      dimension: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(label, key: ValueKey(label)),
            ),
          ),
        ),
      );
}
