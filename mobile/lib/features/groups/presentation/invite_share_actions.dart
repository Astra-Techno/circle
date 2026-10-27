import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/invite_sharing.dart';

class InviteShareActions extends ConsumerStatefulWidget {
  const InviteShareActions({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<InviteShareActions> createState() => _InviteShareActionsState();
}

class _InviteShareActionsState extends ConsumerState<InviteShareActions> {
  bool _busy = false;
  Future<void> _share(InviteShareTarget target) async {
    if (_busy) return;
    if (target == InviteShareTarget.smsContact) {
      final chosen = await showModalBottomSheet<InviteShareTarget>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheet) => SingleChildScrollView(
          padding: CircleInsets.form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Invite by SMS',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: Space.md),
              const Text(
                'Only the number you select is used. Your address book isn’t uploaded. You review and send the message.',
              ),
              const SizedBox(height: Space.md),
              ListTile(
                leading: const Icon(Icons.contacts_outlined),
                title: const Text('Choose a contact'),
                onTap: () => Navigator.pop(sheet, InviteShareTarget.smsContact),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Enter number in SMS app'),
                onTap: () => Navigator.pop(sheet, InviteShareTarget.smsManual),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
      if (chosen == null || !mounted) return;
      target = chosen;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    await runCalmly(context, () async {
      final result = await ref
          .read(inviteSharingProvider)
          .share(widget.groupId, target);
      if (result == InviteShareResult.opened && mounted) {
        showCircleMessage(
          context,
          'Messaging app opened. Review the invite before sending.',
        );
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(inviteShareBridgeProvider).supported) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.md),
        const Text(
          'Choose recipients in WhatsApp, or pick one contact for SMS. Nothing is sent until you confirm in that app.',
        ),
        const SizedBox(height: Space.md),
        if (_busy)
          const LinearProgressIndicator(
            semanticsLabel: 'Opening invite sharing',
          ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _share(InviteShareTarget.whatsapp),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _share(InviteShareTarget.smsContact),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('SMS'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _share(InviteShareTarget.other),
              icon: const Icon(Icons.share_outlined),
              label: const Text('More apps'),
            ),
          ],
        ),
      ],
    );
  }
}
