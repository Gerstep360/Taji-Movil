import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../../shared/widgets/taji_button.dart';
import '../../../shared/widgets/taji_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String _message = '';
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final message = await context.read<AuthRepository>().forgotPassword(
        _email.text,
      );
      if (mounted) {
        setState(() {
          _sent = true;
          _message = message;
        });
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    eyebrow: 'Recupera tu acceso',
    title: _sent ? 'Revisa tu correo' : '¿Olvidaste tu contraseña?',
    subtitle: _sent
        ? 'El enlace abrirá la pantalla web segura de Taji para crear tu nueva clave.'
        : 'Escribe tu correo y te enviaremos un enlace seguro.',
    child: _sent
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBanner(message: _message, success: true),
              const SizedBox(height: 22),
              TajiButton(
                label: 'Volver a iniciar sesión',
                onPressed: () => context.goNamed(AppRoute.login.name),
              ),
            ],
          )
        : Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusBanner(message: _error),
                if (_error.isNotEmpty) const SizedBox(height: 15),
                TajiTextField(
                  controller: _email,
                  label: 'Correo electrónico',
                  hint: 'tu@correo.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa tu correo.';
                    }
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                        ? null
                        : 'Ingresa un correo válido.';
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 22),
                TajiButton(
                  label: 'Enviar enlace',
                  loading: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.goNamed(AppRoute.login.name),
                  child: const Text('← Volver a iniciar sesión'),
                ),
              ],
            ),
          ),
  );
}
