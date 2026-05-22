import '../config/app_config.dart';
import '../mock/mock_users.dart';
import '../models/models.dart';
import '../repositories/api_user_repository.dart';

/// Resolves user display data: mock roster, in-memory cache, then API.
class UserLookup {
  UserLookup({ApiUserRepository? userRepo}) : _userRepo = userRepo ?? ApiUserRepository();

  final ApiUserRepository _userRepo;
  final Map<String, SquadUser> _cache = {};

  void seed(SquadUser user) => _cache[user.id] = user;

  void clear() => _cache.clear();

  SquadUser? cached(String id) => _cache[id] ?? mockUserById(id);

  String displayNameFor(String id) {
    final u = cached(id);
    if (u != null) return u.displayName;
    if (id.length <= 8) return id;
    return 'User';
  }

  Future<SquadUser?> resolve(String id) async {
    final hit = cached(id);
    if (hit != null) return hit;
    if (!AppConfig.useApi) return null;
    final remote = await _userRepo.getUser(id);
    if (remote != null) _cache[id] = remote;
    return remote;
  }

  Future<void> prefetch(Iterable<String> ids) async {
    if (!AppConfig.useApi) return;
    final pending = ids.where((id) => cached(id) == null).toSet();
    if (pending.isEmpty) return;
    await Future.wait(pending.map(resolve));
  }

  Future<List<SquadUser>> usersForIds(Iterable<String> ids) async {
    await prefetch(ids);
    return ids.map(cached).whereType<SquadUser>().toList();
  }
}
