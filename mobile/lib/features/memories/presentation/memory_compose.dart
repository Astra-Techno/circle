import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_signed_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/feature_gate.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/media_providers.dart';
import '../application/photo_uploads.dart';
import 'memory_photos.dart';

/// B3: Memory composer. The audience comes from context (`?group=`); with
/// several groups and no context, the person must choose explicitly. Text,
/// fictional photos and a poll can be mixed; at least one is needed.
/// "Share Memory" is the one primary action; extras sit under "More options".
class CircleCompose extends ConsumerStatefulWidget {
  const CircleCompose({super.key, this.initialGroupId});
  final String? initialGroupId;
  @override
  ConsumerState<CircleCompose> createState() => _CircleComposeState();
}

class _CircleComposeState extends ConsumerState<CircleCompose> {
  final _text = TextEditingController();
  final _year = TextEditingController();
  final _place = TextEditingController();
  final List<MemoryScene> _photos = [];

  /// Optional captions for the preview's photos (≤ 140 each). A server has
  /// no caption field yet, so they're only offered in the preview.
  final Map<MemoryScene, TextEditingController> _captions = {};
  String? _captionError;
  PollForm? _poll;
  String? _groupId;
  String? _audienceError, _textError, _yearError, _placeError, _pollError;
  bool _busy = false;

  /// Real photos on a server (null in the preview, which uses scenes).
  PhotoUploads? _uploads;

  @override
  void initState() {
    super.initState();
    final media = ref.read(mediaRepositoryProvider);
    if (media != null) {
      _uploads = PhotoUploads(media)..addListener(_uploadsChanged);
    }
  }

  void _uploadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.dispose();
    _year.dispose();
    _place.dispose();
    _poll?.dispose();
    _uploads?.dispose();
    for (final caption in _captions.values) {
      caption.dispose();
    }
    super.dispose();
  }

  /// Uploads go to the chosen group; they start once it is known.
  void _target(String? groupId) {
    final uploads = _uploads;
    if (uploads == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) uploads.target(groupId);
    });
  }

  /// "Add photos" on a server: the device's photo library, asked for only
  /// now (never on launch).
  Future<void> _pickDevicePhotos(PhotoUploads uploads) async {
    final room = MemoryRules.maxPhotos - uploads.count;
    if (room <= 0) {
      showCircleMessage(context, 'Add up to 10 photos.');
      return;
    }
    final picked = await runCalmly(
      context,
      () => ref.read(photoPickerProvider).pick(max: room),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    uploads.add(picked);
    setState(() => _textError = null);
  }

  Future<void> _pickPhotos() async {
    final picked = await pickScenes(
      context,
      initial: _photos,
      max: MemoryRules.maxPhotos,
    );
    if (picked != null && mounted) {
      setState(() {
        _photos
          ..clear()
          ..addAll(picked);
        _textError = null;
        _dropUnusedCaptions();
      });
    }
  }

  TextEditingController _caption(MemoryScene scene) =>
      _captions.putIfAbsent(scene, TextEditingController.new);

  void _dropUnusedCaptions() {
    for (final scene in [..._captions.keys]) {
      if (!_photos.contains(scene)) _captions.remove(scene)!.dispose();
    }
  }

  Future<void> _share(String? groupId) async {
    if (_busy) return;
    final uploads = _uploads;
    if (uploads != null && groupId != null) {
      if (uploads.busy) {
        showCircleMessage(
          context,
          'Your photos are still uploading. Share again in a moment.',
        );
        return;
      }
      if (uploads.hasFailed) {
        showCircleMessage(
          context,
          'Retry or remove the photos that didn’t upload.',
        );
        return;
      }
    }
    final now = DateTime.now();
    final poll = _poll?.draft();
    final content = MemoryRules.checkContent(
      text: _text.text,
      photoCount: uploads?.count ?? _photos.length,
      hasPoll: poll != null,
    );
    final pollCheck = poll == null ? null : PollRules.checkDraft(poll);
    final year = MemoryRules.parseYear(_year.text, now);
    final place = MemoryRules.checkPlace(_place.text);
    final captions = [for (final scene in _photos) _captions[scene]?.text];
    final captionCheck = captions
        .map(PhotoCaptionRules.check)
        .firstWhere((check) => !check.allowed, orElse: () => content);
    setState(() {
      _captionError = captionCheck.allowed ? null : captionCheck.reason;
      _audienceError = groupId == null
          ? 'Choose who will see this Memory.'
          : null;
      _textError = content.reason;
      _pollError = pollCheck?.reason;
      _yearError = year.result.reason;
      _placeError = place.reason;
    });
    if (groupId == null ||
        !content.allowed ||
        !(pollCheck?.allowed ?? true) ||
        !year.result.allowed ||
        !place.allowed ||
        _captionError != null) {
      return;
    }
    setState(() => _busy = true);
    final id = await runCalmly(
      context,
      () => ref
          .read(circleWorkspaceProvider.notifier)
          .createMemory(
            groupId,
            _text.text,
            photos: [..._photos],
            captions: captions,
            mediaIds: uploads?.readyIds ?? const [],
            poll: poll,
            takenYear: year.year,
            place: _place.text,
          ),
    );
    if (!mounted) return;
    if (id != null) {
      uploads?.clearShared();
      context.go('/home');
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      if (workspace.groups.isEmpty) {
        return ReadingPane(
          child: CircleEmpty(
            title: 'Choose your people first',
            message: 'Create a group before sharing a Memory.',
            action: FilledButton(
              onPressed: () => context.go('/groups/new'),
              child: const Text('Create a group'),
            ),
          ),
        );
      }
      final fromContext =
          workspace.groupsById.containsKey(widget.initialGroupId)
          ? widget.initialGroupId
          : null;
      // A single group is the only possible audience, so it is not a
      // silent guess. Otherwise nothing is preselected without context.
      final chosen =
          _groupId ??
          fromContext ??
          (workspace.groups.length == 1 ? workspace.groups.single.id : null);
      final tree = buildGroupTree(workspace.groups);
      final theme = Theme.of(context);
      final features = ref.watch(circleFeaturesProvider);
      final uploads = _uploads;
      if (uploads != null) _target(chosen);
      final photoCount = uploads?.count ?? _photos.length;
      final optional = photoCount > 0 || _poll != null;
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            const CircleHeading(
              title: 'Something worth\nsharing.',
              subtitle: 'A small moment can mean a lot to your circle.',
            ),
            DropdownButtonFormField<String>(
              initialValue: chosen,
              isExpanded: true,
              hint: const Text('Choose a group'),
              decoration: InputDecoration(
                labelText: 'Share with',
                helperText: 'Only members of this exact group will see it.',
                helperMaxLines: 3,
                errorText: _audienceError,
                errorMaxLines: 3,
              ),
              items: [
                for (final entry in tree)
                  DropdownMenuItem(
                    value: entry.group.id,
                    child: Text(
                      entry.path.isEmpty
                          ? entry.group.name
                          : '${entry.group.name} · in ${entry.path.last}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                setState(() {
                  _groupId = id;
                  _audienceError = null;
                });
                _target(id);
              },
            ),
            const SizedBox(height: Space.section),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              maxLength: MemoryRules.maxText,
              decoration: InputDecoration(
                labelText: 'Your Memory',
                helperText: optional ? 'Words are optional here.' : null,
                errorText: _textError,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (uploads != null)
                  OutlinedButton.icon(
                    onPressed: uploads.count >= MemoryRules.maxPhotos
                        ? null
                        : () => _pickDevicePhotos(uploads),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      uploads.isEmpty ? 'Add photos' : 'Add more photos',
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _photos.isEmpty ? 'Add photos' : 'Change photos',
                    ),
                  ),
                if (_poll == null && features.has(CircleFeature.polls))
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _poll = PollForm();
                      _textError = null;
                    }),
                    icon: const Icon(Icons.poll_outlined),
                    label: const Text('Add a poll'),
                  ),
              ],
            ),
            if (uploads != null && !uploads.isEmpty) ...[
              CircleSectionTitle(
                '${uploads.count} of ${MemoryRules.maxPhotos} photos',
              ),
              UploadGrid(uploads: uploads, waitingForGroup: chosen == null),
            ],
            if (_photos.isNotEmpty) ...[
              CircleSectionTitle(
                '${_photos.length} of ${MemoryRules.maxPhotos} photos',
              ),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final scene in _photos)
                    InputChip(
                      avatar: Icon(memorySceneIcon(scene)),
                      label: Text(scene.label),
                      deleteButtonTooltipMessage: 'Remove ${scene.label} photo',
                      onDeleted: () => setState(() {
                        _photos.remove(scene);
                        _dropUnusedCaptions();
                      }),
                    ),
                ],
              ),
              // Optional, out of the way: one field per photo.
              ExpansionTile(
                key: const ValueKey('compose-captions'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: Space.sm),
                initiallyExpanded: _captionError != null,
                title: const Text('Captions (optional)'),
                subtitle: Text(
                  _captionError ?? 'A few words under each photo',
                  style: theme.textTheme.bodySmall,
                ),
                children: [
                  for (final scene in _photos)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: TextField(
                        controller: _caption(scene),
                        maxLength: PhotoCaptionRules.maxLength,
                        decoration: InputDecoration(
                          labelText: 'Caption for ${scene.label}',
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (_poll != null) ...[
              const SizedBox(height: Space.lg),
              PollEditor(
                form: _poll!,
                error: _pollError,
                onChanged: () => setState(() {}),
                onRemove: () => setState(() {
                  _poll!.dispose();
                  _poll = null;
                  _pollError = null;
                }),
              ),
            ],
            const SizedBox(height: Space.sm),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: Space.md),
              title: const Text('More options'),
              subtitle: Text(
                'When and where it was taken',
                style: theme.textTheme.bodySmall,
              ),
              children: [
                TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Year taken (optional)',
                    helperText:
                        'For older moments, ${MemoryRules.firstYear}–'
                        '${DateTime.now().year}',
                    errorText: _yearError,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _place,
                  maxLength: MemoryRules.maxPlace,
                  decoration: InputDecoration(
                    labelText: 'Place (optional)',
                    errorText: _placeError,
                    errorMaxLines: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            FilledButton(
              onPressed: _busy ? null : () => _share(chosen),
              child: Text(
                _busy
                    ? (features.server ? 'Sharing…' : 'Saving locally…')
                    : 'Share Memory',
              ),
            ),
            const SizedBox(height: Space.lg),
            const PreviewNotice(
              'Preview: photos are fictional illustrations, and everything '
              'stays on this device until you end the preview.',
            ),
          ],
        ),
      );
    },
  );
}

/// The composer's photos on a server: thumbnails from the device, each
/// with its upload progress, or Retry and the reason when it failed, and
/// Remove (48 px targets, labelled for screen readers).
class UploadGrid extends StatelessWidget {
  const UploadGrid({
    super.key,
    required this.uploads,
    this.waitingForGroup = false,
  });
  final PhotoUploads uploads;

  /// Uploads wait until the audience is chosen.
  final bool waitingForGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = uploads.firstError;
    final items = uploads.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final (index, item) in items.indexed)
              _UploadTile(
                item: item,
                number: index + 1,
                waitingForGroup: waitingForGroup,
                onRetry: () => uploads.retry(item),
                onRemove: () => uploads.remove(item),
              ),
          ],
        ),
        if (waitingForGroup)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              'Photos upload once you choose who will see this Memory.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Semantics(
              liveRegion: true,
              child: Text(
                '$error You can still share your words without photos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.item,
    required this.number,
    required this.waitingForGroup,
    required this.onRetry,
    required this.onRemove,
  });
  final UploadItem item;
  final int number;
  final bool waitingForGroup;
  final VoidCallback onRetry, onRemove;

  static const _size = 104.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = switch (item.status) {
      UploadStatus.waiting =>
        waitingForGroup ? 'waiting for a group' : 'waiting to upload',
      UploadStatus.uploading => 'uploading, ${(item.progress * 100).round()}%',
      UploadStatus.ready => 'uploaded',
      UploadStatus.failed => 'didn’t upload',
    };
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: 'Photo $number, $status',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CircleRadius.tile),
              child: Image.memory(
                item.preview,
                fit: BoxFit.cover,
                cacheWidth: 312,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const CirclePhotoPlaceholder(),
              ),
            ),
          ),
          if (item.status != UploadStatus.ready)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(CircleRadius.tile),
              ),
              child: Center(
                child: switch (item.status) {
                  UploadStatus.uploading => CircularProgressIndicator(
                    value: item.progress > 0 ? item.progress : null,
                  ),
                  UploadStatus.failed when item.retryable => IconButton.filled(
                    tooltip: 'Retry photo $number',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                  ),
                  UploadStatus.failed => Icon(
                    Icons.error_outline,
                    color: colors.error,
                  ),
                  _ => Icon(Icons.schedule, color: colors.onSurfaceVariant),
                },
              ),
            ),
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: IconButton(
              tooltip: 'Remove photo $number',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                backgroundColor: colors.surface.withValues(alpha: 0.8),
              ),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

/// Poll fields held by a composer (Memories and chat).
class PollForm {
  PollForm() : options = [TextEditingController(), TextEditingController()];
  final question = TextEditingController();
  final List<TextEditingController> options;
  bool multipleChoice = false, anonymous = false, allowChangeVote = true;
  PollDuration duration = PollDuration.never;
  PollResultsVisibility resultsVisibility = PollResultsVisibility.afterVoting;

  PollDraft draft() => PollDraft(
    question: question.text,
    options: [for (final option in options) option.text],
    multipleChoice: multipleChoice,
    anonymous: anonymous,
    duration: duration,
    resultsVisibility: resultsVisibility,
    allowChangeVote: allowChangeVote,
  );

  void dispose() {
    question.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

/// F1 in the composer: a question and two options are enough; settings
/// already have calm defaults behind "More poll options".
class PollEditor extends StatelessWidget {
  const PollEditor({
    super.key,
    required this.form,
    required this.onChanged,
    this.onRemove,
    this.error,
  });
  final PollForm form;
  final VoidCallback onChanged;

  /// Shows "Remove poll" when set (the Memory composer).
  final VoidCallback? onRemove;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = form.options;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: CircleAccents.of(context).hairline),
        borderRadius: BorderRadius.circular(CircleRadius.inner),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Poll', style: theme.textTheme.titleMedium),
                  ),
                ),
                if (onRemove != null)
                  TextButton(
                    onPressed: onRemove,
                    child: const Text('Remove poll'),
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: form.question,
              maxLength: PollRules.maxQuestion,
              decoration: const InputDecoration(labelText: 'Poll question'),
            ),
            for (final (index, option) in options.indexed)
              Padding(
                key: ObjectKey(option),
                padding: const EdgeInsets.only(top: Space.sm),
                child: TextField(
                  controller: option,
                  maxLength: PollRules.maxOption,
                  decoration: InputDecoration(
                    labelText: 'Option ${index + 1}',
                    suffixIcon: options.length > PollRules.minOptions
                        ? IconButton(
                            tooltip: 'Remove option ${index + 1}',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              options.removeAt(index).dispose();
                              onChanged();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            if (options.length < PollRules.maxOptions)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    options.add(TextEditingController());
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('More poll options'),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow more than one answer'),
                  value: form.multipleChoice,
                  onChanged: (value) {
                    form.multipleChoice = value;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anonymous votes'),
                  subtitle: const Text('Nobody sees who voted for what.'),
                  value: form.anonymous,
                  onChanged: (value) {
                    form.anonymous = value;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('People can change their vote'),
                  value: form.allowChangeVote,
                  onChanged: (value) {
                    form.allowChangeVote = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: Space.sm),
                DropdownButtonFormField<PollDuration>(
                  initialValue: form.duration,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Closes'),
                  items: [
                    for (final duration in PollDuration.values)
                      DropdownMenuItem(
                        value: duration,
                        child: Text(
                          duration == PollDuration.never
                              ? 'Never (close it yourself)'
                              : 'After ${duration.label}',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) form.duration = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: Space.md),
                DropdownButtonFormField<PollResultsVisibility>(
                  initialValue: form.resultsVisibility,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Who sees results',
                  ),
                  items: [
                    for (final visibility in PollResultsVisibility.values)
                      DropdownMenuItem(
                        value: visibility,
                        child: Text(
                          visibility.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) form.resultsVisibility = value;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
