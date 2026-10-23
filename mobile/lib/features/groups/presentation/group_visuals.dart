import 'package:flutter/material.dart';
import '../domain/circle_repository.dart';

IconData circleTypeIcon(CircleType type) => switch (type) {
  CircleType.family => Icons.favorite_outline,
  CircleType.friends => Icons.people_outline,
  CircleType.school => Icons.menu_book_outlined,
  CircleType.college => Icons.school_outlined,
  CircleType.office => Icons.work_outline,
  CircleType.club => Icons.directions_bike_outlined,
  CircleType.other => Icons.blur_circular,
};

String circleRoleLabel(CircleRole role) => switch (role) {
  CircleRole.owner => 'Owner',
  CircleRole.admin => 'Admin',
  CircleRole.member => 'Member',
};
