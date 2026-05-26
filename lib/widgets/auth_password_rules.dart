// Shared with squadUp-layout signup.tsx + forgot-password.tsx PW_RULES

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/squad_theme.dart';

class AuthPasswordRule {
  const AuthPasswordRule(this.label, this.test);
  final String label;
  final bool Function(String) test;
}

final List<AuthPasswordRule> authPasswordRules = [
  AuthPasswordRule('At least 8 characters', (p) => p.length >= 8),
  AuthPasswordRule('One uppercase letter', (p) => RegExp(r'[A-Z]').hasMatch(p)),
  AuthPasswordRule('One lowercase letter', (p) => RegExp(r'[a-z]').hasMatch(p)),
  AuthPasswordRule('One number', (p) => RegExp(r'\d').hasMatch(p)),
];

bool authPasswordRulesOk(String password) =>
    authPasswordRules.every((r) => r.test(password));

/// Layout: 2-column checklist under password field (green dot when met).
class AuthPasswordRulesList extends StatelessWidget {
  const AuthPasswordRulesList({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final columnWidth = (MediaQuery.sizeOf(context).width - 48 - 8) / 2;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: authPasswordRules.map((rule) {
        final ok = rule.test(password);
        return SizedBox(
          width: columnWidth,
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ok
                      ? SquadColors.success
                      : SquadColors.muted.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rule.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: ok ? SquadColors.success : SquadColors.muted,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
