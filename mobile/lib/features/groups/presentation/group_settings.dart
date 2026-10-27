import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/presentation/workspace_view.dart';
import '../domain/membership_rules.dart';

class GroupSettingsScreen extends StatelessWidget {
  const GroupSettingsScreen({super.key, required this.groupId});
  final String groupId;
  @override
  Widget build(BuildContext context) => WorkspaceView(
    builder: (workspace) {
      final group = workspace.group(groupId);
      if (group == null) {
        return const ReadingPane(
          child: CircleEmpty(
            title: 'This circle is private',
            message: 'You need membership in this exact group.',
          ),
        );
      }
      return _GroupSettings(
        key: ValueKey(group.id),
        group: group,
        workspace: workspace,
      );
    },
  );
}

class _GroupSettings extends ConsumerStatefulWidget {
  const _GroupSettings({
    super.key,
    required this.group,
    required this.workspace,
  });
  final CircleGroup group;
  final CircleWorkspace workspace;
  @override
  ConsumerState<_GroupSettings> createState() => _GroupSettingsState();
}

class _GroupSettingsState extends ConsumerState<_GroupSettings> {
  late final _name = TextEditingController(text: widget.group.name);
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CircleWorkspaceController get _controller =>
      ref.read(circleWorkspaceProvider.notifier);

  Future<void> _saveName() async {
    setState(() => _nameError = null);
    try {
      await _controller.updateSettings(widget.group.id, name: _name.text);
      if (mounted) showCircleMessage(context, 'Name saved.');
    } on CircleFailure catch (failure) {
      if (mounted) setState(() => _nameError = failure.message);
    }
  }

  Future<void> _transfer() async {
    final group = widget.group;
    final workspace = widget.workspace;
    final others = group.roles.keys.where((p) => p != workspace.viewer);
    final person = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose the new owner'),
        children: [
          for (final person in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, person),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Text(workspace.nameOf(person)),
              ),
            ),
        ],
      ),
    );
    if (person == null || !mounted) return;
    final name = workspace.nameOf(person);
    final ok = await confirmCircleAction(
      context,
      title: 'Make $name the owner?',
      message:
          'You’ll become an admin. Only $name will be able to transfer ownership back.',
      confirm: 'Make owner',
    );
    if (ok && mounted) {
      await runCalmly(
        context,
        () => _controller.transferOwnership(group.id, person),
        success: '$name now owns ${group.name}.',
      );
    }
  }

  Future<void> _leave(List<CircleGroup> cascade) async {
    final group = widget.group;
    final also = cascade.where((item) => item.id != group.id);
    final ok = await confirmCircleAction(
      context,
      title: 'Leave ${group.name}?',
      message: also.isEmpty
          ? 'You’ll lose access to its Memories, events and chat. To come back, you’ll need a new invitation.'
          : 'You’ll lose access to ${group.name} and also leave these subgroups:',
      details: [for (final item in also) item.name],
      confirm: 'Leave',
    );
    if (!ok || !mounted) return;
    final done = await runCalmly(context, () async {
      await _controller.leaveGroup(group.id);
      return true;
    }, success: 'You left ${group.name}.');
    if (done == true && mounted) context.go('/groups');
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final workspace = widget.workspace;
    final viewer = workspace.viewer;
    final admin = MembershipRules.canEditSettings(group, viewer).allowed;
    final owner = group.roles[viewer] == CircleRole.owner;
    final parent = workspace.group(group.parentId ?? '');
    final features = ref.watch(circleFeaturesProvider);
    final cascade = MembershipRules.cascade(
      workspace.groupsById,
      group.id,
      viewer,
    );
    final leave = MembershipRules.canLeave(group, viewer, cascade);
    final theme = Theme.of(context);
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.form,
        children: [
          CircleHeading(
            title: 'Settings',
            subtitle: admin
                ? 'Changes apply to ${group.name} only. Subgroups keep their own settings.'
                : 'Only admins can change these settings.',
          ),
          if (admin) ...[
            TextField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Group name',
                errorText: _nameError,
                errorMaxLines: 3,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _name.text.trim() == group.name ? null : _saveName,
                child: const Text('Save name'),
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ask before people join'),
            subtitle: Text(
              group.approvalRequired
                  ? 'Admins approve people who use the link or ask to join.'
                  : 'People with the link join right away.',
            ),
            value: group.approvalRequired,
            onChanged: admin
                ? (value) => runCalmly(
                    context,
                    () => _controller.updateSettings(
                      group.id,
                      approvalRequired: value,
                    ),
                    success: value
                        ? 'New people now need approval.'
                        : 'People with the link now join directly.',
                    onUndo: undoWith(
                      context,
                      () => _controller.updateSettings(
                        group.id,
                        approvalRequired: !value,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: Space.md),
          DropdownButtonFormField<InvitePolicy>(
            initialValue: group.settings.invitePolicy,
            decoration: const InputDecoration(
              labelText: 'Who can invite people',
              helperText: 'Share the link or add people directly.',
              helperMaxLines: 3,
            ),
            items: const [
              DropdownMenuItem(
                value: InvitePolicy.adminsOnly,
                child: Text('Admins only'),
              ),
              DropdownMenuItem(
                value: InvitePolicy.allMembers,
                child: Text('All members'),
              ),
            ],
            onChanged: admin
                ? (policy) => runCalmly(
                    context,
                    () => _controller.updateSettings(
                      group.id,
                      invitePolicy: policy,
                    ),
                    success: policy == InvitePolicy.allMembers
                        ? 'All members can now invite people.'
                        : 'Only admins can now invite people.',
                  )
                : null,
          ),
          if (features.has(CircleFeature.events)) ...[
            const SizedBox(height: Space.md),
            DropdownButtonFormField<EventCreationPolicy>(
              initialValue: group.settings.eventCreation,
              decoration: const InputDecoration(
                labelText: 'Who can create events',
                helperText: 'Everyone in the group can always see and answer.',
                helperMaxLines: 3,
              ),
              items: const [
                DropdownMenuItem(
                  value: EventCreationPolicy.members,
                  child: Text('Everyone'),
                ),
                DropdownMenuItem(
                  value: EventCreationPolicy.admins,
                  child: Text('Admins only'),
                ),
              ],
              onChanged: admin
                  ? (policy) {
                      final previous = group.settings.eventCreation;
                      runCalmly(
                        context,
                        () => _controller.updateSettings(
                          group.id,
                          eventCreation: policy,
                        ),
                        success: policy == EventCreationPolicy.admins
                            ? 'Only admins can now create events.'
                            : 'Everyone can now create events.',
                        onUndo: undoWith(
                          context,
                          () => _controller.updateSettings(
                            group.id,
                            eventCreation: previous,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ],
          if (parent != null) ...[
            const SizedBox(height: Space.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('List in ${parent.name}'),
              subtitle: Text(
                group.hidden
                    ? 'Hidden: only invited people know it exists.'
                    : 'Members of ${parent.name} can see its name and ask to join.',
              ),
              value: !group.hidden,
              onChanged: admin
                  ? (listed) => runCalmly(
                      context,
                      () =>
                          _controller.updateSettings(group.id, hidden: !listed),
                      success: listed
                          ? 'Listed in ${parent.name}.'
                          : 'Hidden from ${parent.name}.',
                      onUndo: undoWith(
                        context,
                        () => _controller.updateSettings(
                          group.id,
                          hidden: listed,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
          if (admin && features.has(CircleFeature.moderation)) ...[
            const SizedBox(height: Space.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Reports and admin actions'),
              subtitle: features.server
                  ? const Text(
                      'Review reports privately with this group’s admins.',
                    )
                  : Text(switch (widget.workspace.openReports[group.id] ?? 0) {
                      0 => 'Nothing to review.',
                      1 => '1 report to review.',
                      final count => '$count reports to review.',
                    }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/groups/g/${group.id}/reports'),
            ),
          ],
          if (owner) ...[
            const SizedBox(height: Space.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Transfer ownership'),
              subtitle: const Text('Choose a member to own this group.'),
              trailing: const Icon(Icons.chevron_right),
              enabled: group.roles.length > 1,
              onTap: _transfer,
            ),
          ],
          const Divider(height: Space.hero * 2),
          Text('Leave group', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          if (leave.allowed) ...[
            Text(
              cascade.length > 1
                  ? 'Leaving also removes you from ${cascade.length - 1} ${cascade.length == 2 ? 'subgroup' : 'subgroups'} inside it.'
                  : 'You can come back only with a new invitation.',
            ),
            const SizedBox(height: Space.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () => _leave(cascade),
                child: Text('Leave ${group.name}'),
              ),
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(leave.reason!)),
              ],
            ),
        ],
      ),
    );
  }
}
