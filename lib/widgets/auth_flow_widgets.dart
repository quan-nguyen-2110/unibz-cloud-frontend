import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/squad_theme.dart';

/// Shared auth UI — `squadUp-layout` `login.tsx` / `signup.tsx` (512d5bf).

class AuthBlurOrb extends StatelessWidget {
  const AuthBlurOrb({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: 200,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    this.emoji,
    this.icon,
    required this.title,
    required this.subtitle,
    this.topPadding = 48,
    this.bottomPadding = 40,
  }) : assert(emoji != null || icon != null);

  final String? emoji;
  final IconData? icon;
  final String title;
  final String subtitle;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
      decoration: const BoxDecoration(gradient: SquadColors.ctaGradient),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: AuthBlurOrb(color: Colors.white.withValues(alpha: 0.2)),
          ),
          Positioned(
            bottom: -70,
            left: -40,
            child: AuthBlurOrb(
              color: SquadColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          Column(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: SquadColors.primaryGlowShadow,
                ),
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(icon, size: 28, color: SquadColors.primary)
                    : Text(emoji!, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: SquadColors.muted,
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    required this.prefix,
    this.suffix,
    this.onChanged,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SquadColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SquadColors.border),
      ),
      child: Row(
        children: [
          Icon(prefix, size: 18, color: SquadColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              onChanged: onChanged,
              maxLength: maxLength,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: SquadColors.text,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: SquadColors.muted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }
}

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({super.key, required this.dividerLabel});

  final String dividerLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: SquadColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                dividerLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SquadColors.muted,
                ),
              ),
            ),
            const Expanded(child: Divider(color: SquadColors.border)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Google sign-in — Cognito federated (coming soon)',
                      ),
                    ),
                  );
                },
                icon: const AuthGoogleGlyph(),
                label: const Text('Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Apple sign-in — Cognito federated (coming soon)',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.apple, size: 18),
                label: const Text('Apple'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: SquadColors.text,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AuthGoogleGlyph extends StatelessWidget {
  const AuthGoogleGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _AuthGoogleGlyphPainter()),
    );
  }
}

class _AuthGoogleGlyphPainter extends CustomPainter {
  const _AuthGoogleGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      0,
      3.14,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
