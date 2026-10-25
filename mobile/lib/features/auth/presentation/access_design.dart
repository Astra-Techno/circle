import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../../core/circle_brand.dart';
import '../domain/access_validation.dart';

/// Welcome with the owner's complete supplied CIRCLE identity.
/// Create account and Log in are the two clear choices; the
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
        const CircleBrand(),
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
  late DialCode _dialCode;
  bool _obscured = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    _dialCode = AccessValidation.dialCodeForLocale(locale);
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code dropdown
                  SizedBox(
                    width: 108,
                    child: DropdownButtonFormField<DialCode>(
                      initialValue: _dialCode,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      isExpanded: true,
                      items: dialCodes
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(
                                  '${d.flag} ${d.code}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _dialCode = v);
                      },
                      selectedItemBuilder: (context) => dialCodes
                          .map((d) => Text(
                                '${d.flag} ${d.code}',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ))
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
              TextFormField(
                controller: _password,
                key: const ValueKey('access-password'),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: widget.registering
                      ? '6–128 characters.'
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
  Widget build(BuildContext context) => const CircleBrand(compact: true);
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
