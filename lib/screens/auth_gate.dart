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
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    if (_restoring || !mounted) return;
    final app = context.read<AppState>();
    if (app.isAuthenticated) return;

    setState(() => _restoring = true);
    try {
      if (AppConfig.useDevAuth && AppConfig.devUserId.trim().isNotEmpty) {
        await app.completeDevLogin();
        return;
      }
      if (authTokenStore.accessToken == null) return;
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
        if (AppConfig.useDevAuth && AppConfig.devUserId.trim().isEmpty) {
          return const _DevAuthConfigError();
        }
        return const LoginScreen();
      },
    );
  }
}

/// Shown when `USE_DEV_AUTH=true` but `DEV_USER_ID` was not passed to `flutter run`.
class _DevAuthConfigError extends StatelessWidget {
  const _DevAuthConfigError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Local dev auth misconfigured',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Run via scripts/run_local.ps1 (sets DEV_USER_ID and API_BASE_URL), '
                'or pass --dart-define=DEV_USER_ID=<uuid>.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
