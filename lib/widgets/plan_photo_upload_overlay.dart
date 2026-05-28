import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/squad_theme.dart';

/// Loading UI while plan photos upload (presign → S3 → confirm).
class PlanPhotoUploadIndicator extends StatelessWidget {
  const PlanPhotoUploadIndicator({
    super.key,
    required this.progress,
    this.compact = false,
  });

  final PlanPhotoUploadProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final total = progress.total;
    final value = total > 0 ? progress.completed / total : null;

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              value: progress.syncing ? null : value,
              color: SquadColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progress.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SquadColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progress.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: SquadColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            value: progress.syncing ? null : value,
            color: SquadColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          progress.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: SquadColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          progress.subtitle,
          style: TextStyle(
            fontSize: 14,
            color: SquadColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Full-screen scrim used on Create while posting / uploading photos.
class PlanPhotoUploadScreenOverlay extends StatelessWidget {
  const PlanPhotoUploadScreenOverlay({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
  });

  final String title;
  final String? subtitle;
  final PlanPhotoUploadProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: ColoredBox(
          color: const Color(0xFFFDF2F7).withValues(alpha: 0.88),
          child: Center(
            child: progress != null
                ? PlanPhotoUploadIndicator(progress: progress!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: SquadColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SquadColors.text,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: SquadColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
