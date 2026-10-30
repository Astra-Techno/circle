import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../application/workspace_providers.dart';

/// Shows loading/error states for the workspace and builds [builder] with
/// data. Shared by every feature screen.
class WorkspaceView extends ConsumerWidget {
  const WorkspaceView({super.key, required this.builder});
  final Widget Function(CircleWorkspace workspace) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(circleWorkspaceProvider)
      .when(
        // Keep showing data while a mutation reloads it.
        skipLoadingOnReload: true,
        data: builder,
        loading: () => const CircleStatePanel(
          child: CircleSkeleton(
            shape: CircleSkeletonShape.cards,
            count: 3,
            label: 'Loading your circles',
          ),
        ),
        error: (error, _) => CircleStatePanel(
          child: Column(
            children: [
              CircleEmpty(
                title: 'Your circles couldn’t load',
                message: error is CircleFailure
                    ? error.message
                    : 'Check your connection and try again.',
                action: FilledButton(
                  onPressed: () => ref.invalidate(circleWorkspaceProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      );
}
