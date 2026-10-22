import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/session.dart';
import '../../../core/design.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ReadingPane(
        child: ListView(
          padding: const EdgeInsets.all(Space.section),
          children: [
            const SizedBox(height: Space.hero),
            Text('CIRCLE', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.large),
            const ArchiveArt(label: 'A little closer to the old days'),
            const SizedBox(height: Space.hero),
            Text(
              'Same people.\nNew memories.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: Space.lg),
            const Text(
              'A quiet place for your college circle. Revisit the stories, find familiar faces, and make room for what comes next.',
            ),
            const SizedBox(height: Space.hero),
            FilledButton(
              onPressed: () => context.go('/invite'),
              child: const Text('Enter with an invitation'),
            ),
            const SizedBox(height: Space.lg),
            const Text(
              'FICTIONAL DEMO · No real accounts or private photos.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class InvitationScreen extends ConsumerStatefulWidget {
  const InvitationScreen({super.key});
  @override
  ConsumerState<InvitationScreen> createState() => _InvitationState();
}

class _InvitationState extends ConsumerState<InvitationScreen> {
  final _code = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!ref.read(sessionProvider.notifier).enter(_code.text)) {
      setState(
        () => _error = 'Use CIRCLE-DEMO to enter this fictional community.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your invitation'),
      leading: BackButton(onPressed: () => context.go('/')),
    ),
    body: ReadingPane(
      child: ListView(
        padding: const EdgeInsets.all(Space.section),
        children: [
          const ArchiveArt(
            label: 'There’s a place for you here',
            icon: Icons.mark_email_read_outlined,
          ),
          const SizedBox(height: Space.section),
          Text(
            'Welcome back to your people.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Space.lg),
          const Text(
            'MOCK invitation validation. Enter CIRCLE-DEMO to explore Marigold College, Class of 2006. This does not create an account or verify membership.',
          ),
          const SizedBox(height: Space.section),
          TextField(
            controller: _code,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Demo invitation code',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.section),
          FilledButton(onPressed: _submit, child: const Text('Open my circle')),
        ],
      ),
    ),
  );
}
