import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth_gate.dart';
import 'state/app_state.dart';
import 'theme/squad_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SquadUpApp());
}

class SquadUpApp extends StatelessWidget {
  const SquadUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'SquadUp',
        debugShowCheckedModeBanner: false,
        theme: buildSquadTheme(),
        home: const AuthGate(),
      ),
    );
  }
}
