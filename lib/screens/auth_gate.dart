import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/auth_token_store.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Shows [LoginScreen] until [AppState.isAuthenticated], then [HomeShell].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.useApi && !AppConfig.useDevAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
    }
  }

  Future<void> _restore() async {
    if (_restoring || !mounted) return;
    final app = context.read<AppState>();
    if (app.isAuthenticated) return;
    if (authTokenStore.accessToken == null) return;
    setState(() => _restoring = true);
    try {
      await app.restoreSessionIfNeeded();
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch AppState here (not inside ListenableBuilder) so completeLogin()
    // reliably swaps LoginScreen → HomeShell after Cognito login.
    final app = context.watch<AppState>();
    return ListenableBuilder(
      listenable: authTokenStore,
      builder: (context, _) {
        if (_restoring) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (app.isAuthenticated) {
          return const HomeShell();
        }
        return const LoginScreen();
      },
    );
  }
}
