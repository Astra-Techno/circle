import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design.dart';
import '../domain/post.dart';
import 'feed_controller.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key, this.postId});
  final String? postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(feedProvider)
      .when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading your circle',
          ),
        ),
        error: (_, _) => Notice(
          title: 'Your circle couldn’t load',
          message: 'Try loading the local demo again.',
          action: FilledButton(
            onPressed: () => ref.invalidate(feedProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (posts) {
          final selected = posts.where((post) => post.id == postId).firstOrNull;
          if (postId != null && selected == null) {
            return const Notice(
              title: 'Memory unavailable',
              message: 'This post is no longer in your circle.',
            );
          }
          return ReadingPane(
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                if (postId == null) ...[
                  Text(
                    'THE CLASS OF 2006',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Good to be together.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: Space.sm),
                  const Text('Marigold College · Fictional private community'),
                  const SizedBox(height: Space.section),
                  FilledButton.icon(
                    onPressed: () => context.push('/create'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Share a memory'),
                  ),
                  const SizedBox(height: Space.section),
                  if (posts.isEmpty)
                    const Notice(
                      title: 'The first story starts with you',
                      message: 'Share a memory to bring this circle to life.',
                    ),
                  for (final post in posts) PostCard(post: post),
                ] else ...[
                  PostCard(post: selected!, detail: true),
                  Text(
                    'Around this memory',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Space.lg),
                  if (selected.comments.isEmpty)
                    const Text('Be the first to add a thought.'),
                  for (final comment in selected.comments)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Text(comment),
                      ),
                    ),
                  TextComposer(
                    key: ValueKey(postId),
                    label: 'Add a comment',
                    button: 'Send comment',
                    onSubmit: (text) =>
                        ref.read(feedProvider.notifier).comment(postId!, text),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.detail = false});
  final Post post;
  final bool detail;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(post.author.substring(0, 1))),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      post.date,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: post.saved ? 'Unsave memory' : 'Save memory',
                onPressed: () => ref.read(feedProvider.notifier).save(post.id),
                icon: Icon(post.saved ? Icons.bookmark : Icons.bookmark_border),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(post.body),
          if (post.archive)
            const Padding(
              padding: EdgeInsets.only(top: Space.lg),
              child: ArchiveArt(label: 'Monsoon in the courtyard · 2006'),
            ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            children: [
              TextButton.icon(
                onPressed: () => ref.read(feedProvider.notifier).react(post.id),
                icon: Icon(post.liked ? Icons.favorite : Icons.favorite_border),
                label: Text(post.liked ? 'Loved' : 'Love'),
              ),
              if (!detail)
                TextButton.icon(
                  onPressed: () => context.push('/post/${post.id}'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('${post.comments.length} comments'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class TextComposer extends StatefulWidget {
  const TextComposer({
    super.key,
    required this.label,
    required this.button,
    required this.onSubmit,
  });
  final String label, button;
  final void Function(String) onSubmit;
  @override
  State<TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        TextFormField(
          controller: _text,
          minLines: 2,
          maxLines: 8,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: widget.label,
            alignLabelWithHint: true,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Write something before sharing.'
              : null,
        ),
        const SizedBox(height: Space.md),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            widget.onSubmit(_text.text.trim());
            _text.clear();
            FocusScope.of(context).unfocus();
          },
          child: Text(widget.button),
        ),
      ],
    ),
  );
}

class CreatePostScreen extends ConsumerWidget {
  const CreatePostScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ReadingPane(
    child: ListView(
      padding: const EdgeInsets.all(Space.section),
      children: [
        const Text(
          'Shared with Marigold College · Class of 2006. Text stays in this demo session.',
        ),
        const SizedBox(height: Space.section),
        TextComposer(
          label: 'What takes you back?',
          button: 'Share with my circle',
          onSubmit: (text) {
            ref.read(feedProvider.notifier).create(text);
            context.go('/feed');
          },
        ),
      ],
    ),
  );
}
