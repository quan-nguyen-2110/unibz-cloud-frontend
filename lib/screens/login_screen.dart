// Migrated from squadUp-layout/src/routes/login.tsx (commit 512d5bf)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/auth_flow_widgets.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialEmail,
    this.emailVerified = false,
  });

  final String? initialEmail;
  final bool emailVerified;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();

  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefill = widget.initialEmail;
    if (prefill != null && prefill.isNotEmpty) {
      _email.text = prefill;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _openVerify(String email) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyEmailScreen(email: email),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await _auth.login(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      await context.read<AppState>().completeLogin(email: _email.text.trim());
    } on AuthException catch (e) {
      if (e.message == 'Email not confirmed') {
        _openVerify(_email.text.trim());
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SignupScreen()),
    );
  }

  void _openForgotPassword() {
    final trimmed = _email.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: trimmed.isEmpty ? null : trimmed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const AuthHero(
                    emoji: '👋',
                    title: 'Welcome back',
                    subtitle: "Sign in to see who's down today.",
                    topPadding: 64,
                    bottomPadding: 40,
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: _LoginFormCard(
                        email: _email,
                        password: _password,
                        showPassword: _showPassword,
                        loading: _loading,
                        error: _error,
                        emailVerified: widget.emailVerified,
                        onTogglePassword: () =>
                            setState(() => _showPassword = !_showPassword),
                        onSubmit: _submit,
                        onOpenSignup: _openSignup,
                        onOpenForgotPassword: _openForgotPassword,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.email,
    required this.password,
    required this.showPassword,
    required this.loading,
    required this.error,
    required this.emailVerified,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onOpenSignup,
    required this.onOpenForgotPassword,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool showPassword;
  final bool loading;
  final String? error;
  final bool emailVerified;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onOpenSignup;
  final VoidCallback onOpenForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: SquadColors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (emailVerified) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: SquadColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SquadColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: SquadColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email verified! Sign in to continue.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: SquadColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const AuthFieldLabel('Email'),
            const SizedBox(height: 6),
            AuthTextField(
              controller: email,
              hint: 'you@squadup.app',
              keyboardType: TextInputType.emailAddress,
              prefix: Icons.mail_outline_rounded,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: AuthFieldLabel('Password')),
                TextButton(
                  onPressed: onOpenForgotPassword,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SquadColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AuthTextField(
              controller: password,
              hint: '••••••••',
              obscureText: !showPassword,
              prefix: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: SquadColors.muted,
                ),
                onPressed: onTogglePassword,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: SquadColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: SquadColors.primary,
                disabledBackgroundColor:
                    SquadColors.primary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                loading ? 'Signing in…' : 'Log in',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const AuthSocialButtons(dividerLabel: 'or continue with'),
            const SizedBox(height: 28),
            Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: SquadColors.muted,
                ),
                children: [
                  const TextSpan(text: 'New here? '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onOpenSignup,
                      child: Text(
                        'Create account',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SquadColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'By continuing you agree to our Terms and acknowledge our Privacy Policy. Secured by Amazon Cognito.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                height: 1.45,
                color: SquadColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
