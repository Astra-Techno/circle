import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_json.dart';
import '../../../core/api/scoped_api.dart';
import '../../../core/local_settings.dart';
import 'chat_outbox.dart';
import 'dart:async';
import '../../workspace/application/workspace_providers.dart';
export '../../../core/api/api_json.dart';

final liveChatApiProvider = Provider<LiveChatApi>((ref) {
  final api = ref.watch(apiClientProvider),
      account = ref.watch(serverAccountProvider.select((value) => value?.id));
  if (api == null || account == null) {
    throw const CircleFailure('Sign in to open chats.');
  }
  final session = api.sessionRevision;
  final client = LiveChatApi(
    ScopedApi(
      api,
      account,
      session,
      () =>
          ref.mounted &&
          identical(ref.read(apiClientProvider), api) &&
          ref.read(serverAccountProvider)?.id == account,
    ),
  );
  client.outbox = ChatOutbox(
    client.scope,
    ref.read(localSettingsStoreProvider),
  );
  ref.onDispose(
    () => unawaited(client.outbox.dispose().catchError((Object _) {})),
  );
  return client;
});

class LiveChatApi {
  LiveChatApi(this.scope);
  final ScopedApi scope;
  late final ChatOutbox outbox;
  final _groups = <String, String>{};
  Future<String> resolve(String id) async {
    if (!id.startsWith('g-')) return id;
    return _groups[id] ??= ApiJson.id(
      (await scope.get('/groups/${id.substring(2)}/chat'))['id'],
    );
  }

  Future<Map<String, Object?>> inbox(int offset) =>
      scope.get('/chats', query: {'offset': offset, 'limit': 30});
  Future<Map<String, Object?>> read(String id, int? before) async => scope.get(
    '/chats/${await resolve(id)}',
    query: {'limit': 50, 'before': ?before},
  );
  Future<Map<String, Object?>> contacts(int offset) =>
      scope.get('/chats/contacts', query: {'offset': offset, 'limit': 30});
  Future<String> direct(String id) async =>
      ApiJson.id((await scope.change('PUT', '/chats/direct/$id', {}))['id']);
  Future<void> send(String id, Map<String, Object?> body) =>
      outbox.send(id, body, _deliver);
  Future<void> _deliver(String id, Map<String, Object?> body) async {
    await scope.change('POST', '/chats/${await resolve(id)}/messages', body);
  }

  Future<void> flush() => outbox.flush(_deliver);
  Future<void> state(String id, Map<String, Object?> body) async {
    await scope.change('PATCH', '/chats/${await resolve(id)}/state', body);
  }

  Future<void> respond(String id, String action) async {
    await scope.change('POST', '/chats/$id/request', {'action': action});
  }

  Future<void> message(
    String id,
    String message,
    Map<String, Object?> body,
  ) async {
    await scope.change('PATCH', '/chats/$id/messages/$message', body);
  }

  Future<void> report(
    String id,
    String message,
    String reason,
    String? note,
  ) async {
    await scope.change('POST', '/chats/$id/reports', {
      'message_id': int.parse(message),
      'reason': reason,
      'note': note ?? '',
    });
  }

  Future<void> react(String id, String message, String? emoji) async {
    await scope.change('PUT', '/chats/$id/messages/$message/reaction', {
      'emoji': emoji,
    });
  }

  Future<Map<String, Object?>> privacy() => scope.get('/me/chat-privacy');
  Future<void> setPrivacy(String value) async {
    await scope.change('PATCH', '/me/chat-privacy', {'who_can_message': value});
  }
}

final liveChatInboxProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, int>(
      (ref, offset) => ref.watch(liveChatApiProvider).inbox(offset),
      retry: (_, _) => null,
    );
final liveConversationProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, ({String id, int? before})>(
      (ref, page) => ref.watch(liveChatApiProvider).read(page.id, page.before),
      retry: (_, _) => null,
    );
final liveChatContactsProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, int>(
      (ref, offset) => ref.watch(liveChatApiProvider).contacts(offset),
      retry: (_, _) => null,
    );
final liveChatPrivacyProvider =
    FutureProvider.autoDispose<Map<String, Object?>>(
      (ref) => ref.watch(liveChatApiProvider).privacy(),
      retry: (_, _) => null,
    );

final liveChatPendingProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>(
      (ref) => ref.watch(liveChatApiProvider).outbox.pending(),
      retry: (_, _) => null,
    );
