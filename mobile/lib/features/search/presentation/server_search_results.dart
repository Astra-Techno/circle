import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/search_providers.dart';

class ServerSearchResults extends ConsumerStatefulWidget {
  const ServerSearchResults({
    super.key,
    required this.query,
    required this.onOpen,
  });
  final String query;
  final ValueChanged<String> onOpen;
  @override
  ConsumerState<ServerSearchResults> createState() =>
      _ServerSearchResultsState();
}

class _ServerSearchResultsState extends ConsumerState<ServerSearchResults> {
  int pages = 1;
  @override
  void didUpdateWidget(ServerSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) pages = 1;
  }

  @override
  Widget build(BuildContext context) {
    final request = (query: widget.query, pages: pages);
    final results = ref.watch(serverSearchProvider(request));
    return results.when(
      loading: () => const CircleSkeleton(count: 3, label: 'Searching'),
      error: (_, _) => CircleErrorState(
        title: "Couldn't load results",
        message: 'Your search is kept. Try again when connected.',
        onRetry: () => ref.invalidate(serverSearchProvider(request)),
      ),
      data: (page) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (page.items.isEmpty)
            const CircleEmpty(
              title: 'No results',
              message: 'Try another word from your Circles.',
            ),
          for (final category in [
            'groups',
            'people',
            'memories',
            'events',
            'polls',
          ])
            if (page.items.any((hit) => hit.category == category)) ...[
              CircleSectionTitle(
                '${category[0].toUpperCase()}${category.substring(1)}',
              ),
              for (final hit in page.items.where(
                (hit) => hit.category == category,
              ))
                CircleRow(
                  child: ListTile(
                    leading: Icon(switch (category) {
                      'groups' => CircleIcons.circles,
                      'people' => CircleIcons.profile,
                      'events' => CircleIcons.calendar,
                      'polls' => CircleIcons.vote,
                      _ => CircleIcons.photo,
                    }),
                    title: Text(
                      hit.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: hit.subtitle.isEmpty ? null : Text(hit.subtitle),
                    onTap: () => widget.onOpen(hit.location),
                  ),
                ),
            ],
          if (page.hasMore)
            TextButton(
              onPressed: () => setState(() => pages++),
              child: const Text('Load more results'),
            ),
        ],
      ),
    );
  }
}
