import 'dart:convert';

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
    required this.selectedEmoji,
    required this.emojis,
    required this.onSelect,
  });

  /// `null` = All vibes.
  final String? selectedEmoji;

  /// Distinct emojis from loaded plans (each has at least one plan).
  final List<String> emojis;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final chips = <({String? emoji, VibeStyle style})>[
      (emoji: null, style: kVibeMeta[SquadVibe.all]!),
      for (final emoji in emojis) (emoji: emoji, style: vibeStyleForEmoji(emoji)),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          final meta = chip.style;
          final active = selectedEmoji == chip.emoji;
          final label = chip.emoji == null
              ? '${meta.emoji} ${meta.label}'
              : meta.label.isEmpty
                  ? meta.emoji
                  : '${meta.emoji} ${meta.label}';
          return GestureDetector(
            onTap: () => onSelect(chip.emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: active ? SquadColors.secondary : meta.softBg,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? SquadColors.cardShadow : null,
              ),
              child: Text(
                label,
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
          child: _avatarImage(url, size, _initials),
        ),
      );
    }
    return _initials();
  }

  /// Layout `PhoneShell` Avatar — network URL or `data:` image (edit-profile mock).
  static Widget _avatarImage(
    String url,
    double size,
    Widget Function() onError,
  ) {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma > 0) {
        try {
          final bytes = base64Decode(url.substring(comma + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: size,
            height: size,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => onError(),
          );
        } catch (_) {
          return onError();
        }
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => onError(),
    );
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

/// Rounded header control (layout: `h-11 w-11 rounded-2xl bg-card` on home / notifications).
class SquadHeaderIconButton extends StatelessWidget {
  const SquadHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: SquadColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, size: 22),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: SquadColors.primary,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: SquadColors.card, width: 2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
