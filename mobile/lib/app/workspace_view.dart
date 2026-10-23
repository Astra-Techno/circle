import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design.dart';
import '../core/circle_components.dart';
import '../features/groups/domain/circle_repository.dart';
import 'workspace_providers.dart';

class WorkspaceView extends ConsumerWidget {
  const WorkspaceView({super.key, required this.builder});
  final Widget Function(CircleWorkspace workspace) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(circleWorkspaceProvider)
      .when(
        data: builder,
        loading: () => Semantics(
          label: 'Loading your circles',
          child: ReadingPane(
            child: ListView(
              padding: const EdgeInsets.all(Space.section),
              children: [
                for (var i = 0; i < 3; i++)
                  Card(
                    child: SizedBox(
                      height: 120,
                      child: ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        error: (_, _) => ReadingPane(
          child: ListView(
            padding: const EdgeInsets.all(Space.section),
            children: [
              CircleEmpty(
                title: 'Your circles couldn’t load',
                message: 'Try loading the local preview again.',
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
