import 'package:quran_center/data/models/user.dart';

/// Repository for [User] profiles (authoritative account/role state).
///
/// Role is backend-authoritative; this repository is the only path for reading
/// and provisioning user profiles. Clients must not write roles directly.
abstract class UserRepository {
  /// Get a user by Firebase Auth uid. Returns null if not found.
  Future<User?> getUser(String uid);

  /// Create a new user profile (trusted provisioning only).
  Future<void> createUser(User user);

  /// Update an existing user profile.
  Future<void> updateUser(User user);

  /// Stream of active users in a center (real-time).
  Stream<List<User>> watchUsersByCenter(String centerId);

  /// Future list of active users in a center.
  Future<List<User>> getUsersByCenter(String centerId);
}
