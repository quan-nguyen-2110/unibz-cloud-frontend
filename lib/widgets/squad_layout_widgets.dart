import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/squad_theme.dart';
import '../data/vibe_catalog.dart';
import '../models/models.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.titleHighlight,
    this.subtitle,
    this.trailing,
  });

  final String title;
  /// Substring of [title] to paint with primary color (e.g. "down?" in "Anyone down?").
  final String? titleHighlight;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget titleWidget;
    if (titleHighlight != null && title.contains(titleHighlight!)) {
      final i = title.indexOf(titleHighlight!);
      titleWidget = Text.rich(
        TextSpan(
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: SquadColors.text,
            height: 1.05,
            letterSpacing: -0.5,
          ),
          children: [
            TextSpan(text: title.substring(0, i)),
            TextSpan(
              text: titleHighlight,
              style: const TextStyle(color: SquadColors.primary),
            ),
            TextSpan(text: title.substring(i + titleHighlight!.length)),
          ],
        ),
      );
    } else {
      titleWidget = Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: SquadColors.text,
          height: 1.05,
          letterSpacing: -0.5,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                if (subtitle case final s?) ...[
                  const SizedBox(height: 6),
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: 14,
                      color: SquadColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class VibeChipRow extends StatelessWidget {
  const VibeChipRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final SquadVibe selected;
  final ValueChanged<SquadVibe> onSelect;

  @override
  Widget build(BuildContext context) {
    const order = [
      SquadVibe.all,
      SquadVibe.hoops,
      SquadVibe.swim,
      SquadVibe.cafe,
      SquadVibe.study,
      SquadVibe.gaming,
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: order.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final v = order[i];
          final meta = kVibeMeta[v]!;
          final active = selected == v;
          return GestureDetector(
            onTap: () => onSelect(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: active ? SquadColors.secondary : meta.softBg,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? SquadColors.cardShadow : null,
              ),
              child: Text(
                '${meta.emoji} ${meta.label}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : meta.softFg,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SquadUserAvatar extends StatelessWidget {
  const SquadUserAvatar({
    super.key,
    required this.user,
    this.size = 44,
  });

  final SquadUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SquadColors.card, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => _initials(),
          ),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    return SquadInitialsAvatar(
      initials: displayInitials(user.displayName),
      background: avatarColorForKey(user.id),
      size: size,
    );
  }
}

class SquadInitialsAvatar extends StatelessWidget {
  const SquadInitialsAvatar({
    super.key,
    required this.initials,
    required this.background,
    this.size = 44,
  });

  final String initials;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: SquadColors.card, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

String displayInitials(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  final p = parts.isNotEmpty ? parts[0] : '';
  if (p.length >= 2) return p.substring(0, 2).toUpperCase();
  if (p.isNotEmpty) return p[0].toUpperCase();
  return '?';
}

Color avatarColorForKey(String key) {
  const colors = [
    SquadColors.primary,
    SquadColors.secondary,
    SquadColors.hoops,
    SquadColors.swim,
    SquadColors.cafe,
    SquadColors.study,
    SquadColors.gaming,
  ];
  var h = 0;
  for (var i = 0; i < key.length; i++) {
    h += key.codeUnitAt(i);
  }
  return colors[h % colors.length];
}
