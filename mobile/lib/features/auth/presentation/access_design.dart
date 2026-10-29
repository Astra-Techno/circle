import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/circle_brand.dart';
import '../../../core/circle_failure.dart';
import '../domain/access_validation.dart';
import '../application/country_provider.dart';

/// Welcome with the owner's complete supplied CIRCLE identity.
/// Create account and Log in are the two clear choices.
class AccessWelcome extends StatelessWidget {
  const AccessWelcome({super.key, this.connectedTo});

  /// The connected server's host.
  final String? connectedTo;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    return _AccessPage(
      children: [
        // ── Logo badge + brand name + tagline ──
        const _WelcomeBrand(),
        const SizedBox(height: Space.lg),

        // ── Photo collage hero ──
        const _PhotoCollage(),
        const SizedBox(height: Space.section),

        // ── Headline ──
        Text(
          'Your People.\nYour Moments.\nYour Circle.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: Space.md),
        Text(
          'A private place to stay close, share memories, and '
          'celebrate life together without algorithms, ads, or '
          'public noise.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: muted),
        ),
        const SizedBox(height: Space.section),

        // ── Promises ──
        const _Promises(),
        const SizedBox(height: Space.section),

        // ── Get Started (→ register) ──
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          child: FilledButton(
            onPressed: () => context.go('/register'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text('Get Started', textAlign: TextAlign.center),
                ),
                SizedBox(width: Space.sm),
                Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),

        // ── Log in ──
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          child: FilledButton.tonal(
            onPressed: () => context.go('/login'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login),
                SizedBox(width: Space.sm),
                Flexible(child: Text('Log in', textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        _PreviewNote(connectedTo: connectedTo, welcome: true),
        const SizedBox(height: Space.md),
        Text(
          'Share thoughtfully with the people in your chosen group.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

/// Infinity logo in a tinted circle, bold "CIRCLE", and tagline.
class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        const SizedBox(height: Space.md),
        // Logo image inside a soft circular badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceContainerHigh,
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Image.asset(
              CircleIdentity.artwork,
              fit: BoxFit.contain,
              semanticLabel: CircleIdentity.semantics,
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'CIRCLE',
          style: theme.textTheme.headlineSmall?.copyWith(
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          CircleIdentity.tagline,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// A warm photo-collage section emulating the design mock-up.
/// Uses placeholder illustrations since we don't bundle stock photos.
class _PhotoCollage extends StatelessWidget {
  const _PhotoCollage();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accents = CircleAccents.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.lg),
      decoration: CircleDepth.panel(
        context,
        radius: CircleRadius.card,
        tint: accents.recessed,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main "photo" placeholder
              Expanded(
                flex: 7,
                child: Transform.rotate(
                  angle: -0.035,
                  child: Container(
                    padding: const EdgeInsets.all(Space.xs),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(CircleRadius.small),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.06),
                          blurRadius: Space.sm,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              CircleRadius.xsmall,
                            ),
                            color: accents.calmContainer,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            "assets/welcome/sunday-supper.jpg",
                            width: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel:
                                "Illustrative family supper from the supplied design",
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.xs,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Sunday Supper',
                                  style: theme.textTheme.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.favorite,
                                size: 14,
                                color: accents.heart,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              // Right column: small photo + group badge
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Transform.rotate(
                      angle: 0.05,
                      child: Container(
                        padding: const EdgeInsets.all(Space.xs),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(
                            CircleRadius.small,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.06),
                              blurRadius: Space.sm,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              CircleRadius.xsmall,
                            ),
                            color: accents.sageContainer,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            "assets/welcome/friends.jpg",
                            width: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel:
                                "Illustrative friends at sunset from the supplied design",
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    // Group badge
                    Container(
                      padding: const EdgeInsets.all(Space.sm),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(CircleRadius.small),
                      ),
                      child: Row(
                        children: [
                          CircleInitialAvatar(
                            icon: Icons.lock,
                            size: CircleAvatarSize.small,
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Living Room',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Invite only',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
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
          // Quality badge + member avatars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm,
                    vertical: Space.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(CircleRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.04),
                        blurRadius: Space.xs,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          'Heirloom Quality',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              // Stacked member avatars
              SizedBox(
                width: 54,
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _MiniAvatar(label: 'M', color: accents.calm),
                    Positioned(
                      left: 14,
                      child: _MiniAvatar(
                        label: 'K',
                        color: colors.primary,
                        textColor: colors.onPrimary,
                      ),
                    ),
                    Positioned(
                      left: 28,
                      child: _MiniAvatar(
                        label: '+8',
                        color: colors.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.label, required this.color, this.textColor});
  final String label;
  final Color color;
  final Color? textColor;
  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: Theme.of(context).colorScheme.surface,
        width: 2,
      ),
    ),
    child: Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class _Promises extends StatelessWidget {
  const _Promises();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: CircleAccents.of(context).recessed,
        borderRadius: BorderRadius.circular(CircleRadius.card),
      ),
      child: Column(
        children: [
          row(Icons.shield_outlined, 'Shared only with your chosen group'),
          row(
            Icons.do_not_disturb_on_outlined,
            'No follower counts, vanity metrics, or ads',
          ),
          row(
            Icons.family_restroom_outlined,
            'Safe, legible, and simple for ages 15 to 75',
          ),
        ],
      ),
    );
  }
}

class AccessForm extends ConsumerStatefulWidget {
  const AccessForm({
    super.key,
    required this.registering,
    required this.onSubmit,
    this.next,
    this.connectedTo,
    this.notice,
  });
  final bool registering;

  /// Sends the details to the server and returns a calm error, or null
  /// once signed in.
  final Future<String?> Function(AccessDetails details) onSubmit;

  /// The connected server's host, shown once.
  final String? connectedTo;

  /// A calm message to show once, e.g. "Your session ended…".
  final String? notice;

  /// A safe in-app destination to resume, kept when switching forms.
  final String? next;
  @override
  ConsumerState<AccessForm> createState() => _AccessFormState();
}

class _AccessFormState extends ConsumerState<AccessForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  late DialCode _dialCode;
  bool _obscured = true;
  bool _busy = false;
  bool _locating = false;
  int _countryRevision = 0;
  String? _countryNotice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dialCode = AccessValidation.defaultDialCode;
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Combines dial code + phone number into E.164 format.
  String get _fullMobile => '${_dialCode.code}${_mobile.text.trim()}';

  Future<void> _detectCountry() async {
    final revision = _countryRevision;
    setState(() {
      _locating = true;
      _countryNotice = null;
    });
    try {
      final region = await ref.read(countryLocatorProvider).detectCountry();
      if (!mounted || revision != _countryRevision) return;
      final detected = AccessValidation.dialCodeForRegion(region);
      setState(() {
        if (detected != null) _dialCode = detected;
        _countryNotice = detected == null
            ? 'Choose your country manually.'
            : '${detected.name} selected. You can change it below.';
      });
    } on CircleFailure catch (error) {
      if (mounted && revision == _countryRevision) {
        setState(() => _countryNotice = error.message);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _submit() {
    if (_busy || !_form.currentState!.validate()) return;
    _send(widget.onSubmit);
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
        mobile: AccessValidation.normalizeMobile(_fullMobile),
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
      const SizedBox(height: Space.lg),
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
      if (widget.notice != null) ...[
        const SizedBox(height: Space.md),
        CircleNote(widget.notice!),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code dropdown
                  SizedBox(
                    width: 108,
                    child: DropdownButtonFormField<DialCode>(
                      key: ValueKey(_dialCode.region),
                      initialValue: _dialCode,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Space.md,
                          vertical: Space.lg,
                        ),
                      ),
                      isExpanded: true,
                      items: dialCodes
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(
                                '${d.flag} ${d.code}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _dialCode = v;
                            _countryRevision++;
                            _countryNotice = null;
                          });
                        }
                      },
                      selectedItemBuilder: (context) => dialCodes
                          .map(
                            (d) => Text(
                              '${d.flag} ${d.code}',
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  // Phone number field
                  Expanded(
                    child: TextFormField(
                      controller: _mobile,
                      key: const ValueKey('access-mobile'),
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: 'Phone number',
                        errorMaxLines: 3,
                        prefixIcon: Icon(Icons.phone_iphone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: AccessValidation.phoneNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              TextButton.icon(
                onPressed: _locating || _busy ? null : _detectCountry,
                icon: const Icon(Icons.my_location_outlined),
                label: Text(
                  _locating
                      ? 'Finding your country…'
                      : 'Use my location for country code',
                ),
              ),
              Text(
                'Optional: your phone’s location service finds the country. CIRCLE does not store your location.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_countryNotice != null)
                Semantics(liveRegion: true, child: Text(_countryNotice!)),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _password,
                key: const ValueKey('access-password'),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: widget.registering
                      ? '6\u2013128 characters.'
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
                onPressed: _busy || _locating ? null : _submit,
                child: Text(
                  _busy
                      ? (widget.registering
                            ? 'Creating your account\u2026'
                            : 'Logging in\u2026')
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
  Widget build(BuildContext context) => const CircleBrand.access();
}

class _PreviewNote extends StatelessWidget {
  const _PreviewNote({this.connectedTo, this.welcome = false});

  /// The connected server's host, named once.
  final String? connectedTo;
  final bool welcome;
  @override
  Widget build(BuildContext context) => Text(
    welcome
        ? 'Your circles stay private to the people you choose.'
        : 'Your details are sent to ${connectedTo ?? 'CIRCLE'} only.',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
