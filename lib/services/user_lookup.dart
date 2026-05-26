import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/api_json.dart';
import '../repositories/api_user_repository.dart';
import 'api_client.dart';

/// In-memory cache of users resolved from the API.
class UserLookup {
  UserLookup({ApiUserRepository? userRepo}) : _userRepo = userRepo ?? ApiUserRepository();

  final ApiUserRepository _userRepo;
  final Map<String, SquadUser> _cache = {};
  final Set<String> _unresolvedIds = {};
  final Map<String, Future<SquadUser?>> _inFlight = {};

  void seed(SquadUser user) {
    _cache[user.id] = user;
    _unresolvedIds.remove(user.id);
  }

  void clear() {
    _cache.clear();
    _unresolvedIds.clear();
    _inFlight.clear();
  }

  void resetUnresolved(Iterable<String> ids) {
    for (final id in ids) {
      _unresolvedIds.remove(id.trim());
    }
  }

  void seedProfiles(Iterable<Map<String, dynamic>> profiles) {
    for (final raw in profiles) {
      try {
        seed(squadUserFromJson(raw));
      } catch (e, st) {
        debugPrint('UserLookup.seedProfiles skip: $e\n$st');
      }
    }
  }

  SquadUser? cached(String id) => _cache[id];

  String displayNameFor(String id) {
    final u = cached(id);
    if (u != null) return u.displayName;
    if (id.length <= 8) return id;
    return 'User';
  }

  Future<SquadUser?> resolve(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;

    final hit = cached(trimmed);
    if (hit != null) return hit;
    if (_unresolvedIds.contains(trimmed)) return null;

    final existing = _inFlight[trimmed];
    if (existing != null) return existing;

    final future = _fetchUser(trimmed);
    _inFlight[trimmed] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(trimmed);
    }
  }

  Future<SquadUser?> _fetchUser(String id) async {
    try {
      final remote = await _userRepo.getUser(id);
      if (remote != null) {
        _cache[id] = remote;
        _unresolvedIds.remove(id);
        return remote;
      }
      _unresolvedIds.add(id);
      return null;
    } on ApiException catch (e) {
      debugPrint('UserLookup.resolve ApiException ($id): ${e.statusCode} ${e.message}');
      _unresolvedIds.add(id);
      return null;
    } catch (e, st) {
      debugPrint('UserLookup.resolve error ($id): $e\n$st');
      _unresolvedIds.add(id);
      return null;
    }
  }

  Future<void> prefetch(Iterable<String> ids) async {
    final pending = ids
        .map((id) => id.trim())
        .where(
          (id) =>
              id.isNotEmpty &&
              cached(id) == null &&
              !_unresolvedIds.contains(id) &&
              !_inFlight.containsKey(id),
        )
        .toSet();
    if (pending.isEmpty) return;

    await Future.wait(
      pending.map((id) async {
        try {
          await resolve(id);
        } catch (e, st) {
          debugPrint('UserLookup.prefetch failed for $id: $e\n$st');
        }
      }),
    );
  }

  Future<List<SquadUser>> usersForIds(Iterable<String> ids) async {
    await prefetch(ids);
    return ids.map(cached).whereType<SquadUser>().toList();
  }
}
