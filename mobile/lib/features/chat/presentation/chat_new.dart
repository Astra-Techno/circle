import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/chat_providers.dart';
import 'chat_visuals.dart';

/// D3: people who share a group with the viewer, grouped by group. People
/// who can't be messaged stay visible, disabled, with the reason.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});
  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _opening = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(ChatContact contact) async {
    setState(() => _opening = true);
    final router = GoRouter.of(context);
    final id = await runCalmly(
      context,
      () => ref
          .read(chatControllerProvider.notifier)
          .openDirect(contact.personId),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (id != null) router.pushReplacement('/chats/c/$id');
  }

  @override
  Widget build(BuildContext context) => ChatAsyncView<List<ChatContactGroup>>(
    provider: chatContactsProvider,
    builder: (groups) {
      final query = _query.trim().toLowerCase();
      final sections = [
        for (final section in groups)
          (
            group: section.group,
            contacts: [
              for (final contact in section.contacts)
                if (query.isEmpty || contact.name.toLowerCase().contains(query))
                  contact,
            ],
          ),
      ].where((section) => section.contacts.isNotEmpty).toList();
      return ReadingPane(
        child: ListView(
          padding: CircleInsets.form.copyWith(left: 0, right: 0),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.lg),
              child: CircleHeading(
                title: 'Message someone you know',
                subtitle:
                    'Only people who share a group with you. There is no stranger search.',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.lg),
              child: PreviewLabel(chatPreviewNote),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.sm,
              ),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.lg),
                child: CircleEmpty(
                  title: 'Nobody to message yet',
                  message:
                      'Join or create a group first. You can message people who share a group with you.',
                ),
              )
            else if (sections.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.lg),
                child: Text('No one matches your search.'),
              ),
            for (final section in sections) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: CircleSectionTitle(section.group.name),
              ),
              for (final contact in section.contacts)
                _ContactRow(
                  contact: contact,
                  onTap: _opening || !contact.canMessage
                      ? null
                      : () => _open(contact),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, this.onTap});
  final ChatContact contact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final reason = ChatRules.eligibilityReason(contact.eligibility);
    // A reason why they can't be messaged comes first; otherwise their
    // activity, when they share it with the viewer.
    final subtitle = reason ?? contact.activity;
    return CircleRow(
      child: ListTile(
        enabled: contact.canMessage,
        leading: CircleInitialAvatar(
          name: contact.name,
          tone: contact.canMessage ? CircleTone.calm : CircleTone.neutral,
        ),
        title: Text(contact.name),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: contact.canMessage
            ? const Icon(Icons.chat_bubble_outline)
            : null,
        onTap: onTap,
      ),
    );
  }
}
