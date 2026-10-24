import '../../../core/rule_result.dart';

/// Fictional illustrated "photos" for the preview. Real uploads come later;
/// nothing here is a real person, place photo or remote image.
enum MemoryScene {
  sundayLunch('Sunday lunch'),
  hillTrip('Hill trip'),
  graduationDay('Graduation day'),
  birthdayCake('Birthday cake'),
  beachWalk('Beach walk'),
  officeParty('Office party'),
  cricketMatch('Cricket match'),
  weddingStage('Wedding stage'),
  templeFestival('Temple festival'),
  oldClassroom('Old classroom');

  const MemoryScene(this.label);
  final String label;
}

/// One photo on a Memory: a fictional illustrated [scene] in the preview,
/// or a private uploaded photo ([mediaId], ADR 0007) on a CIRCLE server.
class MemoryPhoto {
  const MemoryPhoto({
    required this.id,
    this.scene,
    this.mediaId,
    this.width,
    this.height,
    this.caption,
  }) : assert(scene != null || mediaId != null);
  final String id;
  final MemoryScene? scene;

  /// The server's media id; bytes come only through short-lived signed
  /// links requested for this id.
  final String? mediaId;

  /// Pixel size of an uploaded photo, when known.
  final int? width, height;
  final String? caption;

  bool get uploaded => mediaId != null;

  /// The same photo with a new caption (null removes it).
  MemoryPhoto withCaption(String? caption) => MemoryPhoto(
    id: id,
    scene: scene,
    mediaId: mediaId,
    width: width,
    height: height,
    caption: caption,
  );

  /// A short name for the photo: the scene's label, or "Photo".
  String get label => scene?.label ?? 'Photo';

  /// What a screen reader hears: "fictional illustration, Sunday lunch.
  /// Room for one more", or "photo" for an uploaded one.
  String get description {
    final words = scene == null
        ? 'photo'
        : 'fictional illustration, ${scene!.label}';
    return caption == null ? words : '$words. $caption';
  }
}

/// Photo captions (Memories and albums): optional, up to 140 characters.
abstract final class PhotoCaptionRules {
  static const maxLength = 140;

  static RuleResult check(String? caption) =>
      (caption?.trim().runes.length ?? 0) > maxLength
      ? const RuleResult.denied('Keep captions to 140 characters.')
      : const RuleResult.allowed();

  /// Blank captions are stored as null.
  static String? clean(String? caption) {
    final value = caption?.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
