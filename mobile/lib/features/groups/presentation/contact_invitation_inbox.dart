import '../../profile/application/server_blocks.dart';
import 'invite_link_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/design/circle_typography.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/contact_invitations.dart';

/// Tab filter for the invitation inbox.
enum _InviteTab { received, accepted, expired }

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
            ? 'Request sent. A Circle admin will review it.'
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
      case _InviteTab.accepted:
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
    final accents = CircleAccents.of(context);
    final received = _items.where((i) => i.status == 'pending').length;
    final accepted = _items.where((i) => i.status == 'accepted').length;
    final filtered = _filtered;

    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          const CircleHeading(
            title: 'Invitations',
            subtitle: 'Choose which circles to join.',
          ),
          // Tab bar: Received / Sent / Expired.
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                _InviteTabChip(
                  icon: CircleIcons.mail,
                  label: 'Received${received > 0 ? ' ($received)' : ''}',
                  selected: _tab == _InviteTab.received,
                  onTap: () => setState(() => _tab = _InviteTab.received),
                ),
                _InviteTabChip(
                  icon: CircleIcons.check,
                  label: 'Accepted${accepted > 0 ? ' ($accepted)' : ''}',
                  selected: _tab == _InviteTab.accepted,
                  onTap: () => setState(() => _tab = _InviteTab.accepted),
                ),
                _InviteTabChip(
                  icon: CircleIcons.clock,
                  label: 'Expired',
                  selected: _tab == _InviteTab.expired,
                  onTap: () => setState(() => _tab = _InviteTab.expired),
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => openInviteLinkDialog(context, ref),
              icon: const Icon(CircleIcons.link),
              label: const Text('Open an invite link'),
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
          if (_error != null)
            CircleEmpty(
              icon: CircleIcons.wifiOff,
              title: 'Could not load invitations',
              message: 'Please check your connection and try again.',
              action: OutlinedButton(
                onPressed: _busy ? null : () => _load(),
                child: const Text('Try again'),
              ),
            ),
          if (!_busy && _error == null && filtered.isEmpty)
            CircleEmpty(
              title: switch (_tab) {
                _InviteTab.received => 'No invitations waiting',
                _InviteTab.accepted => 'No accepted invitations',
                _InviteTab.expired => 'No expired invitations',
              },
              message: switch (_tab) {
                _InviteTab.received =>
                  'Invitations from people you know will appear here.',
                _InviteTab.accepted =>
                  'Invitations you have accepted will appear here.',
                _InviteTab.expired =>
                  'Expired and declined invitations will appear here.',
              },
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
  Widget build(BuildContext context) => ChoiceChip(
    avatar: Icon(
      icon,
      size: Space.md,
      color: selected
          ? Theme.of(context).colorScheme.onPrimary
          : CircleAccents.of(context).caption,
    ),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

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
                CircleIdentityHeader(
                  leading: CircleInitialAvatar(
                    icon: CircleIcons.members,
                    name: invitation.groupName,
                    size: CircleAvatarSize.hero,
                  ),
                  title: Semantics(
                    header: true,
                    child: Text(
                      invitation.groupName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  subtitle: Text(
                    '${invitation.inviterName} invited you to join this Circle.',
                    style: CircleTextStyles.metadata(accents.caption),
                  ),
                  trailing: timeText.isEmpty
                      ? null
                      : Text(
                          timeText,
                          style: CircleTextStyles.metadata(accents.caption),
                        ),
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
    icon: const Icon(CircleIcons.check, size: 16),
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
    icon: const Icon(CircleIcons.close, size: 16),
    label: const Text('Decline'),
  );
}

/// Approximate creation time from the expiry (invitations expire in 7 days).
String _invitationTimeLabel(DateTime? expiresAt) {
  if (expiresAt == null) return '';
  final created = expiresAt.subtract(const Duration(days: 7));
  return circleTimeAgo(created);
}
