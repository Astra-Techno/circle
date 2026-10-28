import 'dart:async';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_json.dart';
import '../../../core/local_settings.dart';
import '../../../core/notifications/native_push.dart';
import '../data/push_preferences_api.dart';
import '../domain/push_envelope.dart';
import 'push_ledger.dart';
import 'push_settings.dart';

/// Background readers never refresh or write the real credential store. A token
/// expired during suspension waits for the foreground session owner to refresh.
class BackgroundPushProcessor {
  BackgroundPushProcessor({
    required this.config,
    required this.readTokens,
    required this.ledger,
    required this.show,
    this.clientFactory,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final ApiConfig config;
  final Future<TokenPair?> Function() readTokens;
  final PushLedger ledger;
  final Future<bool> Function(PushEnvelope envelope) show;
  final ApiClient Function(TokenPair tokens)? clientFactory;
  final DateTime Function() clock;

  PushScope? _scope(TokenPair? tokens) =>
      tokens == null ||
          tokens.server != config.baseUrl.toString() ||
          tokens.account == null
      ? null
      : PushScope.fromAccessToken(
          server: tokens.server,
          account: tokens.account!.id,
          token: tokens.accessToken,
        );

  Future<void> receive(Map<String, dynamic> raw) async {
    ApiClient? api;
    try {
      final tokens = await readTokens();
      final scope = _scope(tokens);
      if (scope == null || tokens == null || !config.secure) return;
      final envelope = PushEnvelope.parse(raw, scope, clock());
      if (envelope == null) return;
      // Persist before I/O. A transient/offline result can be retried on resume.
      await ledger.stage(envelope, PushAction.display, clock());
      final pending = await ledger.pending(scope, clock());
      if (!pending.any(
        (r) =>
            r.action == PushAction.display &&
            r.envelope.eventId == envelope.eventId,
      )) {
        return;
      }
      api =
          clientFactory?.call(tokens) ??
          ApiClient(
            config: config,
            tokens: MemoryTokenStore(tokens),
            allowRefresh: false,
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 5),
          );
      final reception = PushReception(envelope, PushAction.display);
      try {
        final preferences = await PushPreferencesApi(
          api,
          accountId: scope.account,
        ).load();
        final category = (envelope.isInvitation || envelope.isReport)
            ? PushCategory.groups
            : envelope.isChat
            ? PushCategory.chats
            : envelope.isEvent
            ? PushCategory.events
            : envelope.type == 'memory.created'
            ? PushCategory.memories
            : PushCategory.repliesReactions;
        if (!preferences.enabled || preferences.categories[category] != true) {
          await ledger.complete(reception, clock());
          return;
        }
        if (pushQuietNow(preferences, clock())) return;
        final memory = ApiJson.map(
          await api.get(
            envelope.authorizationPath,
            expectedAccount: scope.account,
          ),
        );
        if (!envelope.authorizes(memory, clock())) {
          await ledger.complete(reception, clock());
          return;
        }
        final live = _scope(await readTokens());
        if (live?.key != scope.key || !envelope.belongsTo(scope, clock())) {
          return;
        }
        // Native show atomically checks opt-in scope, permission/channel and
        // scoped delivery history across both foreground/headless engines.
        if (await show(envelope)) await ledger.complete(reception, clock());
      } on ApiError catch (error) {
        if (const {
          'not_found',
          'not_member',
          'account_inactive',
        }.contains(error.code)) {
          await ledger.complete(reception, clock());
        }
      }
    } catch (_) {
      // No private payloads/credentials in background logs or crash messages.
    } finally {
      api?.dio.close(force: true);
    }
  }
}

@pragma('vm:entry-point')
Future<void> circleBackgroundPushHandler(RemoteMessage message) async {
  if (!const bool.fromEnvironment('CIRCLE_PUSH_ENABLED')) return;
  DartPluginRegistrant.ensureInitialized();
  final config = ApiConfig.fromEnvironment();
  if (config == null || !config.secure) return;
  const native = NativePushBridge();
  final processor = BackgroundPushProcessor(
    config: config,
    readTokens: SecureTokenStore().read,
    ledger: PushLedger(SecureLocalSettingsStore(), mutex: native),
    show: (envelope) => native.show(
      scope: envelope.scope.key,
      event: envelope.eventId,
      expires: envelope.expiresAt,
      data: envelope.toData(),
    ),
  );
  // Per-request bounds keep normal work within Android's headless allowance.
  await processor.receive(message.data);
}
