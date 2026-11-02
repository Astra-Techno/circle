import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../groups/domain/circle_group.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

IconData circleTypeIcon(CircleType type) => switch (type) {
  CircleType.family => LucideIcons.heart,
  CircleType.friends => LucideIcons.users,
  CircleType.school => LucideIcons.book_open,
  CircleType.college => LucideIcons.graduation_cap,
  CircleType.office => LucideIcons.briefcase,
  CircleType.club => LucideIcons.bike,
  CircleType.other => LucideIcons.circle,
};

String circleTypeLabel(CircleType type) =>
    '${type.name[0].toUpperCase()}${type.name.substring(1)}';

String circleRoleLabel(CircleRole role) => switch (role) {
  CircleRole.owner => 'Owner',
  CircleRole.admin => 'Admin',
  CircleRole.member => 'Member',
};

/// The design's colour family for a group type. Colour is never the only
/// signal: chips and pills always show the group's name as well.
CircleTone circleTypeTone(CircleType type) => switch (type) {
  CircleType.family || CircleType.friends => CircleTone.heart,
  CircleType.school || CircleType.college => CircleTone.calm,
  _ => CircleTone.sage,
};
