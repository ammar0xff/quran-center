import 'package:quran_center/core/sync/outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps each user's outbox in the device's preferences, under their own key.
class SharedPrefsOutboxStorage implements OutboxStorage {
  String _key(String owner) => 'outbox_v1_$owner';

  @override
  Future<String?> read(String owner) async =>
      (await SharedPreferences.getInstance()).getString(_key(owner));

  @override
  Future<void> write(String owner, String json) async {
    await (await SharedPreferences.getInstance()).setString(_key(owner), json);
  }
}
