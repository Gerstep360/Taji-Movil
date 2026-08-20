import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/taji_theme.dart';

class TajiApp extends StatelessWidget {
  const TajiApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Taji',
    debugShowCheckedModeBanner: false,
    theme: buildTajiTheme(),
    routerConfig: router,
  );
}
