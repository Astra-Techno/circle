import 'package:flutter_lucide/flutter_lucide.dart';

/// Semantic icon mapping from the CIRCLE design blueprint §6.
///
/// Centralizes icon choices so feature screens never import
/// `flutter_lucide` directly for standard actions.
abstract final class CircleIcons {
  // Navigation
  static const home = LucideIcons.house;
  static const circles = LucideIcons.users_round;
  static const create = LucideIcons.plus;
  static const events = LucideIcons.calendar_days;
  static const profile = LucideIcons.user_round;

  // Header actions
  static const search = LucideIcons.search;
  static const notifications = LucideIcons.bell;
  static const chat = LucideIcons.message_circle;
  static const more = LucideIcons.ellipsis;

  // Quick actions
  static const photo = LucideIcons.image;
  static const video = LucideIcons.video;
  static const event = LucideIcons.calendar_days;
  static const poll = LucideIcons.list_todo;

  // Post actions
  static const like = LucideIcons.heart;
  static const comment = LucideIcons.message_circle;
  static const share = LucideIcons.share_2;
  static const bookmark = LucideIcons.bookmark;

  // Navigation chrome
  static const back = LucideIcons.arrow_left;
  static const close = LucideIcons.x;
  static const chevronRight = LucideIcons.chevron_right;

  // Metadata
  static const members = LucideIcons.users;
  static const location = LucideIcons.map_pin;
  static const time = LucideIcons.clock_3;

  // Celebrations
  static const birthday = LucideIcons.cake;
  static const invite = LucideIcons.user_plus;

  // Actions
  static const send = LucideIcons.send;
  static const check = LucideIcons.check;
}

/// Tokenized icon sizes from the blueprint.
abstract final class CircleSizes {
  static const iconSmall = 17.0;
  static const iconDefault = 22.0;
  static const iconQuickAction = 24.0;
  static const iconCreate = 28.0;
  static const iconAction = 21.0;
  static const minTouchTarget = 44.0;
  static const avatarPost = 40.0;
  static const logoHeader = 40.0;
  static const dockCreate = 56.0;
}
