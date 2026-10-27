import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/circle_failure.dart';

enum InviteShareTarget { whatsapp, smsContact, smsManual, other }

/// User-selected contact only. No address-book permission, upload or persistence.
class InviteShareBridge {
  const InviteShareBridge();
  static const _channel = MethodChannel('circle/invite_share');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<String?> pickPhone() async {
    try {
      return await _channel.invokeMethod<String>('pickPhone');
    } catch (_) {
      throw const CircleFailure(
        'The contact picker couldn’t open. Choose “Enter number in SMS app” instead.',
      );
    }
  }

  Future<bool> compose(
    InviteShareTarget target,
    String message, {
    String? phone,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('compose', {
            'target': switch (target) {
              InviteShareTarget.whatsapp => 'whatsapp',
              InviteShareTarget.smsContact ||
              InviteShareTarget.smsManual => 'sms',
              InviteShareTarget.other => 'other',
            },
            'text': message,
            'phone': ?phone,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
