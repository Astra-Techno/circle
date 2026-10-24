import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../groups/domain/circle_group.dart';

IconData circleTypeIcon(CircleType type) => switch (type) {
  CircleType.family => Icons.favorite_outline,
  CircleType.friends => Icons.people_outline,
  CircleType.school => Icons.menu_book_outlined,
  CircleType.college => Icons.school_outlined,
  CircleType.office => Icons.work_outline,
  CircleType.club => Icons.directions_bike_outlined,
  CircleType.other => Icons.blur_circular,
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
