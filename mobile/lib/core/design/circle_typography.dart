import 'package:flutter/material.dart';

/// Dual-font social hierarchy: Plus Jakarta Sans (warm, rounded terminals) for
/// display/heading roles; Roboto for body/metadata readability. Both are bundled.
abstract final class CircleTextStyles {
  static const fontFamily = 'Roboto';
  static const displayFamily = 'PlusJakartaSans';

  static TextStyle _style(
    Color ink,
    double size,
    double line, {
    bool emphasis = false,
    bool display = false,
  }) => TextStyle(
    fontFamily: display ? displayFamily : fontFamily,
    fontSize: size,
    fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
    height: line / size,
    letterSpacing: display ? -0.2 : 0,
    color: ink,
  );

  // Display roles — Plus Jakarta Sans (warm, rounded)
  static TextStyle brand(Color ink) =>
      _style(ink, 26, 32, emphasis: true, display: true);
  static TextStyle pageTitle(Color ink) =>
      _style(ink, 24, 30, emphasis: true, display: true);
  static TextStyle sectionTitle(Color ink) =>
      _style(ink, 20, 26, emphasis: true, display: true);
  static TextStyle cardTitle(Color ink) =>
      _style(ink, 16, 22, emphasis: true, display: true);

  // Body roles — Roboto (clean, readable)
  static TextStyle body(Color ink) => _style(ink, 16, 24);
  static TextStyle bodyMedium(Color ink) => _style(ink, 16, 24, emphasis: true);
  static TextStyle label(Color ink) => _style(ink, 14, 20, emphasis: true);
  static TextStyle metadata(Color ink) => _style(ink, 13, 18);
  static TextStyle caption(Color ink) => _style(ink, 12, 16);
  static TextStyle button(Color ink) =>
      _style(ink, 15, 20, emphasis: true, display: true);
  static TextStyle navLabel(Color ink) => _style(ink, 11, 14, emphasis: true);
  static TextStyle input(Color ink) => body(ink);

  // Compatibility roles keep all existing screens on the same hierarchy.
  static TextStyle homeBody(Color ink) => body(ink);
  static TextStyle homeAuthor(Color ink) => cardTitle(ink);
}
