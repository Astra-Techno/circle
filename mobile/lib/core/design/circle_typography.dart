import 'package:flutter/material.dart';

/// Semantic text roles from the CIRCLE design blueprint §4.
///
/// All roles use PlusJakartaSans, bundled in the app. Access via
/// `CircleTextStyles.of(context)` for theme-aware colors, or use
/// the raw style getter for composition.
abstract final class CircleTextStyles {
  static const _font = 'PlusJakartaSans';

  /// Brand title in header: 24sp / 700 / -0.5 tracking.
  static TextStyle brand(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 30 / 24,
    letterSpacing: -0.5,
    color: ink,
  );

  /// Root page titles: 22sp / 700 / -0.4.
  static TextStyle pageTitle(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 29 / 22,
    letterSpacing: -0.4,
    color: ink,
  );

  /// Section headings: 18sp / 700 / -0.2.
  static TextStyle sectionTitle(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 25 / 18,
    letterSpacing: -0.2,
    color: ink,
  );

  /// Card titles and author names: 16sp / 700 / -0.2.
  static TextStyle cardTitle(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 23 / 16,
    letterSpacing: -0.2,
    color: ink,
  );

  /// Body text: 15sp / 400 / 0.
  static TextStyle body(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 23 / 15,
    letterSpacing: 0,
    color: ink,
  );

  /// Body with medium emphasis: 15sp / 500 / 0.
  static TextStyle bodyMedium(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 23 / 15,
    letterSpacing: 0,
    color: ink,
  );

  /// Labels, tabs, quick actions, buttons: 13sp / 600 / 0.
  static TextStyle label(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    letterSpacing: 0,
    color: ink,
  );

  /// Metadata, timestamps, counts: 12sp / 400 / 0.
  static TextStyle metadata(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 17 / 12,
    letterSpacing: 0,
    color: ink,
  );

  /// Tiny badges and helper text: 11sp / 500 / 0.
  static TextStyle caption(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 15 / 11,
    letterSpacing: 0,
    color: ink,
  );

  /// Primary/secondary CTA labels: 14sp / 700 / 0.
  static TextStyle button(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 20 / 14,
    letterSpacing: 0,
    color: ink,
  );

  /// Floating dock nav labels: 11sp / 600 / 0.
  static TextStyle navLabel(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 15 / 11,
    letterSpacing: 0,
    color: ink,
  );

  /// Input/composer text: 14sp / 400 / 0.
  static TextStyle input(Color ink) => TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0,
    color: ink,
  );
}
