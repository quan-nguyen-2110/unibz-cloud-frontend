import 'package:flutter/material.dart';

import '../theme/squad_theme.dart';

void showCancelPlanConfirmDialog({
  required BuildContext context,
  required String planTitle,
  required VoidCallback onConfirmCancel,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Cancel this plan?'),
      content: Text(
        '"$planTitle" will be called off and everyone who joined will be notified. You can\'t undo this.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep plan'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: SquadColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            onConfirmCancel();
            Navigator.pop(ctx);
          },
          child: const Text('Yes, cancel it'),
        ),
      ],
    ),
  );
}
