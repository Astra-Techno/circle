import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/workspace_providers.dart';

/// Shows [child] when this session has [feature]; on a server that doesn't
/// offer it yet, one calm "Not on the server yet" card instead (never mock
/// data mixed into real groups). [inline] fits inside an existing list.
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
    final card = CircleNotOnServer(message: feature.notOnServer);
    if (inline) return card;
    return ReadingPane(
      child: ListView(padding: CircleInsets.page, children: [card]),
    );
  }
}

/// The one preview label of a screen. On a server it shows [server]
/// instead, or nothing (the header already names the server).
class PreviewNotice extends ConsumerWidget {
  const PreviewNotice(this.text, {super.key, this.server});
  final String text;
  final String? server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(circleFeaturesProvider).server) return PreviewLabel(text);
    return server == null ? const SizedBox.shrink() : CircleNote(server!);
  }
}

/// "Saving locally…" in the preview, "Saving…" on a server.
String savingLabel(WidgetRef ref) =>
    ref.watch(circleFeaturesProvider).server ? 'Saving…' : 'Saving locally…';
