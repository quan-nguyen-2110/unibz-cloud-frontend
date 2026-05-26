// Migrated from squadUp-layout/src/routes/forgot-password.tsx (commit fceac4c)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/squad_theme.dart';
import '../widgets/auth_flow_widgets.dart';
import '../widgets/auth_password_rules.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart' show maskEmail;

const _codeLength = 6;

enum _ForgotStep { request, reset, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();

  _ForgotStep _step = _ForgotStep.request;
  String _sentTo = '';

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
    super.dispose();
  }

  void _goToReset(String email) {
    setState(() {
      _sentTo = email;
      _step = _ForgotStep.reset;
    });
  }

  void _goToDone() => setState(() => _step = _ForgotStep.done);

  void _goToRequest() => setState(() => _step = _ForgotStep.request);

  @override
  Widget build(BuildContext context) {
    final hero = switch (_step) {
      _ForgotStep.request => (
          icon: Icons.key_rounded,
          title: 'Reset your password',
          subtitle: "We'll email you a code to reset your password.",
        ),
      _ForgotStep.reset => (
          icon: Icons.verified_user_outlined,
          title: 'Create a new password',
          subtitle:
              'Enter the code we sent to\n${maskEmail(_sentTo)}',
        ),
      _ForgotStep.done => (
          icon: Icons.check_circle_outline,
          title: 'Password updated',
          subtitle: "You're all set. Sign in with your new password.",
        ),
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  AuthHero(
                    icon: hero.icon,
                    title: hero.title,
                    subtitle: hero.subtitle,
                    topPadding: 64,
                    bottomPadding: 40,
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: _ForgotFormCard(
                        step: _step,
                        email: _email,
                        sentTo: _sentTo,
                        auth: _auth,
                        onSent: _goToReset,
                        onDone: _goToDone,
                        onBackToRequest: _goToRequest,
                        onSignIn: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => LoginScreen(initialEmail: _sentTo),
                            ),
                          );
                        },
                        onBackToLogin: () => Navigator.of(context).pop(),
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

class _ForgotFormCard extends StatelessWidget {
  const _ForgotFormCard({
    required this.step,
    required this.email,
    required this.sentTo,
    required this.auth,
    required this.onSent,
    required this.onDone,
    required this.onBackToRequest,
    required this.onSignIn,
    required this.onBackToLogin,
  });

  final _ForgotStep step;
  final TextEditingController email;
  final String sentTo;
  final AuthService auth;
  final void Function(String email) onSent;
  final VoidCallback onDone;
  final VoidCallback onBackToRequest;
  final VoidCallback onSignIn;
  final VoidCallback onBackToLogin;

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
      child: switch (step) {
        _ForgotStep.request => _RequestStep(
            email: email,
            auth: auth,
            onSent: onSent,
            onBackToLogin: onBackToLogin,
          ),
        _ForgotStep.reset => _ResetStep(
            email: sentTo,
            auth: auth,
            onDone: onDone,
            onBack: onBackToRequest,
            onBackToLogin: onBackToLogin,
          ),
        _ForgotStep.done => _DoneStep(onSignIn: onSignIn),
      },
    );
  }
}

class _RequestStep extends StatefulWidget {
  const _RequestStep({
    required this.email,
    required this.auth,
    required this.onSent,
    required this.onBackToLogin,
  });

  final TextEditingController email;
  final AuthService auth;
  final void Function(String email) onSent;
  final VoidCallback onBackToLogin;

  @override
  State<_RequestStep> createState() => _RequestStepState();
}

class _RequestStepState extends State<_RequestStep> {
  bool _loading = false;
  String? _error;
  String? _info;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _info = null;
    });
    final value = widget.email.text.trim();
    if (value.isEmpty || !value.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    setState(() => _loading = true);
    try {
      final message = await widget.auth.forgotPassword(value);
      if (!mounted) return;
      setState(() {
        _info = message.contains('account exists')
            ? 'If an account exists, we sent a code to ${maskEmail(value)}.'
            : message;
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) widget.onSent(value);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthFieldLabel('Email'),
          const SizedBox(height: 6),
          AuthTextField(
            controller: widget.email,
            hint: 'you@squadup.app',
            keyboardType: TextInputType.emailAddress,
            prefix: Icons.mail_outline_rounded,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SquadColors.danger,
              ),
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: SquadColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SquadColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 18, color: SquadColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _info!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: SquadColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _loading ? 'Sending…' : 'Send reset code',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: SquadColors.primary,
              disabledBackgroundColor: SquadColors.primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: widget.onBackToLogin,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              'Back to log in',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SquadColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetStep extends StatefulWidget {
  const _ResetStep({
    required this.email,
    required this.auth,
    required this.onDone,
    required this.onBack,
    required this.onBackToLogin,
  });

  final String email;
  final AuthService auth;
  final VoidCallback onDone;
  final VoidCallback onBack;
  final VoidCallback onBackToLogin;

  @override
  State<_ResetStep> createState() => _ResetStepState();
}

class _ResetStepState extends State<_ResetStep> {
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());
  final _controllers = List.generate(_codeLength, (_) => TextEditingController());
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  String? _error;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final n in _focusNodes) {
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _passwordOk => authPasswordRulesOk(_password.text);

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  void _setDigit(int index, String value) {
    setState(() => _error = null);
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      _controllers[index].clear();
      setState(() {});
      return;
    }
    var i = index;
    for (var k = 0; k < clean.length; k++) {
      if (i >= _codeLength) break;
      _controllers[i].text = clean[k];
      i++;
    }
    setState(() {});
    _focusNodes[i.clamp(0, _codeLength - 1)].requestFocus();
  }

  void _applyPastedCode(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final slice = digits.substring(0, digits.length.clamp(0, _codeLength));
    for (var i = 0; i < _codeLength; i++) {
      _controllers[i].clear();
    }
    for (var k = 0; k < slice.length; k++) {
      _controllers[k].text = slice[k];
    }
    setState(() => _error = null);
    _focusNodes[slice.length.clamp(0, _codeLength - 1)].requestFocus();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_code.length < _codeLength) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    if (!_passwordOk) {
      setState(() => _error = 'Password does not meet the requirements.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.auth.resetPassword(
        email: widget.email,
        code: _code,
        password: _password.text,
      );
      if (mounted) widget.onDone();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    setState(() => _error = null);
    try {
      await widget.auth.forgotPassword(widget.email);
      _startCooldown();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmMismatch =
        _confirm.text.isNotEmpty && _confirm.text != _password.text;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthFieldLabel('Confirmation code'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_codeLength, (i) {
              return SizedBox(
                width: 48,
                height: 56,
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  autofillHints:
                      i == 0 ? const [AutofillHints.oneTimeCode] : null,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: SquadColors.text,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SquadColors.inputFill,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: SquadColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: SquadColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: SquadColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.length > 1) {
                      _applyPastedCode(v);
                      return;
                    }
                    if (v.isEmpty && i > 0) {
                      _focusNodes[i - 1].requestFocus();
                    }
                    _setDigit(i, v);
                  },
                ),
              );
            }),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cooldown > 0 ? null : _resend,
              child: Text(
                _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _cooldown > 0 ? SquadColors.muted : SquadColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const AuthFieldLabel('New password'),
          const SizedBox(height: 6),
          AuthTextField(
            controller: _password,
            hint: 'At least 8 characters',
            obscureText: !_showPassword,
            prefix: Icons.lock_outline_rounded,
            onChanged: (_) => setState(() {}),
            suffix: IconButton(
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: SquadColors.muted,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 8),
          AuthPasswordRulesList(password: _password.text),
          const SizedBox(height: 16),
          const AuthFieldLabel('Confirm password'),
          const SizedBox(height: 6),
          AuthTextField(
            controller: _confirm,
            hint: 'Re-enter password',
            obscureText: !_showPassword,
            prefix: Icons.lock_outline_rounded,
            onChanged: (_) => setState(() {}),
          ),
          if (confirmMismatch) ...[
            const SizedBox(height: 6),
            Text(
              "Passwords don't match.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: SquadColors.danger,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SquadColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: SquadColors.primary,
              disabledBackgroundColor: SquadColors.primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              _loading ? 'Resetting…' : 'Reset password',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              'Back',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SquadColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            textAlign: TextAlign.center,
            TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: SquadColors.muted,
              ),
              children: [
                const TextSpan(text: 'Remembered it? '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: widget.onBackToLogin,
                    child: Text(
                      'Back to log in',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SquadColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: SquadColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 32,
              color: SquadColors.success,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your password has been reset successfully.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: SquadColors.muted,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onSignIn,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: SquadColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(
            'Sign in',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
