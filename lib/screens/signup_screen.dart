// Migrated from squadUp-layout/src/routes/signup.tsx (commit 512d5bf)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/squad_theme.dart';
import '../widgets/auth_flow_widgets.dart';
import '../widgets/auth_password_rules.dart';
import 'verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();

  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final displayName = _displayName.text.trim();
      final username = _username.text.trim();
      final email = _email.text.trim();
      final password = _password.text;

      if (displayName.isEmpty ||
          username.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        setState(() => _error = 'Please fill in all fields.');
        return;
      }
      if (!_usernamePattern.hasMatch(username)) {
        setState(
          () => _error = 'Username: 3–20 chars, letters/numbers/underscore.',
        );
        return;
      }
      if (!authPasswordRulesOk(password)) {
        setState(() => _error = 'Password does not meet the requirements.');
        return;
      }

      await _auth.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyEmailScreen(email: email),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                    emoji: '🎉',
                    title: 'Join SquadUp',
                    subtitle: 'Make spontaneous plans with your people.',
                    topPadding: 56,
                    bottomPadding: 36,
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: _SignupFormCard(
                        displayName: _displayName,
                        username: _username,
                        email: _email,
                        password: _password,
                        showPassword: _showPassword,
                        loading: _loading,
                        error: _error,
                        onTogglePassword: () =>
                            setState(() => _showPassword = !_showPassword),
                        onPasswordChanged: () => setState(() {}),
                        onSubmit: _submit,
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

class _SignupFormCard extends StatelessWidget {
  const _SignupFormCard({
    required this.displayName,
    required this.username,
    required this.email,
    required this.password,
    required this.showPassword,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
    required this.onPasswordChanged,
    required this.onSubmit,
  });

  final TextEditingController displayName;
  final TextEditingController username;
  final TextEditingController email;
  final TextEditingController password;
  final bool showPassword;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: SquadColors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthFieldLabel('Display name'),
            const SizedBox(height: 6),
            AuthTextField(
              controller: displayName,
              hint: 'Alex Rivera',
              prefix: Icons.person_outline_rounded,
              maxLength: 50,
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel('Username'),
            const SizedBox(height: 6),
            AuthTextField(
              controller: username,
              hint: 'alex_rivera',
              prefix: Icons.alternate_email_rounded,
              maxLength: 20,
              onChanged: (v) {
                final stripped = v.replaceAll(RegExp(r'\s'), '');
                if (stripped != v) {
                  username.value = username.value.copyWith(
                    text: stripped,
                    selection: TextSelection.collapsed(offset: stripped.length),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel('Email'),
            const SizedBox(height: 6),
            AuthTextField(
              controller: email,
              hint: 'you@squadup.app',
              keyboardType: TextInputType.emailAddress,
              prefix: Icons.mail_outline_rounded,
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel('Password'),
            const SizedBox(height: 6),
            AuthTextField(
              controller: password,
              hint: 'At least 8 characters',
              obscureText: !showPassword,
              prefix: Icons.lock_outline_rounded,
              onChanged: (_) => onPasswordChanged(),
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
            const SizedBox(height: 8),
            AuthPasswordRulesList(password: password.text),
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
            const SizedBox(height: 16),
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
                loading ? 'Creating account…' : 'Create account',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const AuthSocialButtons(dividerLabel: 'or sign up with'),
            const SizedBox(height: 24),
            Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: SquadColors.muted,
                ),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Log in',
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
            const SizedBox(height: 12),
            Text(
              'By creating an account you agree to our Terms and Privacy Policy.',
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
