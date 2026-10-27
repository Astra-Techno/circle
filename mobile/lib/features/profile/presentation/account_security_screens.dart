import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../application/account_security.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});
  @override
  ConsumerState<SessionsScreen> createState() => _SessionsState();
}

class _SessionsState extends ConsumerState<SessionsScreen> {
  final _items = <AccountSession>[];
  int _total = 0, _generation = 0;
  bool _busy = false;
  String? _error, _notice;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(device: true));
  }

  Future<void> _load({bool more = false, bool device = false}) async {
    final service = ref.read(accountSecurityProvider);
    if (_busy || service == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (device) {
        try {
          await service.updateDevice().timeout(const Duration(seconds: 2));
        } catch (_) {
          /* Optional metadata must not block security controls. */
        }
      }
      final page = await service.sessions(offset: more ? _items.length : 0);
      if (!mounted || generation != _generation || !service.active) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.items);
        _total = page.total;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Your devices couldn’t load. Please try again.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _action(Future<void> Function(AccountSecurity) action) async {
    final service = ref.read(accountSecurityProvider);
    if (_busy || service == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action(service);
      if (mounted && service.active) setState(() => _notice = 'Updated.');
    } catch (error) {
      if (mounted && service.active) {
        showCircleMessage(context, error.toString());
      }
    } finally {
      if (mounted && service.active) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Unknown';
    final d = value.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountSecurityProvider, (_, next) {
      _generation++;
      _items.clear();
      _total = 0;
      _busy = false;
      _error = null;
      Future.microtask(_load);
    });
    return ReadingPane(
      child: ListView(
        padding: CircleInsets.page,
        children: [
          const CircleHeading(
            title: 'Your devices',
            subtitle: 'Where you’re signed in.',
          ),
          const SizedBox(height: Space.lg),
          const Text('Location sharing is optional. No background tracking.'),
          if (_busy) const LinearProgressIndicator(),
          if (_notice != null) Text(_notice!),
          if (_error != null) Text(_error!),
          TextButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh devices'),
          ),
          if (!_busy && _error == null && _items.isEmpty)
            const CircleEmpty(
              title: 'No active sessions',
              message: 'Sign in again to review your devices.',
            ),
          for (final session in _items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.device,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (session.current) const Text('This device'),
                    if (session.os.isNotEmpty) Text(session.os),
                    if (session.app.isNotEmpty) Text('CIRCLE ${session.app}'),
                    Text('Signed in: ${_date(session.created)}'),
                    Text('Last active: ${_date(session.seen)}'),
                    Text(
                      'Network: ${session.ip.isEmpty ? 'Unavailable' : session.ip}',
                    ),
                    Text(
                      'Shared approximate location: ${session.location ?? 'Not shared'}',
                    ),
                    if (session.locationUpdated != null)
                      Text(
                        'Location updated: ${_date(session.locationUpdated)}',
                      ),
                    if (session.current)
                      Wrap(
                        spacing: Space.sm,
                        children: [
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    final confirmed = await confirmCircleAction(
                                      context,
                                      title: 'Share approximate location?',
                                      message:
                                          'Use this device’s location once to save a city or region for this session. CIRCLE stores no coordinates. You can remove the label at any time.',
                                      confirm: 'Continue',
                                    );
                                    if (confirmed && mounted) {
                                      await _action((s) => s.shareLocation());
                                    }
                                  },
                            icon: const Icon(Icons.location_on_outlined),
                            label: Text(
                              session.location == null
                                  ? 'Add location'
                                  : 'Update location',
                            ),
                          ),
                          if (session.location != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action((s) => s.clearLocation()),
                              child: const Text('Remove location'),
                            ),
                        ],
                      ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final confirmed = await confirmCircleAction(
                                context,
                                title: session.current
                                    ? 'Log out this device?'
                                    : 'Log out this session?',
                                message: session.current
                                    ? 'You’ll need to sign in again on this device.'
                                    : 'This session will need to sign in again.',
                                confirm: 'Log out',
                              );
                              if (confirmed && mounted) {
                                await _action((s) => s.revoke(session));
                              }
                            },
                      icon: const Icon(Icons.logout),
                      label: Text(
                        session.current
                            ? 'Log out this device'
                            : 'Log out session',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const ExpansionTile(
            title: Text('About device details'),
            children: [
              Padding(
                padding: EdgeInsets.all(Space.lg),
                child: Text(
                  'Device and location labels are reported by the app. Network addresses may be shared or changed by a VPN. Times use your device’s time zone.',
                ),
              ),
            ],
          ),
          if (_items.length < _total)
            TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Load more devices'),
            ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _PasswordState();
}

class _PasswordState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _next = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false, _ambiguous = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final service = ref.read(accountSecurityProvider);
    if (service == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await service.password(_current.text, _next.text);
    } catch (error) {
      if (!mounted || !service.active) return;
      final uncertain =
          error is! ApiError ||
          error.isNetwork ||
          (error.status ?? 0) >= 500 ||
          error.code == ApiError.badResponse;
      setState(() {
        _ambiguous = uncertain;
        _error = uncertain
            ? 'The result couldn’t be confirmed. Don’t send the change again. Sign in with your new password first; if it wasn’t changed, use the previous password.'
            : error.code == 'invalid_current_password'
            ? 'Current password is incorrect.'
            : error.toString();
      });
    } finally {
      if (mounted) {
        _current.clear();
        _next.clear();
        _confirm.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ReadingPane(
    child: ListView(
      padding: CircleInsets.page,
      children: [
        const CircleHeading(
          title: 'Change password',
          subtitle: 'Use 15–128 characters. A memorable phrase works well.',
        ),
        const SizedBox(height: Space.lg),
        const Text(
          'Changing your password logs out every device, including this one. You’ll sign in again with your new password.',
        ),
        const SizedBox(height: Space.lg),
        Form(
          key: _form,
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Column(
              children: [
                TextFormField(
                  controller: _current,
                  enabled: !_busy && !_ambiguous,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Enter your current password.' : null,
                ),
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _next,
                  enabled: !_busy && !_ambiguous,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (v) =>
                      (v ?? '').runes.length < 15 ||
                          (v ?? '').runes.length > 128
                      ? 'Use 15–128 characters.'
                      : v == _current.text
                      ? 'Choose a different new password.'
                      : null,
                ),
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _confirm,
                  enabled: !_busy && !_ambiguous,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  validator: (v) =>
                      v != _next.text ? 'Passwords don’t match.' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(_error!),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_ambiguous)
          OutlinedButton(
            onPressed: _busy ? null : () => _actionLogout(ref),
            child: const Text('Log out and sign in'),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Change password and log out'),
          ),
      ],
    ),
  );
  Future<void> _actionLogout(WidgetRef ref) async {
    final service = ref.read(accountSecurityProvider);
    if (service != null) {
      await service.finish('Sign in to check your password change.');
    }
  }
}
