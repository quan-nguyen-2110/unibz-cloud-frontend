import 'package:flutter/material.dart';

import '../services/api_loading.dart';
import '../theme/squad_theme.dart';

/// Full-screen scrim while any non-silent [ApiClient] request is in flight.
class ApiLoadingOverlay extends StatelessWidget {
  const ApiLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ApiLoading.instance,
      builder: (context, _) {
        if (!ApiLoading.instance.isLoading) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: const Color(0xFFFDF2F7).withValues(alpha: 0.72),
              child: const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: SquadColors.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
