// Migrated from squadUp-layout/src/routes/profile.$userId.tsx (9b5809d)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import 'auth_flow_widgets.dart';
import 'squad_layout_widgets.dart';

/// Shows edit-profile sheet. Returns updated [SquadUser] on save, null if cancelled.
Future<SquadUser?> showEditProfileDialog(
  BuildContext context, {
  required SquadUser user,
}) {
  return showDialog<SquadUser>(
    context: context,
    builder: (ctx) => _EditProfileDialog(initial: user),
  );
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initial});

  final SquadUser initial;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _location;
  late final TextEditingController _bio;
  late final TextEditingController _interests;

  late String? _avatarUrl;
  final ImagePicker _imagePicker = ImagePicker();

  bool _saving = false;
  String? _error;

  static const _bioMaxApi = 200;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    _name = TextEditingController(text: u.displayName);
    _age = TextEditingController(text: u.age?.toString() ?? '');
    _location = TextEditingController(
      text: u.profileLocation ?? (u.city.isNotEmpty ? u.city : ''),
    );
    _bio = TextEditingController(text: u.bio ?? '');
    _interests = TextEditingController(text: (u.interests ?? []).join(', '));
    _avatarUrl = u.avatarUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _location.dispose();
    _bio.dispose();
    _interests.dispose();
    super.dispose();
  }

  SquadUser get _previewUser => SquadUser(
        id: widget.initial.id,
        username: widget.initial.username,
        displayName: _name.text.trim().isEmpty
            ? widget.initial.displayName
            : _name.text.trim(),
        phone: widget.initial.phone,
        city: widget.initial.city,
        avatarEmoji: widget.initial.avatarEmoji,
        avatarUrl: _avatarUrl,
      );

  Future<void> _pickAvatar() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? 'image/jpeg';
    setState(() {
      _avatarUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _save() async {
    setState(() => _error = null);

    final trimmedName = _name.text.trim();
    final ageNum = int.tryParse(_age.text.trim());
    final bio = _bio.text.trim();

    if (trimmedName.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (trimmedName.length > 40) {
      setState(() => _error = 'Name is too long');
      return;
    }
    if (ageNum == null || ageNum < 13 || ageNum > 120) {
      setState(() => _error = 'Enter a valid age');
      return;
    }
    if (bio.length > _bioMaxApi) {
      setState(() => _error = 'Bio must be $_bioMaxApi characters or less');
      return;
    }

    final interestList = _interests.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(10)
        .toList();

    final location = _location.text.trim();

    setState(() => _saving = true);
    try {
      final app = context.read<AppState>();
      final updated = await app.updateMyProfile(
        displayName: trimmedName,
        bio: bio.isEmpty ? '' : bio,
        age: ageNum,
        profileLocation: location.isEmpty ? null : location,
        interests: interestList,
        avatarUrl: _avatarUrl,
        replaceAvatar: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 352),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SquadUserAvatar(user: _previewUser, size: 80),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color: SquadColors.primary,
                            shape: const CircleBorder(),
                            elevation: 2,
                            shadowColor:
                                SquadColors.primary.withValues(alpha: 0.25),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickAvatar,
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: Icon(
                                  Icons.photo_camera_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _avatarUrl = null),
                        style: TextButton.styleFrom(
                          foregroundColor: SquadColors.muted,
                        ),
                        child: Text(
                          'Remove photo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const AuthFieldLabel('Name'),
                const SizedBox(height: 6),
                _dialogField(controller: _name, maxLength: 40),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthFieldLabel('Age'),
                          const SizedBox(height: 6),
                          _dialogField(
                            controller: _age,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthFieldLabel('Location'),
                          const SizedBox(height: 6),
                          _dialogField(
                            controller: _location,
                            maxLength: 60,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const AuthFieldLabel('Bio'),
                const SizedBox(height: 6),
                TextField(
                  controller: _bio,
                  maxLines: 3,
                  maxLength: _bioMaxApi,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SquadColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: SquadColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: SquadColors.border),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_bio.text.length}/$_bioMaxApi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: SquadColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const AuthFieldLabel('Interests'),
                const SizedBox(height: 6),
                _dialogField(
                  controller: _interests,
                  hint: 'Hoops, Cafes, Swim',
                ),
                Text(
                  'Separate with commas',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: SquadColors.muted,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 14, color: SquadColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SquadColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: SquadColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          _saving ? 'Saving…' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    String? hint,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: SquadColors.inputFill,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SquadColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SquadColors.border),
        ),
      ),
    );
  }
}
