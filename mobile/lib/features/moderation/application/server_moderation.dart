import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_json.dart';
import '../../workspace/application/workspace_providers.dart';

class SafetyScope {
  const SafetyScope(this.api, this.account, this.session, this.group);
  final ApiClient api;
  final String account, group;
  final int session;
}

class SafetyCase {
  SafetyCase(Map<String, Object?> data)
    : id = ApiJson.id(data['id']),
      kind = ApiJson.string(data['kind']),
      target = ApiJson.id(data['target_id']),
      version =
          ApiJson.integer(data['version']) ??
          (throw const CircleFailure('Reports changed. Refresh to try again.')),
      summary = ApiJson.optionalString(data['summary']),
      hidden = data['hidden'] == true,
      available = data['available'] == true,
      reasons = ApiJson.list(data['reasons'])
          .map((r) {
            final value = ApiJson.map(r);
            final name = ApiJson.string(value['reason']);
            final reason = ReportReason.values
                .where((v) => v.name == name)
                .firstOrNull;
            return '${reason?.label ?? 'Other'}: ${ApiJson.integer(value['count'])}';
          })
          .join(' · ');
  final String id, kind, target, reasons;
  final int version;
  final String? summary;
  final bool hidden, available;
  bool get hideable => kind == 'memory' || kind == 'comment';
}

class SafetyPage {
  SafetyPage(this.scope, Map<String, Object?> data)
    : items = ApiJson.list(
        data['items'],
      ).map((v) => SafetyCase(ApiJson.map(v))).toList(),
      more = data['has_more'] == true,
      audit = ApiJson.list(data['audit']).map(ApiJson.map).toList();
  final SafetyScope scope;
  final List<SafetyCase> items;
  final bool more;
  final List<Map<String, Object?>> audit;
}

void checkSafetyScope(Ref ref, SafetyScope scope) {
  if (!ref.mounted ||
      !identical(ref.read(apiClientProvider), scope.api) ||
      scope.api.sessionRevision != scope.session ||
      ref.read(serverAccountProvider)?.id != scope.account ||
      ref
              .read(circleWorkspaceProvider)
              .value
              ?.group(scope.group)
              ?.roleOf(scope.account)
              ?.isAdmin !=
          true) {
    throw const CircleFailure('Only current group admins can review reports.');
  }
}

final safetyPageProvider = FutureProvider.autoDispose
    .family<SafetyPage, ({String group, int offset})>((ref, query) async {
      final api = ref.watch(apiClientProvider),
          account = ref.watch(serverAccountProvider);
      ref.watch(
        circleWorkspaceProvider.select(
          (v) => v.value?.group(query.group)?.roleOf(account?.id ?? ''),
        ),
      );
      if (api == null || account == null) {
        throw const CircleFailure('Sign in to review reports.');
      }
      final scope = SafetyScope(
        api,
        account.id,
        api.sessionRevision,
        query.group,
      );
      checkSafetyScope(ref, scope);
      final data = ApiJson.map(
        await api.get(
          '/groups/${query.group}/reports',
          query: {'offset': query.offset, 'limit': 30},
          expectedAccount: scope.account,
          expectedSession: scope.session,
        ),
      );
      checkSafetyScope(ref, scope);
      return SafetyPage(scope, data);
    }, retry: (_, _) => null);
final safetyActionsProvider = Provider((ref) => SafetyActions(ref));

class SafetyActions {
  SafetyActions(this.ref);
  final Ref ref;
  Future<void> act(
    SafetyPage page,
    SafetyCase item,
    String action, {
    int? version,
  }) async {
    checkSafetyScope(ref, page.scope);
    await page.scope.api.post(
      '/groups/${page.scope.group}/reports/${item.id}/actions',
      body: {'action': action, 'version': version ?? item.version},
      expectedAccount: page.scope.account,
      expectedSession: page.scope.session,
    );
    checkSafetyScope(ref, page.scope);
  }
}
