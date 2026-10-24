import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../domain/access_validation.dart';

/// Welcome: the owner's Stitch layout ("Your People. Your Moments. Your
/// Circle."). Create account and Log in are the two clear choices; the
/// fictional tour is a quiet third option for the prototype.
class AccessWelcome extends StatelessWidget {
  const AccessWelcome({super.key, this.onExploreDemo, this.connectedTo});
  final VoidCallback? onExploreDemo;

  /// The server's host in server builds; null in the preview.
  final String? connectedTo;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return _AccessPage(
      children: [
        const Center(
          child: CircleInitialAvatar(
            icon: Icons.all_inclusive,
            size: CircleAvatarSize.hero,
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          'CIRCLE',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 4),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'PRIVATE GROUPS. SHARED MEMORIES.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: muted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: Space.section),
        // The collage is a decorative illustration (described for screen
        // readers), so its tiny captions keep their drawn size.
        MediaQuery.withNoTextScaling(child: const _WelcomeCollage()),
        const SizedBox(height: Space.section),
        // Display text is already large; capping its growth keeps words
        // whole on narrow phones while body text still scales fully.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Text(
            'Your people. Your moments. Your circle.',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          'A private place to stay close, share memories and celebrate life together, without algorithms, ads or public noise.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: muted),
        ),
        const SizedBox(height: Space.section),
        const _Promises(),
        const SizedBox(height: Space.section),
        FilledButton(
          onPressed: () => context.go('/register'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text('Create account', textAlign: TextAlign.center),
              ),
              SizedBox(width: Space.sm),
              Icon(Icons.arrow_forward),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        OutlinedButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login),
          label: const Text('Log in'),
        ),
        if (onExploreDemo != null) ...[
          const SizedBox(height: Space.sm),
          TextButton.icon(
            onPressed: onExploreDemo,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explore fictional circles'),
          ),
        ],
        const SizedBox(height: Space.md),
        _PreviewNote(connectedTo: connectedTo, welcome: true),
      ],
    );
  }
}

/// A fictional keepsake collage: two illustrated "photos", an invite-only
/// room and a calm promise. No real people or remote images.
class _WelcomeCollage extends StatelessWidget {
  const _WelcomeCollage();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Semantics(
      image: true,
      label:
          'Illustration: a family supper and a hillside outing, shared in an invite-only circle',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: accents.calmContainer,
            borderRadius: BorderRadius.circular(CircleRadius.sheet),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Transform.rotate(
                      angle: -0.03,
                      child: const _Polaroid(
                        icon: Icons.dinner_dining_outlined,
                        caption: 'Sunday supper',
                        height: 120,
                        loved: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Transform.rotate(
                          angle: 0.04,
                          child: const _Polaroid(
                            icon: Icons.landscape_outlined,
                            height: 64,
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Container(
                          padding: const EdgeInsets.all(Space.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(
                              CircleRadius.tile,
                            ),
                          ),
                          child: Row(
                            children: [
                              const CircleInitialAvatar(
                                icon: Icons.lock_outline,
                                tone: CircleTone.strong,
                                size: CircleAvatarSize.small,
                              ),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Living room',
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium,
                                    ),
                                    Text(
                                      'Invite only',
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CirclePill(
                        'Calm and private',
                        icon: Icons.verified_user_outlined,
                        tone: CircleTone.surface,
                      ),
                    ),
                  ),
                  for (final (index, label) in ['M', 'K', '+8'].indexed)
                    Align(
                      widthFactor: 0.75,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accents.calmContainer,
                            width: 2,
                          ),
                        ),
                        child: CircleInitialAvatar(
                          name: label == '+8' ? null : label,
                          icon: label == '+8' ? Icons.more_horiz : null,
                          tone: index == 1
                              ? CircleTone.strong
                              : index == 0
                              ? CircleTone.heart
                              : CircleTone.neutral,
                          size: CircleAvatarSize.small,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An illustrated "photo" with a white keepsake border.
class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.icon,
    required this.height,
    this.caption,
    this.loved = false,
  });
  final IconData icon;
  final double height;
  final String? caption;
  final bool loved;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = CircleAccents.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(CircleRadius.small),
        border: Border.all(color: accents.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: accents.recessed,
              borderRadius: BorderRadius.circular(CircleRadius.small),
            ),
            child: Icon(
              icon,
              size: height / 2.4,
              color: theme.colorScheme.secondary,
            ),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      caption!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (loved)
                    Icon(Icons.favorite_border, size: 16, color: accents.heart),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The three promises from the design, in plain words.
class _Promises extends StatelessWidget {
  const _Promises();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          CircleInitialAvatar(icon: icon, tone: CircleTone.surface),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: CircleAccents.of(context).calmContainer,
        borderRadius: BorderRadius.circular(CircleRadius.card),
      ),
      child: Column(
        children: [
          row(Icons.shield_outlined, 'Private to the groups you choose'),
          row(
            Icons.do_not_disturb_on_outlined,
            'No follower counts, vanity metrics or ads',
          ),
          row(
            Icons.family_restroom_outlined,
            'Clear and simple for every age, 15 to 75',
          ),
        ],
      ),
    );
  }
}

class AccessForm extends StatefulWidget {
  const AccessForm({
    super.key,
    required this.registering,
    required this.onPreviewComplete,
    this.next,
    this.onSubmit,
    this.connectedTo,
    this.notice,
  });
  final bool registering;

  /// Called after valid input has been cleared. Nothing is sent or stored.
  final VoidCallback onPreviewComplete;

  /// Server builds: sends the details for real and returns a calm error,
  /// or null once signed in. Null in the preview.
  final Future<String?> Function(AccessDetails details)? onSubmit;

  /// The server's host, shown once instead of the preview note.
  final String? connectedTo;

  /// A calm message to show once, e.g. "Your session ended…".
  final String? notice;

  /// A safe in-app destination to resume, kept when switching forms.
  final String? next;
  @override
  State<AccessForm> createState() => _AccessFormState();
}

class _AccessFormState extends State<AccessForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _obscured = true;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.onSubmit != null) {
      _send(widget.onSubmit!);
      return;
    }
    // This prototype must never retain, log, transmit or authenticate input.
    _name.clear();
    _mobile.clear();
    _password.clear();
    FocusScope.of(context).unfocus();
    // Nothing was verified, so password managers are told not to save.
    TextInput.finishAutofillContext(shouldSave: false);
    widget.onPreviewComplete();
  }

  /// Server builds: register or log in for real. The password is sent
  /// exactly as typed and cleared from the form once signed in.
  Future<void> _send(Future<String?> Function(AccessDetails) submit) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await submit(
      AccessDetails(
        registering: widget.registering,
        mobile: AccessValidation.normalizeMobile(_mobile.text),
        password: _password.text,
        name: widget.registering ? _name.text.trim() : null,
      ),
    );
    if (!mounted) return;
    if (error == null) {
      TextInput.finishAutofillContext();
      _password.clear();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  String _switchLocation() => Uri(
    path: widget.registering ? '/login' : '/register',
    queryParameters: {if (widget.next != null) 'next': widget.next!},
  ).toString();

  @override
  Widget build(BuildContext context) => _AccessPage(
    back: true,
    children: [
      const _Brand(),
      const SizedBox(height: Space.hero),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: CircleInitialAvatar(
          icon: widget.registering
              ? Icons.person_add_alt_1_outlined
              : Icons.waving_hand_outlined,
          size: CircleAvatarSize.large,
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
      _PreviewNote(connectedTo: widget.connectedTo),
      if (widget.notice != null && widget.onSubmit != null) ...[
        const SizedBox(height: Space.md),
        PreviewLabel(widget.notice!),
      ],
      const SizedBox(height: Space.section),
      AutofillGroup(
        child: Form(
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
                  autofillHints: const [AutofillHints.name],
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
                autofillHints: const [AutofillHints.telephoneNumber],
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
                autofillHints: [
                  widget.registering
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                validator: (value) => AccessValidation.password(
                  value,
                  registering: widget.registering,
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.lg),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Space.section),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  widget.onSubmit == null
                      ? (widget.registering
                            ? 'Preview registration'
                            : 'Preview log in')
                      : _busy
                      ? (widget.registering
                            ? 'Creating your account…'
                            : 'Logging in…')
                      : (widget.registering ? 'Create account' : 'Log in'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: Space.md),
      TextButton(
        onPressed: () => context.go(_switchLocation()),
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
  const _PreviewNote({this.connectedTo, this.welcome = false});

  /// Server builds name the server once instead of the preview note.
  final String? connectedTo;
  final bool welcome;
  @override
  Widget build(BuildContext context) => Text(
    connectedTo == null
        ? 'Design preview · use fictional details only. Nothing is sent or stored.'
        : welcome
        ? 'Connected to $connectedTo. Explore fictional circles is a separate tour that stays on this device.'
        : 'Connected to $connectedTo. Your details are sent to this server only.',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
