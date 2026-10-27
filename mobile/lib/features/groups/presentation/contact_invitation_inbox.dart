import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/contact_invitations.dart';

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load());
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

  @override
  Widget build(BuildContext context) {
    ref.listen(contactInvitationClientProvider, (_, next) {
      _revision++;
      _items.clear();
      _message = null;
      _busy = false;
      _more = false;
      _error = null;
      Future.microtask(_load);
      if (mounted) setState(() {});
    });
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          const CircleHeading(
            title: 'Invitations',
            subtitle: 'Your circles begin with your choice.',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          if (_error != null) ...[
            const Text('Invitations couldn’t load. Please try again.'),
            TextButton(
              onPressed: _busy ? null : () => _load(),
              child: const Text('Try again'),
            ),
          ],
          if (!_busy && _error == null && _items.isEmpty)
            const CircleEmpty(
              title: 'No invitations waiting',
              message: 'Invitations from people you know will appear here.',
            ),
          for (final item in _items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.groupName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${item.inviterName} invited you'),
                    if (item.status == 'pending') ...[
                      Text(
                        item.approvalRequired
                            ? 'A group admin may need to approve your request after you accept.'
                            : 'Accept to join this circle.',
                      ),
                      Wrap(
                        spacing: Space.sm,
                        children: [
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _respond(item, true),
                            child: const Text('Accept'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _respond(item, false),
                            child: const Text('Decline'),
                          ),
                        ],
                      ),
                    ] else
                      Text('Invitation ${item.status}'),
                  ],
                ),
              ),
            ),
          if (_more)
            TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Load more'),
            ),
          TextButton(
            onPressed: _busy ? null : () => _load(),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
