import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/taji_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_controller.dart';
import 'shared/widgets/taji_logo.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
    ),
  );

  try {
    await ApiConfig.initialize();
  } on Object catch (error) {
    runApp(_StartupErrorApp(message: error.toString()));
    return;
  }

  final tokens = TokenStore();
  final api = ApiClient(tokenStore: tokens);
  final repository = AuthRepository(api);
  final auth = AuthController(repository);
  final router = AppRouter.create(auth);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<AuthRepository>.value(value: repository),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: TajiApp(router: router),
    ),
  );
  unawaited(auth.initialize());
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTajiTheme(),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TajiLogo(),
                const SizedBox(height: 24),
                Text(
                  'No pudimos iniciar Taji',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Revisa assets/config/app_config.json y vuelve a abrir la aplicación.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TajiColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
