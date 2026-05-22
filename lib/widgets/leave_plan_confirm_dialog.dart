import 'package:flutter/material.dart';

import '../theme/squad_theme.dart';

/// Same copy and actions as plan detail — used from feed cards too.
void showLeavePlanConfirmDialog({
  required BuildContext context,
  required String planTitle,
  required VoidCallback onConfirmLeave,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Cancel your spot?'),
      content: Text(
        'You\'ll leave "$planTitle". You can rejoin if there\'s still space.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Stay in'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: SquadColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            onConfirmLeave();
            Navigator.pop(ctx);
          },
          child: const Text('Leave plan'),
        ),
      ],
    ),
  );
}
