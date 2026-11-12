import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../memories/presentation/memory_photos.dart';
import '../../memories/presentation/scoped_memory_list.dart';
import '../../workspace/application/workspace_providers.dart';

Future<List<String>?> pickSharedPhotos(
  BuildContext context,
  String groupId, {
  required int max,
  Set<String> excluded = const {},
}) {
  final selected = <String>{};
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Photos shared in this Circle'),
        content: SizedBox(
          width: CircleLayout.homeComposerMaxWidth,
          child: SingleChildScrollView(
            child: ScopedMemoryList(
              query: MemoryQuery(groupId: groupId),
              empty: const CircleEmpty(
                title: 'No shared photos yet',
                message: 'Share a photo in a Memory, then add it to an album.',
              ),
              itemBuilder: (context, memory) => Column(
                children: [
                  for (final photo in memory.photos)
                    if (photo.mediaId case final media?)
                      if (!excluded.contains(media))
                        CheckboxListTile(
                          value: selected.contains(media),
                          title: Text(
                            photo.caption ?? 'Photo from ${memory.author}',
                          ),
                          secondary: SizedBox(
                            width: Space.large,
                            height: Space.large,
                            child: MemoryPhotoTile(
                              photo: photo,
                              semanticsLabel: photo.description,
                            ),
                          ),
                          onChanged:
                              selected.contains(media) || selected.length < max
                              ? (value) {
                                  update(() {
                                    if (value == true) {
                                      selected.add(media);
                                    } else {
                                      selected.remove(media);
                                    }
                                  });
                                }
                              : null,
                        ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, selected.toList()),
            child: Text('Add ${selected.length} photos'),
          ),
        ],
      ),
    ),
  );
}
