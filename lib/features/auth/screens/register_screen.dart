import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../../shared/widgets/taji_button.dart';
import '../../../shared/widgets/taji_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final message = await context.read<AuthRepository>().register(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } on AuthException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    wide: true,
    eyebrow: 'Empieza en minutos',
    title: 'Crea tu cuenta',
    subtitle: 'Tu cuenta se registrará como Copropietario / Residente.',
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusBanner(message: _error),
          if (_error.isNotEmpty) const SizedBox(height: 15),
          _ResponsivePair(
            children: [
              TajiTextField(
                controller: _firstName,
                label: 'Nombres',
                hint: 'Tus nombres',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: _required,
              ),
              TajiTextField(
                controller: _lastName,
                label: 'Apellidos',
                hint: 'Tus apellidos',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: _required,
              ),
            ],
          ),
          const SizedBox(height: 15),
          _ResponsivePair(
            children: [
              TajiTextField(
                controller: _email,
                label: 'Correo electrónico',
                hint: 'tu@correo.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (_required(value) != null) return _required(value);
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!)
                      ? null
                      : 'Ingresa un correo válido.';
                },
              ),
              TajiTextField(
                controller: _phone,
                label: 'Teléfono (opcional)',
                hint: '+591 70000000',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
          const SizedBox(height: 15),
          _ResponsivePair(
            children: [
              TajiTextField(
                controller: _password,
                label: 'Contraseña',
                hint: 'Mínimo 10 caracteres',
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: (value) => (value?.length ?? 0) < 10
                    ? 'Usa al menos 10 caracteres.'
                    : null,
              ),
              TajiTextField(
                controller: _confirm,
                label: 'Repite la contraseña',
                hint: 'Repite tu contraseña',
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (value) => value != _password.text
                    ? 'Las contraseñas no coinciden.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TajiButton(
            label: 'Crear mi cuenta',
            loading: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Ya tengo una cuenta'),
          ),
        ],
      ),
    ),
  );

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 520) {
        return Column(
          children: [children[0], const SizedBox(height: 15), children[1]],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 14),
          Expanded(child: children[1]),
        ],
      );
    },
  );
}
