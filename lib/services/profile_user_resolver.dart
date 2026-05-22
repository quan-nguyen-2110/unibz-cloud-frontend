import '../models/models.dart';
import 'user_lookup.dart';

/// Resolves a [SquadUser] for profile screens: cache, mock roster, then API.
Future<SquadUser?> resolveProfileUser(
  String userId, {
  SquadUser? currentUser,
  UserLookup? lookup,
}) async {
  final lu = lookup ?? UserLookup();
  final cached = lu.cached(userId);
  if (cached != null) return cached;

  if (currentUser?.id == userId) {
    final me = await lu.resolve(userId);
    return me ?? currentUser;
  }

  return lu.resolve(userId);
}
