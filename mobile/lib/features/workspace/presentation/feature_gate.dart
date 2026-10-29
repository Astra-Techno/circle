import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/workspace_providers.dart';

/// Shows [child] when the server offers [feature]. Otherwise the feature is
/// hidden: nothing inline, and a calm "unavailable" page if someone opens
/// its address directly. Never placeholder or mock data.
class CircleFeatureGate extends ConsumerWidget {
  const CircleFeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.inline = false,
  });
  final CircleFeature feature;
  final Widget child;
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(circleFeaturesProvider).has(feature)) return child;
    if (inline) return const SizedBox.shrink();
    return const ReadingPane(
      child: Padding(
        padding: CircleInsets.page,
        child: CircleEmpty(
          title: 'This page is unavailable',
          message: 'Return to your circles.',
        ),
      ),
    );
  }
}

/// The busy label while a change is sent to the server.
String savingLabel(WidgetRef ref) => 'Saving…';
