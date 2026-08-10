import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/taji_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/state/auth_controller.dart';
import 'shared/widgets/taji_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
    ),
  );
  final repository = AuthRepository(ApiClient());
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: repository),
        ChangeNotifierProvider(
          create: (_) => AuthController(repository)..initialize(),
        ),
      ],
      child: const TajiApp(),
    ),
  );
}

class TajiApp extends StatelessWidget {
  const TajiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Taji',
    debugShowCheckedModeBanner: false,
    theme: buildTajiTheme(),
    home: Consumer<AuthController>(
      builder: (context, auth, _) {
        return switch (auth.status) {
          AuthStatus.initializing => const _SplashScreen(),
          AuthStatus.unauthenticated => const LoginScreen(),
          AuthStatus.authenticated => const HomeScreen(),
        };
      },
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TajiLogo(),
          SizedBox(height: 22),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ],
      ),
    ),
  );
}
