import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../auth/domain/access_validation.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../application/contact_invitations.dart';
import '../application/invite_sharing.dart';
import '../domain/membership_rules.dart';

class ContactInviteScreen extends ConsumerStatefulWidget {
  const ContactInviteScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<ContactInviteScreen> createState() =>
      _ContactInviteScreenState();
}

class _ContactInviteScreenState extends ConsumerState<ContactInviteScreen> {
  bool _busy = false;
  String? _status, _phone;
  ContactInviteScope? _scope;
  bool _share = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _choose();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showCircleMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() => _run(() async {
    final service = ref.read(contactInvitationsProvider);
    final scope = service.capture(widget.groupId);
    final raw = await service.pick(scope);
    if (!mounted || raw == null) return;
    final phone = await _confirmNumber(raw);
    if (!mounted || phone == null) return;
    service.validate(scope);
    final confirmed = await confirmCircleAction(
      context,
      title: 'Invite this contact?',
      message:
          'Send an invitation to $phone? If they use CIRCLE, they choose whether to accept. Otherwise you can share a link.',
      confirm: 'Send invitation',
    );
    if (!mounted || !confirmed) return;
    final result = await service.send(scope, phone);
    if (!mounted) return;
    setState(() {
      _phone = phone;
      _scope = scope;
      _share = result.outcome == 'share_link';
      _status = switch (result.outcome) {
        'invited' => 'Invitation sent. They choose whether to accept.',
        'already_pending' =>
          'An invitation is already waiting for their response.',
        'already_member' => 'This person is already in the circle.',
        'share_link' => 'Share an invitation with this contact.',
        _ => 'An invitation can’t be sent to this contact right now.',
      };
    });
  });
  Future<String?> _confirmNumber(String raw) async {
    final input = TextEditingController(
      text: AccessValidation.normalizeMobile(raw),
    );
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm mobile number'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: input,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mobile with country code',
              helperText: 'Confirm the country code, for example +91.',
            ),
            validator: AccessValidation.mobile,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  AccessValidation.normalizeMobile(input.text),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    // The dialog's route may still animate after its result completes.
    return result;
  }

  Future<void> _copy() => _run(() async {
    final service = ref.read(contactInvitationsProvider);
    final scope = service.capture(widget.groupId);
    final link = await service.link(scope);
    service.validate(scope);
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showCircleMessage(context, 'Invite link copied.');
  });
  Future<void> _compose(InviteShareTarget target) => _run(() async {
    final opened = await ref
        .read(contactInvitationsProvider)
        .share(_scope!, target, _phone!);
    if (!opened && mounted) {
      showCircleMessage(
        context,
        'Messaging app unavailable. Copy the invite link instead.',
      );
    }
  });
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final group = workspace.group(widget.groupId);
      if (group == null ||
          !MembershipRules.canInvite(group, workspace.viewer).allowed) {
        return const CircleEmpty(
          title: 'Inviting is limited here',
          message: 'Open the group to check your access.',
        );
      }
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            CircleHeading(
              title: 'Invite to ${group.name}',
              subtitle: 'Choose one person. They decide whether to join.',
            ),
            const SizedBox(height: Space.lg),
            if (_busy) const LinearProgressIndicator(),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.lg),
                child: Text(
                  _status!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            FilledButton.icon(
              onPressed: _busy ? null : _choose,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Choose contact'),
            ),
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : _copy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy invite link'),
            ),
            if (_share) ...[
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _compose(InviteShareTarget.whatsapp),
                    child: const Text('WhatsApp'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _compose(InviteShareTarget.smsManual),
                    child: const Text('SMS'),
                  ),
                ],
              ),
              const Text(
                'WhatsApp lets you choose the recipient. Nothing is sent automatically.',
              ),
            ],
            const SizedBox(height: Space.lg),
            const Text(
              'Only the selected number is checked after you confirm. Your address book is never uploaded.',
            ),
            TextButton(
              onPressed: () =>
                  context.push('/groups/g/${widget.groupId}/invite/link'),
              child: const Text('Manage invite link'),
            ),
          ],
        ),
      );
    },
  );
}
