import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../workspace/application/workspace_providers.dart';

/// A group's report queue and audit trail, or the calm reason it can't be
/// shown (only admins of that exact group see it). Refreshes whenever the
/// workspace changes.
final moderationQueueProvider =
    FutureProvider.family<
      ({ModerationQueue? queue, String? unavailable}),
      String
    >((ref, groupId) async {
      ref.watch(circleWorkspaceProvider);
      try {
        return (
          queue: await ref
              .read(circleRepositoryProvider)
              .queue(ref.watch(circleViewerProvider), groupId),
          unavailable: null,
        );
      } on CircleFailure catch (failure) {
        return (queue: null, unavailable: failure.message);
      }
    });
