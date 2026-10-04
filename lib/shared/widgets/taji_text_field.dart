import 'package:flutter/material.dart';

class TajiTextField extends StatefulWidget {
  const TajiTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.minLines,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  /// Campos largos, como el código QR pegado a mano, necesitan varias líneas.
  final int maxLines;
  final int? minLines;

  @override
  State<TajiTextField> createState() => _TajiTextFieldState();
}

class _TajiTextFieldState extends State<TajiTextField> {
  bool visible = false;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    obscureText: widget.obscure && !visible,
    autofillHints: widget.autofillHints,
    validator: widget.validator,
    onFieldSubmitted: widget.onFieldSubmitted,
    maxLines: widget.maxLines,
    minLines: widget.minLines,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      prefixIcon: Icon(widget.icon, size: 20),
      suffixIcon: widget.obscure
          ? IconButton(
              tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
              onPressed: () => setState(() => visible = !visible),
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            )
          : null,
    ),
  );
}
