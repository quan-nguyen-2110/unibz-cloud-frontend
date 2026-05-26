import '../models/models.dart';
import 'user_lookup.dart';

/// Resolves a [SquadUser] for profile screens: cache then API.
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

/// Profile location line: [profileLocation] first, then [city].
String profileLocationLine(SquadUser user) {
  final loc = user.profileLocation?.trim();
  if (loc != null && loc.isNotEmpty) return loc;
  final city = user.city.trim();
  return city.isNotEmpty ? city : '';
}

/// When viewing your own profile, [current] holds edited age, bio, interests, etc.
SquadUser mergeProfileWithCurrentUser(SquadUser base, SquadUser? current) {
  if (current == null || current.id != base.id) return base;
  return SquadUser(
    id: base.id,
    username: base.username.isNotEmpty ? base.username : current.username,
    displayName: current.displayName,
    phone: base.phone.isNotEmpty ? base.phone : current.phone,
    city: base.city.isNotEmpty ? base.city : current.city,
    avatarEmoji: current.avatarEmoji,
    age: current.age,
    genderLabel: current.genderLabel ?? base.genderLabel,
    bio: current.bio,
    interests: current.interests,
    profileLocation: current.profileLocation,
    avatarUrl: base.avatarUrl ?? current.avatarUrl,
  );
}
