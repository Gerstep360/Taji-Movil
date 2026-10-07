import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';
import '../../../core/router/app_routes.dart';
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
  final _unitLabel = TextEditingController();
  List<Map<String, dynamic>> _condominiums = [];
  int? _selectedCondominiumId;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadCondos();
  }

  Future<void> _loadCondos() async {
    final list = await context.read<AuthRepository>().getPublicCondominiums();
    if (mounted) {
      setState(() {
        _condominiums = list;
        if (list.isNotEmpty && _selectedCondominiumId == null) {
          _selectedCondominiumId = list.first['id'] as int?;
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _password,
      _confirm,
      _unitLabel,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCondominiumId == null) {
      setState(() => _error = 'Por favor selecciona tu condominio de residencia.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await context.read<AuthRepository>().register(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        condominiumId: _selectedCondominiumId,
        unitLabel: _unitLabel.text,
      );
      if (!mounted) return;
      context.goNamed(
        AppRoute.login.name,
        queryParameters: {'registered': '1'},
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE4ED)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedCondominiumId,
                isExpanded: true,
                hint: const Text(
                  'Selecciona tu Condominio',
                  style: TextStyle(color: Color(0xFF6F7F93), fontSize: 14),
                ),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0F6FFF)),
                items: _condominiums.map((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'] as int?,
                    child: Text(
                      '${c['name']} (${c['address'] ?? c['slug']})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF10233C),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCondominiumId = val),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TajiTextField(
            controller: _unitLabel,
            label: 'Unidad / Departamento que habitas',
            hint: 'Ej. Torre A - Depto 302',
            icon: Icons.apartment_outlined,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 15),
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
            onPressed: _busy
                ? null
                : () => context.goNamed(AppRoute.login.name),
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
