import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDraftStore {
  const LocalDraftStore();
  String key(String userId, String companyId, String context) =>
      'qotg.draft.v1.${base64Url.encode(utf8.encode(jsonEncode([
            userId,
            companyId,
            context
          ])))}';

  Future<Map<String, dynamic>?> read(String key) async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return null;
    final envelope = jsonDecode(value) as Map<String, dynamic>;
    if (envelope['version'] != 1 || envelope['fields'] is! Map) {
      throw const FormatException(
          'This saved draft uses an unsupported format.');
    }
    return Map<String, dynamic>.from(envelope['fields'] as Map);
  }

  Future<void> write(String key, Map<String, dynamic> fields) async {
    final value = jsonEncode({
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'fields': fields
    });
    final saved =
        await (await SharedPreferences.getInstance()).setString(key, value);
    if (!saved) throw StateError('The device could not save your draft.');
  }

  Future<void> remove(String key) async {
    final removed = await (await SharedPreferences.getInstance()).remove(key);
    if (!removed) throw StateError('The saved draft could not be cleared.');
  }
}
