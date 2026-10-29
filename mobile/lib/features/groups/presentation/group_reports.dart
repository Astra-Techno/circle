import '../../moderation/presentation/server_reports.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../workspace/application/workspace_providers.dart';

/// C9: a group's reports, for that group's admins only. Reasons and counts,
/// never who reported. Subgroups show only name, size and reasons.
class GroupReportsScreen extends StatelessWidget {
  const GroupReportsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) => ServerReportsScreen(groupId: groupId);
}

class GroupReportsButton extends StatelessWidget {
  const GroupReportsButton({
    super.key,
    required this.group,
    required this.count,
  });
  final CircleGroup group;
  final int count;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => context.push('/groups/g/${group.id}/reports'),
    icon: const Icon(Icons.flag_outlined),
    label: Text(
      count == 0
          ? 'Reports'
          : count == 1
          ? '1 report'
          : '$count reports',
    ),
  );
}
