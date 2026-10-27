import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/contact_invitations.dart';

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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mark_email_unread_outlined),
        title: const Text('Invitations for you'),
        subtitle: Text(
          _error
              ? 'Couldn’t check invitations. Tap refresh to retry.'
              : _busy
              ? 'Checking invitations…'
              : _count == null
              ? 'Review your invitations'
              : _count == 0
              ? 'No invitations waiting'
              : '$_count waiting on the latest page',
        ),
        trailing: IconButton(
          tooltip: 'Refresh invitations',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        onTap: () async {
          await context.push('/you/invitations');
          if (mounted) _load();
        },
      ),
    );
  }
}
