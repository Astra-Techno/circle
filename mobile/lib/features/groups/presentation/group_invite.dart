import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/feature_gate.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../domain/membership_rules.dart';
import 'invite_share_actions.dart';
import '../application/invite_sharing.dart';

const _expiryChoices = [
  Duration(days: 1),
  Duration(days: 7),
  Duration(days: 30),
];
const _limitChoices = <int?>[null, 10, 25, 100];

String _days(Duration duration) =>
    duration.inDays == 1 ? '1 day' : '${duration.inDays} days';

String linkStatus(InviteLink link, DateTime now) {
  final left = link.expiresAt.difference(now);
  final expiry = link.expiredAt(now)
      ? 'Expired'
      : left.inHours < 24
      ? 'Expires within a day'
      : 'Expires in ${_days(Duration(days: (left.inHours / 24).ceil()))}';
  final uses = link.maxUses == null
      ? '${link.uses} ${link.uses == 1 ? 'use' : 'uses'}, no limit'
      : '${link.uses} of ${link.maxUses} uses';
  return '$expiry · $uses';
}

/// Invite link and direct additions for one group.
class GroupInviteScreen extends ConsumerWidget {
  const GroupInviteScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => WorkspaceView(
    builder: (workspace) {
      final group = workspace.group(groupId);
      final viewer = workspace.viewer;
      final rule = group == null
          ? const RuleResult.denied('This group is not shared with you.')
          : MembershipRules.canInvite(group, viewer);
      if (!rule.allowed) {
        return ReadingPane(
          child: ListView(
            padding: CircleInsets.form,
            children: [
              CircleEmpty(
                title: 'Inviting is limited here',
                message: rule.reason!,
              ),
            ],
          ),
        );
      }
      final g = group!;
      final controller = ref.read(circleWorkspaceProvider.notifier);
      final features = ref.watch(circleFeaturesProvider);
      final direct = features.has(CircleFeature.directInvitations);
      final link = g.inviteLink;
      final linkText = link == null
          ? ''
          : (features.server
                    ? ref.watch(inviteSharingProvider).linkFor(g.id)
                    : null) ??
                inviteLinkFor(link.token);
      final canManage = MembershipRules.canManageLink(g, viewer).allowed;
      final parent = workspace.group(g.parentId ?? '');
      final invited = workspace.sentInvitations
          .where((invitation) => invitation.groupId == g.id)
          .map((invitation) => invitation.invitee)
          .toSet();
      final candidates = parent == null
          ? const <String>[]
          : (parent.roles.keys
                .where((p) => !g.isMember(p) && !invited.contains(p))
                .toList()
              ..sort(
                (a, b) => workspace.nameOf(a).compareTo(workspace.nameOf(b)),
              ));
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form,
          children: [
            CircleHeading(
              title: 'Invite to\n${g.name}',
              subtitle: g.approvalRequired
                  ? 'People who use the link wait for an admin to approve them.'
                  : 'People who use the link join right away.',
            ),
            const PreviewNotice(
              'Preview link — not shareable. It only works inside this preview.',
              server:
                  'Share this link only with people you know. Recipients can open CIRCLE or download the app, then review the invitation.',
            ),
            if (link == null)
              FilledButton.icon(
                onPressed: () => runCalmly(
                  context,
                  () => controller.createInviteLink(g.id),
                  success: 'Invite link ready.',
                ),
                icon: const Icon(Icons.add_link),
                label: const Text('Create invite link'),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        linkText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Space.sm),
                      Text(linkStatus(link, DateTime.now().toUtc())),
                      const SizedBox(height: Space.lg),
                      FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: linkText),
                          );
                          if (context.mounted) {
                            showCircleMessage(
                              context,
                              features.server
                                  ? 'Copied.'
                                  : 'Copied. It only opens inside this preview.',
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(
                          features.server
                              ? 'Copy invite link'
                              : 'Copy preview link',
                        ),
                      ),
                      if (features.server &&
                          !link.expiredAt(DateTime.now().toUtc()) &&
                          !link.exhausted)
                        InviteShareActions(groupId: g.id),
                    ],
                  ),
                ),
              ),
            if (link != null && canManage)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('More options'),
                childrenPadding: const EdgeInsets.only(bottom: Space.lg),
                children: [
                  DropdownButtonFormField<Duration>(
                    initialValue: _closestExpiry(link),
                    decoration: const InputDecoration(
                      labelText: 'Link expires after',
                    ),
                    items: [
                      for (final choice in _expiryChoices)
                        DropdownMenuItem(
                          value: choice,
                          child: Text(_days(choice)),
                        ),
                    ],
                    onChanged: (expiry) {
                      if (expiry == null) return;
                      runCalmly(
                        context,
                        () => controller.configureInviteLink(
                          g.id,
                          expiry: expiry,
                          maxUses: link.maxUses,
                        ),
                        success: 'Link now expires in ${_days(expiry)}.',
                      );
                    },
                  ),
                  const SizedBox(height: Space.lg),
                  DropdownButtonFormField<int?>(
                    initialValue: _limitChoices.contains(link.maxUses)
                        ? link.maxUses
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Maximum uses',
                    ),
                    items: [
                      for (final choice in _limitChoices)
                        DropdownMenuItem(
                          value: choice,
                          child: Text(choice == null ? 'No limit' : '$choice'),
                        ),
                    ],
                    onChanged: (limit) => runCalmly(
                      context,
                      () => controller.configureInviteLink(
                        g.id,
                        expiry: _closestExpiry(link),
                        maxUses: limit,
                      ),
                      success: limit == null
                          ? 'Usage limit removed.'
                          : 'Link limited to $limit uses.',
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await confirmCircleAction(
                            context,
                            title: 'Reset the invite link?',
                            message:
                                'The current link stops working for everyone. You’ll get a new one to share.',
                            confirm: 'Reset link',
                          );
                          if (ok && context.mounted) {
                            await runCalmly(
                              context,
                              () => controller.resetInviteLink(g.id),
                              success:
                                  'New link ready. The old link no longer works.',
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset link'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final ok = await confirmCircleAction(
                            context,
                            title: 'Turn off the invite link?',
                            message:
                                'Nobody can join with it any more. You can create a new link later.',
                            confirm: 'Turn off',
                          );
                          if (ok && context.mounted) {
                            await runCalmly(
                              context,
                              () => controller.revokeInviteLink(g.id),
                              success: 'Invite link turned off.',
                            );
                          }
                        },
                        child: const Text('Turn off link'),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: Space.section),
            if (parent != null && direct) ...[
              Text(
                'Add people from ${parent.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Space.sm),
              const Text(
                'They’ll get an invitation and join only if they accept.',
              ),
              const SizedBox(height: Space.md),
              if (candidates.isEmpty)
                Text('Everyone in ${parent.name} is already here or invited.'),
              for (final person in candidates)
                CircleRow(
                  child: ListTile(
                    leading: CircleInitialAvatar(
                      name: workspace.nameOf(person),
                    ),
                    title: Text(workspace.nameOf(person)),
                    trailing: TextButton(
                      onPressed: () => runCalmly(
                        context,
                        () => controller.inviteMember(g.id, person),
                        success:
                            'Invitation sent. ${workspace.nameOf(person)} needs to accept.',
                      ),
                      child: Text(
                        'Invite',
                        semanticsLabel: 'Invite ${workspace.nameOf(person)}',
                      ),
                    ),
                  ),
                ),
            ] else
              const Text(
                'Share the link with people you know. There is no public search.',
              ),
          ],
        ),
      );
    },
  );

  static Duration _closestExpiry(InviteLink link) {
    final total = link.expiresAt.difference(link.createdAt);
    return _expiryChoices.reduce(
      (best, choice) =>
          (choice - total).abs() < (best - total).abs() ? choice : best,
    );
  }
}
