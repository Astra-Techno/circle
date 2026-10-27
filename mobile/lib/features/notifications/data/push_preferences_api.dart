import '../../../core/api/api_client.dart';
import '../../../core/api/api_json.dart';
import '../domain/push_preferences.dart';

export '../domain/push_preferences.dart';

/// Does not initialize Firebase or request permissions. Session-scoped API
/// instances are supplied by the application layer during push integration.
class PushPreferencesApi {
  PushPreferencesApi(this.client, {this.accountId});
  final String? accountId;
  final ApiClient client;
  static const path = '/me/notification-preferences';

  Future<PushPreferences> load() async =>
      _decode(await client.get(path, expectedAccount: accountId));

  Future<PushPreferences> update({
    bool? enabled,
    Map<PushCategory, bool>? categories,
    bool? quietHours,
    int? quietStart,
    int? quietEnd,
    String? timezone,
  }) async => _decode(
    await client.patch(
      path,
      expectedAccount: accountId,
      body: {
        'enabled': ?enabled,
        if (categories != null)
          'categories': {
            for (final entry in categories.entries)
              _key(entry.key): entry.value,
          },
        'quiet_hours': ?quietHours,
        'quiet_start': ?quietStart,
        'quiet_end': ?quietEnd,
        'timezone': ?timezone,
      },
    ),
  );

  Future<void> registerDevice(String token, PushDevicePlatform platform) async {
    await client.post(
      '/devices/register',
      body: {'fcm_token': token, 'platform': platform.name},
    );
  }

  Future<void> unregisterDevice(String token) async {
    await client.post('/devices/unregister', body: {'fcm_token': token});
  }

  static String _key(PushCategory category) =>
      category == PushCategory.repliesReactions
      ? 'replies_reactions'
      : category.name;

  static PushPreferences _decode(Object? value) {
    final json = ApiJson.map(value),
        categories = ApiJson.map(ApiJson.map(value)['categories']);
    bool boolean(Object? value) => value is bool ? value : ApiJson.unexpected();
    int minute(Object? value) => value is int && value >= 0 && value < 1440
        ? value
        : ApiJson.unexpected();
    final timezone = json['timezone'];
    if (timezone is! String || timezone.isEmpty || timezone.length > 64) {
      ApiJson.unexpected();
    }
    final start = minute(json['quiet_start']), end = minute(json['quiet_end']);
    if (start == end) ApiJson.unexpected();
    return PushPreferences(
      enabled: boolean(json['enabled']),
      categories: {
        for (final category in PushCategory.values)
          category: boolean(categories[_key(category)]),
      },
      quietHours: boolean(json['quiet_hours']),
      quietStart: start,
      quietEnd: end,
      timezone: timezone,
    );
  }
}
