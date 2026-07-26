import 'package:shared_preferences/shared_preferences.dart';

class SummaryWatermarkRepository {
  static const _key = 'activity_summary_watermark';

  Future<DateTime?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> save(DateTime watermark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, watermark.millisecondsSinceEpoch);
  }
}
