import 'package:flutter/material.dart';

import '../mock/mock_users.dart';
import '../theme/squad_theme.dart';

class AvatarStackWidget extends StatelessWidget {
  const AvatarStackWidget({
    super.key,
    required this.userIds,
    this.max = 4,
  });

  final List<String> userIds;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ids = userIds.take(max).toList();
    if (ids.isEmpty) {
      return Text(
        'Be first',
        style: TextStyle(color: SquadColors.muted.withValues(alpha: 0.9)),
      );
    }
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < ids.length; i++)
            Transform.translate(
              offset: Offset(-10.0 * i, 0),
              child: _bubble(ids[i]),
            ),
        ],
      ),
    );
  }

  Widget _bubble(String id) {
    final u = mockUserById(id);
    final emoji = u?.avatarEmoji ?? '\u{1F464}';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SquadColors.surface2,
        border: Border.all(color: SquadColors.bg, width: 2),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}
