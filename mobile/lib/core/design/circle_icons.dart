import 'package:flutter/material.dart' show Icons;
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

  /// Home quick-action tile glyphs.
  static const eventAdd = LucideIcons.calendar_plus;
  static const pollBars = LucideIcons.chart_bar;

  // Post actions
  /// Opens the reaction picker; love (a heart) is the default reaction.
  static const react = LucideIcons.heart;
  static const saved = LucideIcons.bookmark_check;

  /// A filled heart for love you've already given (Lucide has no filled
  /// variant).
  static const loved = Icons.favorite;

  /// Comments use a square bubble so they don't read as Chats.
  static const comment = LucideIcons.message_square;
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

  // Other interface icons (one place for every Lucide glyph the app uses).
  static const alarmClock = LucideIcons.alarm_clock;
  static const archive = LucideIcons.archive;
  static const arrowRight = LucideIcons.arrow_right;
  static const atSign = LucideIcons.at_sign;
  static const ban = LucideIcons.ban;
  static const bike = LucideIcons.bike;
  static const bookOpen = LucideIcons.book_open;
  static const briefcase = LucideIcons.briefcase;
  static const building = LucideIcons.building;
  static const calendar = LucideIcons.calendar;
  static const calendarCheck = LucideIcons.calendar_check;
  static const calendarCog = LucideIcons.calendar_cog;
  static const calendarX = LucideIcons.calendar_x;
  static const camera = LucideIcons.camera;
  static const chartBar = LucideIcons.chart_bar;
  static const checkCheck = LucideIcons.check_check;
  static const chevronDown = LucideIcons.chevron_down;
  static const chevronLeft = LucideIcons.chevron_left;
  static const chevronUp = LucideIcons.chevron_up;
  static const circle = LucideIcons.circle;
  static const circleAlert = LucideIcons.circle_alert;
  static const circleCheckBig = LucideIcons.circle_check_big;
  static const clock = LucideIcons.clock;
  static const coffee = LucideIcons.coffee;
  static const contact = LucideIcons.contact;
  static const copy = LucideIcons.copy;
  static const crown = LucideIcons.crown;
  static const ellipsisVertical = LucideIcons.ellipsis_vertical;
  static const eye = LucideIcons.eye;
  static const eyeOff = LucideIcons.eye_off;
  static const faceSlightlySmiling = LucideIcons.face_slightly_smiling;
  static const flag = LucideIcons.flag;
  static const flower2 = LucideIcons.flower_2;
  static const graduationCap = LucideIcons.graduation_cap;
  static const handshake = LucideIcons.handshake;
  static const hourglass = LucideIcons.hourglass;
  static const imageOff = LucideIcons.image_off;
  static const imagePlus = LucideIcons.image_plus;
  static const images = LucideIcons.images;
  static const inbox = LucideIcons.inbox;
  static const info = LucideIcons.info;
  static const landmark = LucideIcons.landmark;
  static const layers = LucideIcons.layers;
  static const link = LucideIcons.link;
  static const locate = LucideIcons.locate;
  static const lock = LucideIcons.lock;
  static const lockKeyhole = LucideIcons.lock_keyhole;
  static const lockOpen = LucideIcons.lock_open;
  static const logIn = LucideIcons.log_in;
  static const logOut = LucideIcons.log_out;
  static const luggage = LucideIcons.luggage;
  static const mail = LucideIcons.mail;
  static const messagesSquare = LucideIcons.messages_square;
  static const monitorSmartphone = LucideIcons.monitor_smartphone;
  static const mountain = LucideIcons.mountain;
  static const partyPopper = LucideIcons.party_popper;
  static const pencil = LucideIcons.pencil;
  static const pin = LucideIcons.pin;
  static const refreshCw = LucideIcons.refresh_cw;
  static const reply = LucideIcons.reply;
  static const settings = LucideIcons.settings;
  static const shield = LucideIcons.shield;
  static const shieldOff = LucideIcons.shield_off;
  static const slidersHorizontal = LucideIcons.sliders_horizontal;
  static const smartphone = LucideIcons.smartphone;
  static const sparkles = LucideIcons.sparkles;
  static const star = LucideIcons.star;
  static const timer = LucideIcons.timer;
  static const trash = LucideIcons.trash;
  static const trophy = LucideIcons.trophy;
  static const type = LucideIcons.type;
  static const umbrella = LucideIcons.umbrella;
  static const undo = LucideIcons.undo;
  static const user = LucideIcons.user;
  static const userCheck = LucideIcons.user_check;
  static const userMinus = LucideIcons.user_minus;
  static const userX = LucideIcons.user_x;
  static const utensils = LucideIcons.utensils;
  static const volumeOff = LucideIcons.volume_off;
  static const vote = LucideIcons.vote;
  static const wifiOff = LucideIcons.wifi_off;
}

/// Tokenized icon sizes from the blueprint.
abstract final class CircleSizes {
  /// Tiny icon beside caption/metadata text (12–14dp range).
  static const iconInline = 14.0;

  /// Photo-viewer action icons (React, Comment, Share).
  static const iconPhoto = 20.0;

  static const iconSmall = 17.0;
  static const iconDefault = 20.0;
  static const iconQuickAction = 24.0;
  static const iconCreate = 28.0;
  static const iconAction = 20.0;
  static const minTouchTarget = 48.0;
  static const avatarPost = 40.0;
  static const logoHeader = 40.0;
  static const dockCreate = 56.0;
}
