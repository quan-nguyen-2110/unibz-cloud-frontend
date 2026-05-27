import 'package:flutter/material.dart';

import '../theme/squad_theme.dart';

/// Migrated from squadUp-layout `plan.$planId.tsx` remove attendee dialog (0e57c36).
void showRemoveAttendeeConfirmDialog({
  required BuildContext context,
  required String attendeeName,
  required String planTitle,
  required VoidCallback onConfirmRemove,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Remove $attendeeName?'),
      content: Text(
        'They\'ll be taken off "$planTitle" and notified. Their spot opens back up.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep them'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: SquadColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            onConfirmRemove();
            Navigator.pop(ctx);
          },
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}
