// Migrated from squadUp-layout/src/routes/verify.tsx (commit 0d8534d)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../theme/squad_theme.dart';
import '../widgets/auth_flow_widgets.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

const _codeLength = 6;

/// Masks email for display: `jo••••••@example.com`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final local = email.substring(0, at);
  final domain = email.substring(at);
  if (local.length <= 2) {
    return '${local[0]}${'•' * 3}$domain';
  }
  final hidden = '•' * (local.length - 2).clamp(3, 12);
  return '${local.substring(0, 2)}$hidden$domain';
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _auth = AuthService();
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());
  final _controllers = List.generate(_codeLength, (_) => TextEditingController());

  bool _loading = false;
  bool _resending = false;
  String? _error;
  int? _resentAt;
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
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _resentAt = DateTime.now().millisecondsSinceEpoch;
      _cooldown = 30;
    });
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
    final jump = (i).clamp(0, _codeLength - 1);
    _focusNodes[jump].requestFocus();
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

    setState(() => _loading = true);
    try {
      if (AppConfig.useApi && !AppConfig.useDevAuth) {
        await _auth.confirmSignUp(email: widget.email, code: _code);
      } else {
        try {
          await _auth.confirmSignUp(email: widget.email, code: _code);
        } on AuthException {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LoginScreen(
            initialEmail: widget.email,
            emailVerified: true,
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() {
      _error = null;
      _resending = true;
    });
    try {
      if (AppConfig.useApi && !AppConfig.useDevAuth) {
        await _auth.resendConfirmationCode(widget.email);
      } else {
        try {
          await _auth.resendConfirmationCode(widget.email);
        } on AuthException {
          // layout stub — cooldown only
        }
      }
      _startCooldown();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = widget.email.isNotEmpty ? maskEmail(widget.email) : 'your email';

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
                    icon: Icons.mark_email_read_rounded,
                    title: 'Check your inbox',
                    subtitle: 'We sent a 6-digit code to\n$masked',
                    topPadding: 64,
                    bottomPadding: 40,
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: _VerifyFormCard(
                        controllers: _controllers,
                        focusNodes: _focusNodes,
                        loading: _loading,
                        error: _error,
                        cooldown: _cooldown,
                        showResentHint: _resentAt != null && _cooldown > 0,
                        onDigit: _setDigit,
                        onPaste: _applyPastedCode,
                        onSubmit: _submit,
                        onResend: _resend,
                        onBackToSignup: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
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

class _VerifyFormCard extends StatelessWidget {
  const _VerifyFormCard({
    required this.controllers,
    required this.focusNodes,
    required this.loading,
    required this.error,
    required this.cooldown,
    required this.showResentHint,
    required this.onDigit,
    required this.onPaste,
    required this.onSubmit,
    required this.onResend,
    required this.onBackToSignup,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool loading;
  final String? error;
  final int cooldown;
  final bool showResentHint;
  final void Function(int index, String value) onDigit;
  final void Function(String text) onPaste;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final VoidCallback onBackToSignup;

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
            const AuthFieldLabel('Confirmation code'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_codeLength, (i) {
                return SizedBox(
                  width: 48,
                  height: 56,
                  child: TextField(
                    controller: controllers[i],
                    focusNode: focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    autofillHints: i == 0
                        ? const [AutofillHints.oneTimeCode]
                        : null,
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
                        onPaste(v);
                        return;
                      }
                      if (v.isEmpty && i > 0) {
                        focusNodes[i - 1].requestFocus();
                      }
                      onDigit(i, v);
                    },
                    onSubmitted: (_) {
                      if (i == _codeLength - 1) onSubmit();
                    },
                  ),
                );
              }),
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
                loading ? 'Verifying…' : 'Verify & continue',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: SquadColors.muted,
                ),
                children: [
                  const TextSpan(text: "Didn't get a code? "),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: cooldown > 0 ? null : onResend,
                      child: Text(
                        cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cooldown > 0
                              ? SquadColors.muted
                              : SquadColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showResentHint) ...[
              const SizedBox(height: 8),
              Text(
                'A fresh code is on its way.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: SquadColors.muted,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: SquadColors.muted,
                ),
                children: [
                  const TextSpan(text: 'Wrong email? '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onBackToSignup,
                      child: Text(
                        'Go back',
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
          ],
        ),
      ),
    );
  }
}
