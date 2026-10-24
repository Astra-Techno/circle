import 'circle_group.dart';

class GroupTreeEntry {
  const GroupTreeEntry({
    required this.group,
    required this.level,
    required this.path,
    required this.hasChildren,
    required this.expanded,
  });
  final CircleGroup group;

  /// 0 for a top-level entry in this tree (its parent is not in the list).
  final int level;

  /// Ancestor names from the top of this tree down to the parent.
  final List<String> path;
  final bool hasChildren, expanded;
}

int _compare(CircleGroup a, CircleGroup b) {
  final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return name != 0 ? name : a.order.compareTo(b.order);
}

/// Orders [groups] as a tree: each parent followed by its children,
/// recursively, with siblings sorted by name then creation order.
/// Children of a collapsed id are omitted.
List<GroupTreeEntry> buildGroupTree(
  Iterable<CircleGroup> groups, {
  Set<String> collapsed = const {},
}) {
  final byId = {for (final group in groups) group.id: group};
  final children = <String?, List<CircleGroup>>{};
  for (final group in byId.values) {
    final parent = byId.containsKey(group.parentId) ? group.parentId : null;
    children.putIfAbsent(parent, () => []).add(group);
  }
  for (final list in children.values) {
    list.sort(_compare);
  }
  final result = <GroupTreeEntry>[];
  void visit(CircleGroup group, int level, List<String> path) {
    final kids = children[group.id] ?? const [];
    final expanded = !collapsed.contains(group.id);
    result.add(
      GroupTreeEntry(
        group: group,
        level: level,
        path: path,
        hasChildren: kids.isNotEmpty,
        expanded: expanded,
      ),
    );
    if (!expanded || level >= maxGroupDepth) return;
    for (final child in kids) {
      visit(child, level + 1, [...path, group.name]);
    }
  }

  for (final root in children[null] ?? const <CircleGroup>[]) {
    visit(root, 0, const []);
  }
  return result;
}

/// Ancestors of [group] from the root down to the group itself, limited to
/// [groups] the caller can see.
List<CircleGroup> groupLineage(
  CircleGroup group,
  Map<String, CircleGroup> groups,
) {
  final lineage = <CircleGroup>[group];
  var parentId = group.parentId;
  while (parentId != null && lineage.length < maxGroupDepth) {
    final parent = groups[parentId];
    if (parent == null) break;
    lineage.insert(0, parent);
    parentId = parent.parentId;
  }
  return lineage;
}

/// Where a group sits, as shown on audience pills: "Root › Group", or
/// "Root › … › Group" when it is nested deeper. Only uses groups the viewer
/// can see; an unknown parent simply ends the walk.
String audiencePath(CircleGroup group, Map<String, CircleGroup> byId) {
  final chain = <String>[group.name];
  var parentId = group.parentId;
  while (parentId != null) {
    final parent = byId[parentId];
    if (parent == null) break;
    chain.insert(0, parent.name);
    parentId = parent.parentId;
  }
  if (chain.length <= 2) return chain.join(' › ');
  return '${chain.first} › … › ${chain.last}';
}
