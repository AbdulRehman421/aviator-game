import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth/auth_screen.dart';
import 'firebase_options.dart';
import 'game_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AviatorApp());
}

class AviatorApp extends StatelessWidget {
  const AviatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aviator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
      ),
      home: AuthGate(auth: AuthService()),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: auth.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFE50539)),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null) return AuthScreen(auth: auth);
        return GamePage(user: user, auth: auth);
      },
    );
  }
}
