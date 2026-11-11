import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/contact_invitations.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';

/// Inbox discovery remains available when OS notifications are disabled.
class ContactInvitationEntry extends ConsumerStatefulWidget {
  const ContactInvitationEntry({super.key});
  @override
  ConsumerState<ContactInvitationEntry> createState() =>
      _ContactInvitationEntryState();
}

class _ContactInvitationEntryState extends ConsumerState<ContactInvitationEntry>
    with WidgetsBindingObserver {
  int? _count;
  bool _busy = false, _error = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final client = ref.read(contactInvitationClientProvider);
    if (_busy || client == null) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final page = await client.list();
      if (!mounted ||
          !identical(ref.read(contactInvitationClientProvider), client) ||
          client.api.sessionRevision != client.session) {
        return;
      }
      setState(
        () => _count = page.items
            .where((item) => item is Map && item['status'] == 'pending')
            .length,
      );
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contactInvitationClientProvider, (_, next) {
      if (mounted) setState(() => _count = null);
    });
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () async {
          await context.push('/you/invitations');
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.contentInset,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              // Mail icon with optional badge.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accents.calmContainer,
                      borderRadius: BorderRadius.circular(CircleRadius.card),
                    ),
                    child: SizedBox.square(
                      dimension: Space.hero,
                      child: Icon(
                        CircleIcons.mail,
                        size: Space.section,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (_count != null && _count! > 0)
                    Positioned(
                      top: -Space.xs,
                      right: -Space.xs,
                      child: Container(
                        padding: const EdgeInsets.all(Space.xs),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: Space.section,
                          minHeight: Space.section,
                        ),
                        child: Text(
                          '$_count',
                          textAlign: TextAlign.center,
                          style: CircleTextStyles.caption(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Circle Invitations',
                      style: CircleTextStyles.homeAuthor(
                        theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _error
                          ? 'Tap to check invitations'
                          : _busy
                          ? 'Checking...'
                          : _count == null
                          ? 'Review your invitations'
                          : _count == 0
                          ? 'No invitations waiting'
                          : '$_count pending',
                      style: CircleTextStyles.metadata(accents.caption),
                    ),
                  ],
                ),
              ),
              Icon(CircleIcons.chevronRight, color: accents.caption),
            ],
          ),
        ),
      ),
    );
  }
}
