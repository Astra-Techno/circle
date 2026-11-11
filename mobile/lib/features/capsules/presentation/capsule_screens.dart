import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/capsule_providers.dart';

// ---------------------------------------------------------------------------
// Capsule list screen
// ---------------------------------------------------------------------------

class CapsuleListScreen extends ConsumerWidget {
  const CapsuleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(capsulesProvider);
    final accents = CircleAccents.of(context);
    final theme = Theme.of(context);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          CircleEmpty(title: 'Could not load capsules', message: '$e'),
      data: (capsules) {
        if (capsules.isEmpty) {
          return Padding(
            padding: CircleInsets.page,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleShimmerGlow(
                  color: accents.calm,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: accents.calmContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CircleIcons.timer,
                      size: 36,
                      color: accents.calm,
                    ),
                  ),
                ),
                const SizedBox(height: Space.section),
                Text('Memory Capsules', style: theme.textTheme.headlineSmall),
                const SizedBox(height: Space.sm),
                Text(
                  'Seal memories for the future.\nThey unlock on the date you choose.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accents.caption,
                  ),
                ),
                const SizedBox(height: Space.section),
                FilledButton.icon(
                  onPressed: () => context.push('/capsules/new'),
                  icon: const Icon(CircleIcons.create),
                  label: const Text('Create capsule'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: CircleInsets.rootPage,
          itemCount: capsules.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
          itemBuilder: (context, index) {
            final capsule = capsules[index];
            return CircleFadeIn(
              delay: CircleMotion.staggerDelay * index,
              child: _CapsuleCard(capsule: capsule),
            );
          },
        );
      },
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({required this.capsule});
  final Capsule capsule;

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    final theme = Theme.of(context);
    final isUnlocked = capsule.isUnlocked;
    final isSealed = capsule.isSealed;
    final accentColor = isUnlocked ? accents.sage : accents.calm;

    return CirclePressable(
      child: GestureDetector(
        onTap: () => context.push('/capsules/c/${capsule.id}'),
        child: Container(
          decoration: CircleDepth.glassPanel(
            context,
            radius: CircleRadius.card,
            glowColor: accentColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gradient header with capsule icon and status
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: CircleDepth.accentHeader(
                  context,
                  primary: isUnlocked ? accents.sage : accents.calm,
                  secondary: isUnlocked ? accents.calm : accents.amber,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? accents.sageContainer
                            : accents.calmContainer,
                        borderRadius: BorderRadius.circular(CircleRadius.tile),
                        boxShadow: CircleDepth.glowShadow(accentColor),
                      ),
                      child: Icon(
                        isUnlocked ? CircleIcons.lockOpen : CircleIcons.lock,
                        size: 20,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            capsule.title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            capsule.countdownLabel,
                            style: CircleTextStyles.metadata(
                              accentColor,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (isSealed && !isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                          vertical: Space.xs,
                        ),
                        decoration: BoxDecoration(
                          color: accents.amberContainer,
                          borderRadius: BorderRadius.circular(
                            CircleRadius.pill,
                          ),
                        ),
                        child: Text(
                          'Sealed',
                          style: CircleTextStyles.caption(
                            accents.amber,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),

              // Progress bar (only for sealed, not yet unlocked)
              if (isSealed && !isUnlocked)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CircleRadius.pill),
                    child: LinearProgressIndicator(
                      value: capsule.progress,
                      minHeight: 4,
                      backgroundColor: accents.hairline,
                      valueColor: AlwaysStoppedAnimation(accentColor),
                    ),
                  ),
                ),

              // Footer metadata
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.sm,
                  Space.md,
                  Space.md,
                ),
                child: Row(
                  children: [
                    if (capsule.message.isNotEmpty) ...[
                      Expanded(
                        child: Text(
                          capsule.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accents.caption,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (capsule.messageCount > 0)
                      _MetaBadge(
                        icon: CircleIcons.comment,
                        count: capsule.messageCount,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: accents.caption),
        const SizedBox(width: Space.xs),
        Text('$count', style: CircleTextStyles.caption(accents.caption)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Capsule detail screen
// ---------------------------------------------------------------------------

class CapsuleDetailScreen extends ConsumerWidget {
  const CapsuleDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(capsulesProvider);
    final accents = CircleAccents.of(context);
    final theme = Theme.of(context);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          CircleEmpty(title: 'Could not load capsule', message: '$e'),
      data: (capsules) {
        final capsule = capsules.where((c) => c.id == id).firstOrNull;
        if (capsule == null) {
          return const CircleEmpty(
            title: 'Capsule not found',
            message: 'This capsule may have been deleted.',
          );
        }

        final isUnlocked = capsule.isUnlocked;
        final isSealed = capsule.isSealed;
        final viewer = ref.watch(circleViewerProvider);
        final isMine = capsule.creatorId == viewer;

        return ReadingPane(
          child: ListView(
            padding: CircleInsets.page,
            children: [
              // Hero capsule card — premium glass panel with accent glow
              Container(
                decoration: CircleDepth.glassPanel(
                  context,
                  radius: CircleRadius.sheet,
                  glowColor: isUnlocked ? accents.sage : accents.calm,
                ),
                padding: const EdgeInsets.all(Space.section),
                child: Column(
                  children: [
                    // Status icon with progress ring and shimmer glow
                    CircleShimmerGlow(
                      color: isUnlocked ? accents.sage : accents.calm,
                      animate: isSealed && !isUnlocked,
                      child: isSealed && !isUnlocked
                          ? CircleProgressRing(
                              progress: capsule.progress,
                              color: accents.calm,
                              size: 80,
                              strokeWidth: 5,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: accents.calmContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CircleIcons.lock,
                                  size: 28,
                                  color: accents.calm,
                                ),
                              ),
                            )
                          : Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: isUnlocked
                                    ? accents.sageContainer
                                    : accents.calmContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isUnlocked
                                    ? CircleIcons.lockOpen
                                    : CircleIcons.lock,
                                size: 32,
                                color: isUnlocked ? accents.sage : accents.calm,
                              ),
                            ),
                    ),
                    const SizedBox(height: Space.md),

                    // Title
                    Text(
                      capsule.title,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.sm),

                    // Countdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.md,
                        vertical: Space.sm,
                      ),
                      decoration: BoxDecoration(
                        color: (isUnlocked ? accents.sage : accents.calm)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(CircleRadius.pill),
                      ),
                      child: Text(
                        capsule.countdownLabel,
                        style: CircleTextStyles.label(
                          isUnlocked ? accents.sage : accents.calm,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Space.section),

              // Message
              if (capsule.message.isNotEmpty) ...[
                Text(
                  capsule.message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: accents.caption,
                  ),
                ),
                const SizedBox(height: Space.section),
              ],

              // Status info
              if (!isUnlocked && !isSealed)
                _InfoTile(
                  icon: CircleIcons.info,
                  label: 'Open for contributions',
                  message:
                      'Add messages before sealing. Once sealed, contents are hidden until the unlock date.',
                ),
              if (isSealed && !isUnlocked)
                _InfoTile(
                  icon: CircleIcons.shield,
                  label: 'Sealed',
                  message:
                      'This capsule is sealed. Contents will be revealed on the unlock date.',
                ),
              if (isUnlocked)
                _InfoTile(
                  icon: CircleIcons.sparkles,
                  label: 'Unlocked',
                  message:
                      'This capsule has been unlocked! All memories inside are now visible.',
                ),

              const SizedBox(height: Space.md),

              // Stats row — glass panels
              Row(
                children: [
                  Expanded(
                    child: CircleFadeIn(
                      delay: CircleMotion.staggerDelay,
                      child: _StatCard(
                        icon: CircleIcons.comment,
                        value: '${capsule.messageCount}',
                        label: 'Messages',
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: CircleFadeIn(
                      delay: CircleMotion.staggerDelay * 2,
                      child: _StatCard(
                        icon: CircleIcons.members,
                        value: '${capsule.contributors.length}',
                        label: 'Contributors',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Space.section),

              // Actions
              if (isMine && capsule.isOpen) ...[
                FilledButton.icon(
                  onPressed: () => _confirmSeal(context, ref, capsule),
                  icon: const Icon(CircleIcons.lock),
                  label: const Text('Seal capsule'),
                ),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: () => _addEntry(context, ref, capsule),
                  icon: const Icon(CircleIcons.create),
                  label: const Text('Add a message'),
                ),
                const SizedBox(height: Space.sm),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref, capsule),
                  icon: Icon(CircleIcons.trash, color: theme.colorScheme.error),
                  label: Text(
                    'Delete capsule',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (capsule.isOpen && !isMine)
                OutlinedButton.icon(
                  onPressed: () => _addEntry(context, ref, capsule),
                  icon: const Icon(CircleIcons.create),
                  label: const Text('Add a message'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSeal(
    BuildContext context,
    WidgetRef ref,
    Capsule capsule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seal this capsule?'),
        content: Text(
          'Once sealed, nobody can see or change the contents until '
          '${_formatDate(capsule.unlockAt)}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seal'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(capsulesProvider.notifier).seal(capsule.id);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Capsule capsule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this capsule?'),
        content: const Text(
          'This capsule and all its contents will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(capsulesProvider.notifier).delete(capsule.id);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _addEntry(
    BuildContext context,
    WidgetRef ref,
    Capsule capsule,
  ) async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.section),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add to capsule',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: controller,
                  maxLength: CapsuleRules.maxMessage,
                  maxLines: 4,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Write a message for the future…',
                  ),
                ),
                const SizedBox(height: Space.md),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isNotEmpty) Navigator.pop(context, value);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (text != null && text.isNotEmpty && context.mounted) {
      await ref.read(capsulesProvider.notifier).addEntry(capsule.id, text);
    }
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.message,
  });
  final IconData icon;
  final String label, message;

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: accents.recessed,
        borderRadius: BorderRadius.circular(CircleRadius.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accents.caption),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CircleTextStyles.label(accents.title)),
                const SizedBox(height: Space.xs),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: accents.caption),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: CircleDepth.glassPanel(context, radius: CircleRadius.tile),
      child: Column(
        children: [
          Icon(icon, size: 20, color: accents.calm),
          const SizedBox(height: Space.sm),
          Text(value, style: CircleTextStyles.sectionTitle(accents.title)),
          Text(label, style: CircleTextStyles.caption(accents.caption)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Capsule create form
// ---------------------------------------------------------------------------

class CapsuleCreateScreen extends ConsumerStatefulWidget {
  const CapsuleCreateScreen({super.key, this.groupId});
  final String? groupId;

  @override
  ConsumerState<CapsuleCreateScreen> createState() =>
      _CapsuleCreateScreenState();
}

class _CapsuleCreateScreenState extends ConsumerState<CapsuleCreateScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String? _groupId;
  DateTime? _unlockAt;
  String? _titleError, _messageError, _dateError, _groupError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _unlockAt ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: CapsuleRules.minDaysAhead)),
      lastDate: now.add(const Duration(days: CapsuleRules.maxDaysAhead)),
      helpText: 'When should this capsule unlock?',
    );
    if (picked != null) {
      setState(() {
        _unlockAt = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _submit() async {
    final now = DateTime.now();
    var hasError = false;

    final titleCheck = CapsuleRules.checkTitle(_title.text);
    if (!titleCheck.allowed) {
      setState(() => _titleError = titleCheck.reason);
      hasError = true;
    } else {
      setState(() => _titleError = null);
    }

    final msgCheck = CapsuleRules.checkMessage(_message.text);
    if (!msgCheck.allowed) {
      setState(() => _messageError = msgCheck.reason);
      hasError = true;
    } else {
      setState(() => _messageError = null);
    }

    if (_unlockAt == null) {
      setState(() => _dateError = 'Pick an unlock date.');
      hasError = true;
    } else {
      final dateCheck = CapsuleRules.checkUnlockDate(_unlockAt!, now);
      if (!dateCheck.allowed) {
        setState(() => _dateError = dateCheck.reason);
        hasError = true;
      } else {
        setState(() => _dateError = null);
      }
    }

    if (_groupId == null) {
      setState(() => _groupError = 'Choose a Circle for this capsule.');
      hasError = true;
    } else {
      setState(() => _groupError = null);
    }

    if (hasError) return;

    setState(() => _busy = true);
    try {
      final capsule = await ref
          .read(capsulesProvider.notifier)
          .create(
            groupId: _groupId!,
            title: _title.text,
            message: _message.text,
            unlockAt: _unlockAt!,
          );
      if (mounted) context.go('/capsules/c/${capsule.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create capsule: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accents = CircleAccents.of(context);
    final theme = Theme.of(context);

    return WorkspaceView(
      builder: (workspace) {
        final groups = workspace.groups;
        return ReadingPane(
          maxWidth: 640,
          child: ListView(
            padding: CircleInsets.form,
            children: [
              // Hero illustration with shimmer glow
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.section),
                child: Center(
                  child: CircleShimmerGlow(
                    color: accents.calm,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: accents.calmContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CircleIcons.timer,
                        size: 40,
                        color: accents.calm,
                      ),
                    ),
                  ),
                ),
              ),

              // Title field
              TextField(
                controller: _title,
                maxLength: CapsuleRules.maxTitle,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Capsule title',
                  hintText: 'e.g. "Open on graduation day"',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: CircleFormMetrics.fieldGap),

              // Message field
              TextField(
                controller: _message,
                maxLength: CapsuleRules.maxMessage,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'A note for when it unlocks…',
                  errorText: _messageError,
                ),
              ),
              const SizedBox(height: CircleFormMetrics.fieldGap),

              // Group picker
              Text('Circle', style: theme.textTheme.labelMedium),
              const SizedBox(height: Space.sm),
              if (groups.isEmpty)
                Text(
                  'Join a Circle first.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accents.caption,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _groupId,
                  decoration: InputDecoration(
                    errorText: _groupError,
                    hintText: 'Choose a Circle',
                  ),
                  items: groups
                      .map(
                        (g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _groupId = v;
                    _groupError = null;
                  }),
                ),
              const SizedBox(height: CircleFormMetrics.fieldGap),

              // Unlock date picker
              Text('Unlock date', style: theme.textTheme.labelMedium),
              const SizedBox(height: Space.sm),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(CircleIcons.calendar),
                label: Text(
                  _unlockAt != null ? _formatDate(_unlockAt!) : 'Pick a date',
                ),
              ),
              if (_dateError != null) ...[
                const SizedBox(height: Space.xs),
                Text(
                  _dateError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],

              // Duration preview
              if (_unlockAt != null) ...[
                const SizedBox(height: Space.sm),
                Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: accents.calmContainer,
                    borderRadius: BorderRadius.circular(CircleRadius.tile),
                  ),
                  child: Row(
                    children: [
                      Icon(CircleIcons.clock, size: 18, color: accents.calm),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          _durationPreview(_unlockAt!),
                          style: CircleTextStyles.label(accents.calmText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: CircleFormMetrics.sectionGap),

              // Create button
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Create capsule'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _durationPreview(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      final remaining = diff.inDays - years * 365;
      final months = (remaining / 30).floor();
      if (months > 0) return 'Opens in $years years, $months months';
      return 'Opens in $years ${years == 1 ? 'year' : 'years'}';
    }
    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return 'Opens in $months ${months == 1 ? 'month' : 'months'}';
    }
    return 'Opens in ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
  }
}
