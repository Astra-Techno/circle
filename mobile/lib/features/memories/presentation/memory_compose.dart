import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/local_settings.dart';
import '../../../core/api/api_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_signed_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../groups/domain/group_tree.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/media_providers.dart';
import '../application/photo_uploads.dart';

/// B3: Memory composer, camera first (like Instagram): photos at the top,
/// then a caption and who sees it. The audience comes from context
/// (`?group=`); with several groups and no context, the person must choose
/// explicitly. Photos or words are needed. "Share Memory" is the one primary
/// action, pinned in the thumb zone; extras sit under "More options".
class CircleCompose extends ConsumerStatefulWidget {
  const CircleCompose({super.key, this.initialGroupId});
  final String? initialGroupId;
  @override
  ConsumerState<CircleCompose> createState() => _CircleComposeState();
}

class _CircleComposeState extends ConsumerState<CircleCompose>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _year = TextEditingController();
  final _place = TextEditingController();
  String? _groupId;
  String? _audienceError, _textError, _yearError, _placeError;

  /// Why sharing must wait (photos uploading or failed), shown just above
  /// the pinned Share button so no message covers it.
  String? _shareNotice;
  bool _busy = false;

  /// The photos being uploaded to the server (null while signed out).
  PhotoUploads? _uploads;
  MemoryDraftStore? _draftStore;
  DraftLease? _draftLease;
  MemoryTextDraft? _resumeDraft;
  Timer? _draftTimer;
  bool _draftReady = false, _submitted = false;
  String? _draftNotice, _effectiveGroup;

  void _draftChanged() {
    if (!_draftReady || _submitted || _resumeDraft != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final lease = _draftLease;
    if (lease == null || _submitted || _resumeDraft != null) return;
    final ok = await _draftStore!.save(
      lease,
      MemoryTextDraft(
        text: _text.text,
        year: _year.text,
        place: _place.text,
        groupId: _effectiveGroup ?? _groupId ?? widget.initialGroupId,
      ),
    );
    if (!ok && mounted) {
      setState(() => _draftNotice = 'Draft could not be saved on this device.');
    }
  }

  Future<void> _restoreDraft() async {
    final account = ref.read(serverAccountProvider);
    final config = ref.read(apiConfigProvider);
    if (account == null || config == null) return;
    _draftStore = ref.read(memoryDraftStoreProvider);
    _draftLease = _draftStore!.open(
      DraftScope(server: config.baseUrl.toString(), account: account.id),
    );
    final draft = await _draftStore!.read(
      _draftLease!,
      groupId: widget.initialGroupId,
    );
    if (!mounted) return;
    setState(() {
      _resumeDraft = draft;
      _draftReady = true;
    });
  }

  Future<void> _resolveDraft(bool resume) async {
    final draft = _resumeDraft;
    if (draft == null) return;
    if (!resume) {
      final removed = await _draftStore!.remove(_draftLease!, draft.groupId);
      if (!mounted) return;
      if (!removed) {
        setState(
          () => _draftNotice =
              'The draft could not be discarded. Please try again.',
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      if (resume) {
        _text.text = draft.text;
        _year.text = draft.year;
        _place.text = draft.place;
        _groupId = draft.groupId;
      }
      _resumeDraft = null;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_draftChanged);
    _year.addListener(_draftChanged);
    _place.addListener(_draftChanged);
    unawaited(_restoreDraft());
    final media = ref.read(mediaRepositoryProvider);
    if (media != null) {
      _uploads = PhotoUploads(media)..addListener(_uploadsChanged);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _draftReady) {
      _draftTimer?.cancel();
      unawaited(_saveDraft());
    }
  }

  void _uploadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    if (_draftReady) unawaited(_saveDraft());
    _text.dispose();
    _year.dispose();
    _place.dispose();
    _uploads?.dispose();
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

  Future<void> _share(String? groupId) async {
    if (_busy || _resumeDraft != null) return;
    final uploads = _uploads;
    if (uploads != null && groupId != null) {
      if (uploads.busy) {
        setState(
          () => _shareNotice =
              'Your photos are still uploading. Share again in a moment.',
        );
        return;
      }
      if (uploads.hasFailed) {
        setState(
          () => _shareNotice = 'Retry or remove the photos that didn’t upload.',
        );
        return;
      }
    }
    if (_shareNotice != null) setState(() => _shareNotice = null);
    final now = DateTime.now();
    final content = MemoryRules.checkContent(
      text: _text.text,
      photoCount: uploads?.count ?? 0,
      hasPoll: false,
    );
    final year = MemoryRules.parseYear(_year.text, now);
    final place = MemoryRules.checkPlace(_place.text);
    setState(() {
      _audienceError = groupId == null
          ? 'Choose who will see this Memory.'
          : null;
      _textError = content.reason;
      _yearError = year.result.reason;
      _placeError = place.reason;
    });
    if (groupId == null ||
        !content.allowed ||
        !year.result.allowed ||
        !place.allowed) {
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
            mediaIds: uploads?.readyIds ?? const [],
            takenYear: year.year,
            place: _place.text,
          ),
    );
    if (!mounted) return;
    if (id != null) {
      _submitted = true;
      _draftTimer?.cancel();
      if (_draftLease != null) {
        // The serial store queues removal after any outstanding autosave.
        // A device storage plugin must not hold up a successful server share.
        unawaited(_draftStore!.remove(_draftLease!, groupId));
      }
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
      final candidate =
          _groupId ??
          fromContext ??
          (workspace.groups.length == 1 ? workspace.groups.single.id : null);
      final chosen = workspace.groupsById.containsKey(candidate)
          ? candidate
          : null;
      _effectiveGroup = chosen;
      final tree = buildGroupTree(workspace.groups);
      final theme = Theme.of(context);
      final uploads = _uploads;
      if (uploads != null) _target(chosen);
      final photoCount = uploads?.count ?? 0;
      final form = ListView(
        padding: CircleInsets.form,
        children: [
          if (_resumeDraft != null) ...[
            Text(
              'Resume your saved text draft? Photos must be selected again.',
              style: theme.textTheme.bodyMedium,
            ),
            Wrap(
              spacing: Space.sm,
              children: [
                TextButton(
                  onPressed: () => _resolveDraft(true),
                  child: const Text('Resume draft'),
                ),
                TextButton(
                  onPressed: () => _resolveDraft(false),
                  child: const Text('Discard draft'),
                ),
              ],
            ),
          ],
          if (_draftNotice != null)
            Text(_draftNotice!, style: theme.textTheme.bodyMedium),
          // Photos first: one big tap opens the phone's photos.
          if (uploads != null)
            if (uploads.isEmpty)
              _AddPhotosTile(onTap: () => _pickDevicePhotos(uploads))
            else ...[
              UploadGrid(uploads: uploads, waitingForGroup: chosen == null),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: uploads.count >= MemoryRules.maxPhotos
                      ? null
                      : () => _pickDevicePhotos(uploads),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    '$photoCount of ${MemoryRules.maxPhotos} · Add more photos',
                  ),
                ),
              ),
            ],
          const SizedBox(height: Space.lg),
          TextField(
            controller: _text,
            readOnly: _resumeDraft != null,
            minLines: 2,
            maxLines: 8,
            maxLength: MemoryRules.maxText,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Your Memory',
              hintText: 'Write a caption…',
              helperText: photoCount > 0 ? 'Words are optional here.' : null,
              errorText: _textError,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: Space.sm),
          DropdownButtonFormField<String>(
            initialValue: chosen,
            isExpanded: true,
            hint: const Text('Choose a group'),
            decoration: InputDecoration(
              labelText: 'Share with',
              prefixIcon: const Icon(Icons.lock_outline),
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
              _draftChanged();
            },
          ),
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
        ],
      );
      // The one primary action stays in the thumb zone.
      return ReadingPane(
        child: Column(
          children: [
            Expanded(child: form),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: CircleAccents.of(context).hairline),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.section,
                  Space.md,
                  Space.section,
                  Space.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_shareNotice != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _shareNotice!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : () => _share(chosen),
                      child: Text(_busy ? 'Sharing…' : 'Share Memory'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The empty photo area at the top of the composer: one large target that
/// opens the phone's photos.
class _AddPhotosTile extends StatelessWidget {
  const _AddPhotosTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Semantics(
      button: true,
      label: 'Add photos',
      excludeSemantics: true,
      child: Material(
        color: accents.recessed,
        borderRadius: BorderRadius.circular(CircleRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: Space.large,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Space.sm),
                Text('Add photos', style: theme.textTheme.titleMedium),
                Text(
                  'Up to ${MemoryRules.maxPhotos}, from your phone',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accents.caption,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
