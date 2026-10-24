import 'package:flutter/material.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../memories/presentation/memory_photos.dart';
import '../application/chat_providers.dart';
import 'chat_visuals.dart';

/// G3 for a photo message: the shared full-screen viewer (swipe or
/// buttons, "n of N"). Access is the conversation's: someone who can't
/// read the chat (or the message) sees a calm notice instead.
class ChatPhotoViewer extends StatelessWidget {
  const ChatPhotoViewer({
    super.key,
    required this.conversationId,
    required this.messageId,
    this.initialIndex = 0,
  });
  final String conversationId, messageId;
  final int initialIndex;
  @override
  Widget build(BuildContext context) => ChatAsyncView<ConversationLoad>(
    provider: chatConversationProvider(conversationId),
    builder: (load) {
      final message = load.view?.messages
          .where((message) => message.id == messageId)
          .firstOrNull;
      if (message == null || message.photos.isEmpty) {
        return const ReadingPane(
          child: Padding(
            padding: CircleInsets.form,
            child: CircleEmpty(
              title: 'Photos unavailable',
              message:
                  'This message was unsent, or the chat isn’t shared with you.',
            ),
          ),
        );
      }
      return PhotoPager(photos: message.photos, initialIndex: initialIndex);
    },
  );
}
