import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/scoped_api.dart';
import '../../workspace/application/workspace_providers.dart';
export '../../../core/api/api_json.dart';

final livePollApiProvider = Provider<LivePollApi>((ref) {
  final api = ref.watch(apiClientProvider),
      account = ref.watch(serverAccountProvider.select((a) => a?.id));
  if (api == null || account == null) {
    throw const CircleFailure('Sign in to open polls.');
  }
  return LivePollApi(
    ScopedApi(
      api,
      account,
      api.sessionRevision,
      () =>
          ref.mounted &&
          identical(ref.read(apiClientProvider), api) &&
          ref.read(serverAccountProvider)?.id == account,
    ),
  );
});

class LivePollApi {
  LivePollApi(this.scope);
  final ScopedApi scope;
  Future<Map<String, Object?>> list(
    ({String? group, String? event, int offset}) p,
  ) => scope.get(
    '/polls',
    query: {
      'group_id': ?p.group,
      'event_id': ?p.event,
      'offset': p.offset,
      'limit': 30,
    },
  );
  Future<Map<String, Object?>> detail(String id) => scope.get('/polls/$id');
  Future<Map<String, Object?>> create(
    String group,
    Map<String, Object?> body,
  ) => scope.change('POST', '/groups/$group/polls', body);
  Future<Map<String, Object?>> vote(String id, List<int> ids) =>
      scope.change('PUT', '/polls/$id/votes', {'option_ids': ids});
  Future<Map<String, Object?>> close(String id) =>
      scope.change('POST', '/polls/$id/close', {});
  Future<Map<String, Object?>> option(String id, String label) =>
      scope.change('POST', '/polls/$id/options', {'label': label});
  Future<Map<String, Object?>> voters(String id, int offset) =>
      scope.get('/polls/$id/voters', query: {'offset': offset, 'limit': 30});
}

final livePollsProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, ({String? group, String? event, int offset})>(
      (ref, p) => ref.watch(livePollApiProvider).list(p),
      retry: (_, _) => null,
    );
final livePollProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>(
      (ref, id) => ref.watch(livePollApiProvider).detail(id),
      retry: (_, _) => null,
    );
final livePollVotersProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, ({String id, int offset})>(
      (ref, p) => ref.watch(livePollApiProvider).voters(p.id, p.offset),
      retry: (_, _) => null,
    );
