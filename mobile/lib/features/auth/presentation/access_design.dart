import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design.dart';
import '../domain/access_validation.dart';

class AccessWelcome extends StatelessWidget {
  const AccessWelcome({super.key});
  @override
  Widget build(BuildContext context) => _AccessPage(
    children: [
      const _Brand(),
      const SizedBox(height: Space.hero),
      const _CircleArtwork(),
      const SizedBox(height: Space.hero),
      Text(
        'Your people.\nYour own little world.',
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: Space.lg),
      Text(
        'A private place for family, friends and the circles that make life yours.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: Space.section),
      const Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          _QuietChip(Icons.photo_library_outlined, 'Shared Memories'),
          _QuietChip(Icons.forum_outlined, 'Familiar conversations'),
        ],
      ),
      const SizedBox(height: Space.hero),
      FilledButton(
        onPressed: () => context.go('/register'),
        child: const Text('Create account'),
      ),
      const SizedBox(height: Space.sm),
      TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Already here? Log in'),
      ),
      const SizedBox(height: Space.lg),
      const _PreviewNote(),
    ],
  );
}

class AccessForm extends StatefulWidget {
  const AccessForm({super.key, required this.registering});
  final bool registering;
  @override
  State<AccessForm> createState() => _AccessFormState();
}

class _AccessFormState extends State<AccessForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _obscured = true;
  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    // This prototype must never retain, log, transmit or authenticate input.
    _name.clear();
    _mobile.clear();
    _password.clear();
    FocusScope.of(context).unfocus();
    context.go('/complete');
  }

  @override
  Widget build(BuildContext context) => _AccessPage(
    back: true,
    children: [
      const _Brand(),
      const SizedBox(height: Space.hero),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            widget.registering
                ? Icons.person_add_alt_1_outlined
                : Icons.waving_hand_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 28,
          ),
        ),
      ),
      const SizedBox(height: Space.section),
      Text(
        widget.registering
            ? 'Make room for\nyour people.'
            : 'Good to have\nyou back.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: Space.md),
      Text(
        widget.registering
            ? 'Anyone can join CIRCLE. Create a private group or join people you know.'
            : 'Log in with your mobile number and password. Your circles stay private.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: Space.section),
      const _PreviewNote(),
      const SizedBox(height: Space.section),
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.registering) ...[
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                enableSuggestions: false,
              ),
              const SizedBox(height: Space.lg),
            ],
            TextFormField(
              controller: _mobile,
              key: const ValueKey('access-mobile'),
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '+ country code and number',
                errorMaxLines: 3,
                prefixIcon: Icon(Icons.phone_iphone_outlined),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              validator: AccessValidation.mobile,
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _password,
              key: const ValueKey('access-password'),
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: widget.registering
                    ? '15–128 characters. A passphrase works well.'
                    : null,
                helperMaxLines: 3,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscured ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              obscureText: _obscured,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              validator: (value) => AccessValidation.password(
                value,
                registering: widget.registering,
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Space.section),
            FilledButton(
              onPressed: _submit,
              child: Text(
                widget.registering ? 'Preview registration' : 'Preview log in',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.md),
      TextButton(
        onPressed: () =>
            context.go(widget.registering ? '/login' : '/register'),
        child: Text(
          widget.registering
              ? 'Have an account? Log in'
              : 'New here? Create account',
        ),
      ),
      if (!widget.registering)
        const Padding(
          padding: EdgeInsets.only(top: Space.md),
          child: Text(
            'Password recovery will be available with the secure API. OTP is planned for a later release.',
            textAlign: TextAlign.center,
          ),
        ),
    ],
  );
}

class AccessPreviewComplete extends StatelessWidget {
  const AccessPreviewComplete({super.key});
  @override
  Widget build(BuildContext context) => _AccessPage(
    children: [
      const _Brand(),
      const SizedBox(height: Space.hero),
      const _CircleArtwork(),
      const SizedBox(height: Space.section),
      Text(
        'Your circle\nstarts with you.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: Space.lg),
      const Text(
        'Preview complete. Your inputs have been cleared. No account was created and no login request was sent.',
      ),
      const SizedBox(height: Space.section),
      const _NextStep(
        Icons.add_circle_outline,
        'Create your own group',
        'Bring together family, friends or your team.',
      ),
      const _NextStep(
        Icons.link_outlined,
        'Join through a link',
        'Join directly or ask for approval, as the group requires.',
      ),
      const _NextStep(
        Icons.mark_email_read_outlined,
        'Accept a direct invitation',
        'Choose which circles you want to be part of.',
      ),
      const SizedBox(height: Space.section),
      const Text(
        'These group actions follow real registration in a later implementation. Registration alone never reveals private group content.',
      ),
      const SizedBox(height: Space.section),
      FilledButton(
        onPressed: () => context.go('/'),
        child: const Text('Back to the design preview'),
      ),
    ],
  );
}

class _AccessPage extends StatelessWidget {
  const _AccessPage({required this.children, this.back = false});
  final List<Widget> children;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: back
        ? AppBar(
            leading: BackButton(onPressed: () => context.go('/')),
            title: const Text('Account'),
          )
        : null,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(Space.section),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.section,
    runSpacing: Space.md,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.blur_circular,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: Space.sm),
          Text(
            'CIRCLE',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(letterSpacing: 3),
          ),
        ],
      ),
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 18),
          SizedBox(width: Space.xs),
          Text('Private by choice'),
        ],
      ),
    ],
  );
}

class _PreviewNote extends StatelessWidget {
  const _PreviewNote();
  @override
  Widget build(BuildContext context) => Text(
    'DESIGN PREVIEW · Use fictional details only. Nothing is sent or stored.',
    style: Theme.of(context).textTheme.bodySmall,
  );
}

class _QuietChip extends StatelessWidget {
  const _QuietChip(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));
}

class _NextStep extends StatelessWidget {
  const _NextStep(this.icon, this.title, this.description);
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Space.xs),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CircleArtwork extends StatelessWidget {
  const _CircleArtwork();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Original illustration: family, friends and work circles connected privately',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(Space.section),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryContainer, colors.tertiaryContainer],
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      child: _Orbit(
                        icon: Icons.favorite_outline,
                        colors: colors,
                      ),
                    ),
                    _Orbit(
                      icon: Icons.people_outline,
                      colors: colors,
                      featured: true,
                    ),
                    Positioned(
                      right: 0,
                      child: _Orbit(icon: Icons.work_outline, colors: colors),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(
                'Different circles. Same sense of belonging.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Orbit extends StatelessWidget {
  const _Orbit({
    required this.icon,
    required this.colors,
    this.featured = false,
  });
  final IconData icon;
  final ColorScheme colors;
  final bool featured;
  @override
  Widget build(BuildContext context) => Container(
    width: featured ? 112 : 88,
    height: featured ? 112 : 88,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: featured ? colors.primary : colors.surface,
      border: Border.all(color: colors.outlineVariant, width: 2),
    ),
    child: Icon(
      icon,
      size: featured ? 48 : 32,
      color: featured ? colors.onPrimary : colors.primary,
    ),
  );
}
