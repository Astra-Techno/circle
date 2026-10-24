import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../memories/presentation/memory_photos.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/album_providers.dart';
import 'albums_tab.dart';

/// On a past event's page: "Photos from …" (the event's title). The album is created the
/// first time someone adds photos, inside the event's own group.
class EventAlbumSection extends ConsumerWidget {
  const EventAlbumSection({super.key, required this.event});
  final CircleEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(circleClockProvider)();
    if (!AlbumRules.canHaveEventAlbum(event, now.toUtc()).allowed) {
      return const SizedBox.shrink();
    }
    final album = ref.watch(eventAlbumProvider(event.id)).value?.value;
    final title = AlbumRules.eventAlbumTitle(event);

    Future<void> addFirst() async {
      final scenes = await pickScenes(
        context,
        max: AlbumRules.maxPerAdd,
        action: 'Add',
      );
      if (scenes == null || scenes.isEmpty || !context.mounted) return;
      final router = GoRouter.of(context);
      final id = await runCalmly(
        context,
        () => ref
            .read(albumControllerProvider.notifier)
            .addEventPhotos(event.id, scenes),
        success: 'Photos added to “$title”.',
      );
      if (id != null) router.push(albumLocation(event.groupId, id));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CircleSectionTitle('Photos'),
        if (album == null)
          CircleRow(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleInitialAvatar(
                icon: Icons.photo_library_outlined,
                tone: CircleTone.neutral,
              ),
              title: Text(title),
              subtitle: const Text('No photos yet. Add the first ones.'),
              trailing: TextButton(
                onPressed: addFirst,
                child: Text(
                  'Add photos',
                  semanticsLabel: 'Add photos to $title',
                ),
              ),
            ),
          )
        else
          CircleRow(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleInitialAvatar(
                icon: album.cover == null
                    ? Icons.photo_library_outlined
                    : memorySceneIcon(album.cover!.photo.scene),
                tone: CircleTone.neutral,
              ),
              title: Text(album.title),
              subtitle: Text(album.details),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(albumLocation(album.groupId, album.id)),
            ),
          ),
      ],
    );
  }
}
