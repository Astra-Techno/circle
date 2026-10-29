import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/group_visuals.dart';

/// Asks for a pasted invite link or code, then opens its invitation.
Future<void> openInviteLinkDialog(BuildContext context, WidgetRef ref) async {
  final token = await showDialog<String>(
    context: context,
    builder: (context) => const _InviteLinkDialog(),
  );
  if (token == null || token.isEmpty || !context.mounted) return;
  context.push('/invite/${Uri.encodeComponent(token)}');
}

class _InviteLinkDialog extends StatefulWidget {
  const _InviteLinkDialog();
  @override
  State<_InviteLinkDialog> createState() => _InviteLinkDialogState();
}

class _InviteLinkDialogState extends State<_InviteLinkDialog> {
  final _input = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _open([String? value]) {
    final token = serverInviteToken(value ?? _input.text);
    if (token == null) {
      setState(() => _error = 'Paste the whole link or code.');
      return;
    }
    Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Open an invite link'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _input,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Invite link or code',
            hintText: '${inviteLinkPrefix}code',
            errorText: _error,
            errorMaxLines: 3,
          ),
          onSubmitted: _open,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _open, child: const Text('Open')),
    ],
  );
}

/// What someone sees after opening an invite link: just enough to decide.
class InviteLinkScreen extends ConsumerStatefulWidget {
  const InviteLinkScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<InviteLinkScreen> createState() => _InviteLinkScreenState();
}

class _InviteLinkScreenState extends ConsumerState<InviteLinkScreen> {
  late Future<InvitePreview> _preview = _load();
  bool _busy = false;

  @override
  void didUpdateWidget(InviteLinkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _preview = _load();
  }

  Future<InvitePreview> _load() =>
      ref.read(circleWorkspaceProvider.notifier).previewInvite(widget.token);

  Future<void> _join(GroupPreview group) async {
    setState(() => _busy = true);
    final outcome = await runCalmly(
      context,
      () =>
          ref.read(circleWorkspaceProvider.notifier).joinWithLink(widget.token),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == null) {
      setState(() => _preview = _load());
      return;
    }
    showCircleMessage(
      context,
      outcome == JoinOutcome.joined
          ? 'Welcome to ${group.name}.'
          : 'Request sent. You’ll see ${group.name} once an admin approves.',
    );
    // A server's invite preview never reveals the group's id.
    context.go(group.id.isEmpty ? '/groups' : '/groups/g/${group.id}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Invite'),
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/groups'),
      ),
    ),
    body: SafeArea(
      child: ReadingPane(
        child: FutureBuilder<InvitePreview>(
          future: _preview,
          builder: (context, snapshot) {
            final preview = snapshot.data;
            return ListView(
              padding: CircleInsets.form,
              children: [
                if (preview == null)
                  const CircleSkeleton(
                    shape: CircleSkeletonShape.cards,
                    count: 1,
                    label: 'Opening the invite',
                  )
                else
                  ..._content(context, preview),
              ],
            );
          },
        ),
      ),
    ),
  );

  List<Widget> _content(BuildContext context, InvitePreview preview) {
    final group = preview.group;
    CircleEmpty problem(String title, String message, {Widget? action}) =>
        CircleEmpty(
          title: title,
          message: message,
          action:
              action ??
              OutlinedButton(
                onPressed: () => context.go('/groups'),
                child: const Text('Back to groups'),
              ),
        );
    switch (preview.status) {
      case InviteLinkStatus.expired:
        return [
          problem(
            'This invite link has expired',
            'Ask the person who shared it for a new link.',
          ),
        ];
      case InviteLinkStatus.reset:
        return [
          problem(
            'This invite link no longer works',
            'An admin reset or turned off this link. Ask for the new one.',
          ),
        ];
      case InviteLinkStatus.exhausted:
        return [
          problem(
            'This invite link has reached its limit',
            'It has been used as many times as allowed. Ask for a new link.',
          ),
        ];
      case InviteLinkStatus.unknown:
        return [
          problem(
            'We couldn’t find that invite',
            'Check the link or code and try again.',
          ),
        ];
      case InviteLinkStatus.needsParent:
        return [
          problem(
            'Join ${group!.parentName ?? 'the parent group'} first',
            '${group.name} is a subgroup. Subgroups are open only to members of the group directly above them. Ask someone in ${group.parentName ?? 'that group'} for its link.',
          ),
        ];
      case InviteLinkStatus.alreadyMember:
        return [
          problem(
            'You’re already in ${group!.name}',
            'Nothing more to do.',
            action: FilledButton(
              onPressed: () => context.go('/groups/g/${group.id}'),
              child: const Text('Open group'),
            ),
          ),
        ];
      case InviteLinkStatus.alreadyRequested:
        return [
          problem(
            'Waiting for approval',
            'You asked to join ${group!.name}. An admin will review it.',
            action: OutlinedButton(
              onPressed: () => context.go('/groups/g/${group.id}'),
              child: const Text('View request'),
            ),
          ),
        ];
      case InviteLinkStatus.valid:
        final g = group!;
        return [
          Center(
            child: CircleInitialAvatar(
              icon: circleTypeIcon(g.type),
              tone: circleTypeTone(g.type),
              size: CircleAvatarSize.hero,
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            g.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Space.sm),
          Text(
            [
              circleTypeLabel(g.type),
              '${g.memberCount} ${g.memberCount == 1 ? 'member' : 'members'}',
              if (g.parentName != null) 'in ${g.parentName}',
            ].join(' · '),
            textAlign: TextAlign.center,
          ),
          if (preview.inviterName != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              'Link shared by ${preview.inviterName}',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: Space.section),
          FilledButton(
            onPressed: _busy ? null : () => _join(g),
            child: Text(g.approvalRequired ? 'Ask to join' : 'Join group'),
          ),
          const SizedBox(height: Space.md),
          Text(
            g.approvalRequired
                ? 'An admin reviews requests. Until then you’ll only see the group’s name.'
                : 'You’ll join right away and can leave at any time.',
            textAlign: TextAlign.center,
          ),
        ];
    }
  }
}
