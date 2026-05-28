import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import 'plan_photo_upload_overlay.dart';

/// Plan detail gallery — layout parity with `plan.$planId.tsx`.
class PlanPhotosSection extends StatelessWidget {
  const PlanPhotosSection({
    super.key,
    required this.plan,
    required this.canUpload,
  });

  final SquadPlan plan;
  final bool canUpload;

  static const _maxPick = 10;

  Future<void> _pickAndUpload(BuildContext context) async {
    final app = context.read<AppState>();
    if (app.isUploadingPlanPhotos(plan.id)) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 85,
      limit: _maxPick,
    );
    if (picked.isEmpty || !context.mounted) return;
    try {
      await app.uploadPlanPhotos(plan.id, picked);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${picked.length} photo${picked.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photos.')),
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    PlanPhoto photo,
  ) async {
    final app = context.read<AppState>();
    if (app.isUploadingPlanPhotos(plan.id)) return;
    try {
      await app.removePlanPhoto(plan.id, photo.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete photos you uploaded.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final uid = app.currentUser?.id;
    final photos = plan.photos;
    final started = plan.hasStarted;
    final uploading = app.isUploadingPlanPhotos(plan.id);
    final uploadProgress = app.planPhotoUploadProgress;

    if (photos.isEmpty && !canUpload && !uploading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SquadColors.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: SquadColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'PHOTOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SquadColors.muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      started
                          ? 'Live · attendees can add'
                          : 'Available once the plan starts',
                      style: TextStyle(fontSize: 11, color: SquadColors.muted),
                    ),
                  ],
                ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, i) {
                      final ph = photos[i];
                      final mine = uid != null && ph.uploaderId == uid;
                      final spanFull = photos.length == 1 ||
                          (photos.length == 3 && i == 0);
                      return GridTile(
                        child: AspectRatio(
                          aspectRatio: spanFull ? 16 / 9 : 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  ph.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => ColoredBox(
                                    color: SquadColors.mutedBg,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: SquadColors.muted,
                                    ),
                                  ),
                                ),
                                if (mine && canUpload && !uploading)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Material(
                                      color: SquadColors.card
                                          .withValues(alpha: 0.92),
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _remove(context, ph),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.close, size: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (mine)
                                  Positioned(
                                    left: 6,
                                    bottom: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SquadColors.card
                                            .withValues(alpha: 0.92),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'You',
                                        style: TextStyle(
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
                    },
                  ),
                ],
                if (canUpload) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () => _pickAndUpload(context),
                    icon: uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      uploading ? 'Uploading…' : 'Add photos',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (uploading && uploadProgress != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: SquadColors.card.withValues(alpha: 0.92),
                  child: Center(
                    child: PlanPhotoUploadIndicator(
                      progress: uploadProgress,
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
