import '../../profile/application/server_blocks.dart';
import 'invite_link_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_icons.dart';
import '../../../core/design/circle_typography.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/contact_invitations.dart';

/// Tab filter for the invitation inbox.
enum _InviteTab { received, sent, expired }

class ContactInvitationInbox extends ConsumerStatefulWidget {
  const ContactInvitationInbox({super.key, this.invitationId});
  final String? invitationId;
  @override
  ConsumerState<ContactInvitationInbox> createState() =>
      _ContactInvitationInboxState();
}

class _ContactInvitationInboxState
    extends ConsumerState<ContactInvitationInbox> {
  final _items = <ContactInvitation>[];
  String? _message;
  bool _busy = false, _more = false;
  Object? _error;
  int _revision = 0;
  BlockScope? _itemsScope;
  _InviteTab _tab = _InviteTab.received;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load());
  }

  Future<void> _blockInviter(ContactInvitation item) async {
    final person = item.inviterId;
    if (person == null || _busy) return;
    final actions = ref.read(blockActionsProvider);
    final scope = _itemsScope;
    if (scope == null || !_items.contains(item)) return;
    if (!await confirmCircleAction(
      context,
      title: 'Block ${item.inviterName}?',
      message:
          'Stop direct Circle invitations and personal reply alerts. Shared-group profiles, photos, Memories and comments stay visible. This invitation will expire. No alert is sent.',
      confirm: 'Block',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _revision++;
      _items.clear();
      _itemsScope = null;
      _message = null;
    });
    await runCalmly(
      context,
      () => actions.change(scope, person, blocked: true),
      success: 'Blocked.',
    );
    if (mounted) await _load();
  }

  Future<void> _load({bool more = false}) async {
    final client = ref.read(contactInvitationClientProvider);
    if (client == null || _busy) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      List<ContactInvitation> items;
      var hasMore = false;
      if (widget.invitationId != null) {
        items = [await client.detail(widget.invitationId!)];
        hasMore = false;
      } else {
        final page = await client.list(offset: more ? _items.length : 0);
        items = page.items.map(ContactInvitation.fromJson).toList();
        final total = page.pagination['total'];
        hasMore =
            total is int && (more ? _items.length : 0) + items.length < total;
      }
      if (!mounted ||
          revision != _revision ||
          !identical(ref.read(contactInvitationClientProvider), client) ||
          client.api.sessionRevision != client.session) {
        return;
      }
      setState(() {
        _itemsScope = BlockScope(client.api, client.account, client.session);
        _more = hasMore;
        if (!more) _items.clear();
        _items.addAll(items);
      });
    } catch (error) {
      if (mounted && revision == _revision) setState(() => _error = error);
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _respond(ContactInvitation invitation, bool accept) async {
    final client = ref.read(contactInvitationClientProvider);
    if (client == null || _busy) return;
    final revision = ++_revision;
    var responded = false;
    setState(() => _busy = true);
    try {
      final status = await client.respond(invitation.id, accept: accept);
      if (!mounted ||
          !identical(ref.read(contactInvitationClientProvider), client) ||
          client.api.sessionRevision != client.session) {
        return;
      }
      if (status == 'joined') {
        await ref.read(circleWorkspaceProvider.notifier).refresh();
      }
      if (!mounted ||
          revision != _revision ||
          !identical(ref.read(contactInvitationClientProvider), client) ||
          client.api.sessionRevision != client.session) {
        return;
      }
      responded = true;
      setState(() {
        _items.removeWhere((item) => item.id == invitation.id);
        _message = status == 'pending_approval'
            ? 'Request sent. A group admin will review it.'
            : status == 'joined'
            ? 'You joined the circle.'
            : status == 'declined'
            ? 'Invitation declined.'
            : 'Invitation accepted.';
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        showCircleMessage(context, error.toString());
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _busy = false);
        if (responded) await _load();
      }
    }
  }

  List<ContactInvitation> get _filtered {
    switch (_tab) {
      case _InviteTab.received:
        return _items.where((i) => i.status == 'pending').toList();
      case _InviteTab.sent:
        return _items.where((i) => i.status == 'accepted').toList();
      case _InviteTab.expired:
        return _items
            .where((i) => i.status == 'expired' || i.status == 'declined')
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contactInvitationClientProvider, (_, next) {
      _revision++;
      _itemsScope = null;
      _items.clear();
      _message = null;
      _busy = false;
      _more = false;
      _error = null;
      Future.microtask(_load);
      if (mounted) setState(() {});
    });
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final received = _items.where((i) => i.status == 'pending').length;
    final sent = _items.where((i) => i.status == 'accepted').length;
    final filtered = _filtered;

    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          // Title row.
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(
              'Circle Invitations',
              style: CircleTextStyles.pageTitle(theme.colorScheme.onSurface),
            ),
          ),
          // Tab bar: Received / Sent / Expired.
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(
              children: [
                Expanded(
                  child: _InviteTabChip(
                    icon: LucideIcons.mail,
                    label: 'Received${received > 0 ? ' ($received)' : ''}',
                    selected: _tab == _InviteTab.received,
                    onTap: () => setState(() => _tab = _InviteTab.received),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _InviteTabChip(
                    icon: LucideIcons.send,
                    label: 'Sent${sent > 0 ? ' ($sent)' : ''}',
                    selected: _tab == _InviteTab.sent,
                    onTap: () => setState(() => _tab = _InviteTab.sent),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _InviteTabChip(
                    icon: LucideIcons.clock,
                    label: 'Expired',
                    selected: _tab == _InviteTab.expired,
                    onTap: () => setState(() => _tab = _InviteTab.expired),
                  ),
                ),
              ],
            ),
          ),
          if (_busy && _items.isEmpty) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                _message!,
                style: CircleTextStyles.body(accents.caption),
              ),
            ),
          if (_error != null) ...[
            const CircleEmpty(
              title: 'Could not load invitations',
              message: 'Please check your connection and try again.',
            ),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _load(),
                child: const Text('Try again'),
              ),
            ),
          ],
          if (!_busy && _error == null && filtered.isEmpty)
            CircleEmpty(
              title: switch (_tab) {
                _InviteTab.received => 'No invitations waiting',
                _InviteTab.sent => 'No sent invitations',
                _InviteTab.expired => 'No expired invitations',
              },
              message: switch (_tab) {
                _InviteTab.received =>
                  'Invitations from people you know will appear here.',
                _InviteTab.sent =>
                  'Invitations you have accepted will appear here.',
                _InviteTab.expired =>
                  'Expired and declined invitations will appear here.',
              },
              action: _tab == _InviteTab.received
                  ? TextButton.icon(
                      onPressed: () => openInviteLinkDialog(context, ref),
                      icon: const Icon(LucideIcons.link),
                      label: const Text('Open an invite link'),
                    )
                  : null,
            ),
          for (final item in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: _InvitationCard(
                invitation: item,
                busy: _busy,
                onAccept: item.status == 'pending'
                    ? () => _respond(item, true)
                    : null,
                onDecline: item.status == 'pending'
                    ? () => _respond(item, false)
                    : null,
                onBlock:
                    item.inviterId != null &&
                        ref
                            .watch(circleFeaturesProvider)
                            .has(CircleFeature.blocking)
                    ? () => _blockInviter(item)
                    : null,
              ),
            ),
          if (_more)
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tab chip with icon + label, matching the Circles filter chip style.
class _InviteTabChip extends StatelessWidget {
  const _InviteTabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(CircleRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(CircleRadius.button),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Space.large),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CircleRadius.button),
            border: selected ? null : Border.all(color: accents.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: Space.md,
                color: selected ? theme.colorScheme.onPrimary : accents.caption,
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: CircleTextStyles.label(
                    selected ? theme.colorScheme.onPrimary : accents.caption,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rich invitation card matching the design reference.
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.busy,
    this.onAccept,
    this.onDecline,
    this.onBlock,
  });
  final ContactInvitation invitation;
  final bool busy;
  final VoidCallback? onAccept, onDecline, onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    final timeText = _invitationTimeLabel(invitation.expiresAt);

    return CircleSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accent top border for visual warmth.
          Container(
            height: Space.xs,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(CircleRadius.card),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: cover photo + group info + time.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group avatar / cover placeholder.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(CircleRadius.card),
                      child: CircleInitialAvatar(
                        icon: LucideIcons.users,
                        name: invitation.groupName,
                        size: CircleAvatarSize.hero,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  invitation.groupName,
                                  style: CircleTextStyles.cardTitle(
                                    theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timeText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: Space.sm,
                                  ),
                                  child: Text(
                                    timeText,
                                    style: CircleTextStyles.metadata(
                                      accents.caption,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            '${invitation.inviterName} invited you to join this Circle.',
                            style: CircleTextStyles.metadata(accents.caption),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                if (onAccept != null || onDecline != null) ...[
                  const SizedBox(height: Space.section),
                  // Accept / Decline buttons.
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      if (onAccept != null)
                        _AcceptButton(onPressed: busy ? null : onAccept),
                      if (onDecline != null)
                        _DeclineButton(onPressed: busy ? null : onDecline),
                    ],
                  ),
                ],
                if (invitation.status != 'pending')
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(
                      'Invitation ${invitation.status}',
                      style: CircleTextStyles.label(accents.caption),
                    ),
                  ),
                if (invitation.approvalRequired &&
                    invitation.status == 'pending')
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(
                      'A group admin may need to approve your request.',
                      style: CircleTextStyles.caption(accents.caption),
                    ),
                  ),
                if (onBlock != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(CircleRadius.button),
                      onTap: onBlock,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: CircleSizes.minTouchTarget,
                          minWidth: CircleSizes.minTouchTarget,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Block inviter',
                            style: CircleTextStyles.label(accents.caption),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(LucideIcons.check, size: 16),
    label: const Text('Accept'),
  );
}

/// Outlined "Decline" button with X icon.
class _DeclineButton extends StatelessWidget {
  const _DeclineButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(LucideIcons.x, size: 16),
    label: const Text('Decline'),
  );
}

/// Approximate creation time from the expiry (invitations expire in 7 days).
String _invitationTimeLabel(DateTime? expiresAt) {
  if (expiresAt == null) return '';
  final created = expiresAt.subtract(const Duration(days: 7));
  return circleTimeAgo(created);
}
