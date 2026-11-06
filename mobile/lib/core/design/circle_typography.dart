import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Native Apple typography on iOS/macOS; correctly named Inter faces elsewhere.
/// All screens resolve through these roles. No runtime font downloads.
abstract final class CircleTextStyles {
  static String get fontFamily => kIsWeb
      ? 'Inter'
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS || TargetPlatform.macOS => 'CupertinoSystemText',
          _ => 'Inter',
        };
  static String get displayFamily => fontFamily;

  static TextStyle _style(
    Color ink,
    double size,
    double line, {
    bool emphasis = false,
    bool display = false,
    FontWeight? weight,
  }) => TextStyle(
    fontFamily: display ? displayFamily : fontFamily,
    fontSize: size,
    fontWeight: weight ?? (emphasis ? FontWeight.w600 : FontWeight.w400),
    height: line / size,
    letterSpacing: 0,
    color: ink,
  );

  // Compact headings share the same family as reading text.
  static TextStyle brand(Color ink) =>
      _style(ink, 24, 30, emphasis: true, display: true);
  static TextStyle pageTitle(Color ink) =>
      _style(ink, 21, 28, emphasis: true, display: true);
  static TextStyle sectionTitle(Color ink) =>
      _style(ink, 18, 24, emphasis: true, display: true);
  static TextStyle cardTitle(Color ink) =>
      _style(ink, 15, 20, emphasis: true, display: true);

  // Reading and control roles.
  static TextStyle body(Color ink) => _style(ink, 16, 24);
  static TextStyle bodyMedium(Color ink) => _style(ink, 16, 24, emphasis: true);
  static TextStyle label(Color ink) =>
      _style(ink, 13, 18, weight: FontWeight.w500);
  static TextStyle metadata(Color ink) => _style(ink, 12, 16);
  static TextStyle caption(Color ink) => _style(ink, 12, 16);
  static TextStyle button(Color ink) =>
      _style(ink, 15, 20, weight: FontWeight.w500);
  static TextStyle navLabel(Color ink) =>
      _style(ink, 11, 14, weight: FontWeight.w500);
  static TextStyle input(Color ink) => body(ink);

  // Compatibility roles keep all existing screens on the same hierarchy.
  static TextStyle postBody(Color ink) => _style(ink, 15, 22);
  static TextStyle homeBody(Color ink) => body(ink);
  static TextStyle homeAuthor(Color ink) => cardTitle(ink);
}
