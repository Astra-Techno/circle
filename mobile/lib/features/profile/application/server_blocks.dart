import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_json.dart';
import '../../workspace/application/workspace_providers.dart';

class BlockScope {
  const BlockScope(this.api, this.account, this.session);
  final ApiClient api;
  final String account;
  final int session;
}

BlockScope blockScope(Ref ref) {
  final api = ref.read(apiClientProvider),
      account = ref.read(serverAccountProvider);
  if (api == null || account == null) {
    throw const CircleFailure('Sign in to manage blocking.');
  }
  return BlockScope(api, account.id, api.sessionRevision);
}

void checkBlockScope(Ref ref, BlockScope scope) {
  if (!ref.mounted ||
      !identical(ref.read(apiClientProvider), scope.api) ||
      ref.read(serverAccountProvider)?.id != scope.account ||
      scope.api.sessionRevision != scope.session) {
    throw const CircleFailure('Your session changed. Open blocking again.');
  }
}

final blockStateProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  id,
) async {
  ref.watch(apiClientProvider);
  ref.watch(serverAccountProvider);
  final scope = blockScope(ref);
  final result = ApiJson.map(
    await scope.api.get(
      '/me/blocks/$id',
      expectedAccount: scope.account,
      expectedSession: scope.session,
    ),
  );
  checkBlockScope(ref, scope);
  return result['blocked'] == true;
}, retry: (_, _) => null);

class BlockPage {
  BlockPage(this.scope, Map<String, Object?> data)
    : items = ApiJson.list(data['items']).map(ApiJson.map).toList(),
      more = data['has_more'] == true;
  final BlockScope scope;
  final List<Map<String, Object?>> items;
  final bool more;
}

final blockPageProvider = FutureProvider.autoDispose.family<BlockPage, int>((
  ref,
  offset,
) async {
  ref.watch(apiClientProvider);
  ref.watch(serverAccountProvider);
  final scope = blockScope(ref);
  final result = ApiJson.map(
    await scope.api.get(
      '/me/blocks',
      query: {'offset': offset, 'limit': 30},
      expectedAccount: scope.account,
      expectedSession: scope.session,
    ),
  );
  checkBlockScope(ref, scope);
  return BlockPage(scope, result);
}, retry: (_, _) => null);
final blockActionsProvider = Provider((ref) => BlockActions(ref));

class BlockActions {
  BlockActions(this.ref);
  final Ref ref;
  BlockScope capture() => blockScope(ref);
  Future<void> change(
    BlockScope scope,
    String person, {
    required bool blocked,
  }) async {
    checkBlockScope(ref, scope);
    if (blocked) {
      await scope.api.put(
        '/me/blocks/$person',
        body: <String, Object?>{},
        expectedAccount: scope.account,
        expectedSession: scope.session,
      );
    } else {
      await scope.api.delete(
        '/me/blocks/$person',
        expectedAccount: scope.account,
        expectedSession: scope.session,
      );
    }
    checkBlockScope(ref, scope);
    ref.invalidate(blockStateProvider);
    ref.invalidate(blockPageProvider);
    checkBlockScope(ref, scope);
  }
}
