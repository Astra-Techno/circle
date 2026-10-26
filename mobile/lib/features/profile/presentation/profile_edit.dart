import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/circle_components.dart';
import '../../../core/design.dart';
import '../../workspace/application/workspace_providers.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final key in [
      'display_name',
      'about',
      'current_city',
      'hometown',
      'work',
      'education',
    ])
      key: TextEditingController(),
  };
  bool _loading = true, _saving = false;
  String? _error, _accountId;
  String _mobile = '';
  ApiClient? _profileApi;

  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(_load));
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final id = ref.read(serverAccountProvider)?.id;
    final api = ref.read(apiClientProvider);
    if (id == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please log in to edit your profile.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref
        .read(serverSessionProvider.notifier)
        .refreshProfile();
    if (!mounted ||
        ref.read(serverAccountProvider)?.id != id ||
        !identical(ref.read(apiClientProvider), api)) {
      return;
    }
    final account = ref.read(serverAccountProvider)!;
    setState(() {
      _loading = false;
      _error = error;
      if (error == null) {
        _accountId = id;
        _profileApi = api;
        _mobile = account.mobile;
        final values = {
          'display_name': account.displayName,
          'about': account.about,
          'current_city': account.currentCity,
          'hometown': account.hometown,
          'work': account.work,
          'education': account.education,
        };
        for (final entry in values.entries) {
          _fields[entry.key]!.text = entry.value;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final id = _accountId;
    if (id == null ||
        ref.read(serverAccountProvider)?.id != id ||
        !identical(ref.read(apiClientProvider), _profileApi)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref.read(serverSessionProvider.notifier).updateProfile({
      for (final field in _fields.entries) field.key: field.value.text.trim(),
    });
    if (!mounted ||
        ref.read(serverAccountProvider)?.id != id ||
        !identical(ref.read(apiClientProvider), _profileApi)) {
      return;
    }
    if (error == null) {
      showCircleMessage(context, 'Profile updated.');
      context.pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  Widget _field(String key, String label, {int max = 100, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Space.lg),
        child: TextFormField(
          key: ValueKey('profile-${key.replaceAll('_', '-')}'),
          controller: _fields[key],
          enabled: !_saving,
          maxLength: max,
          minLines: lines,
          maxLines: lines,
          textCapitalization: key == 'about'
              ? TextCapitalization.sentences
              : TextCapitalization.words,
          textInputAction: lines == 1
              ? TextInputAction.next
              : TextInputAction.newline,
          autofillHints: key == 'display_name'
              ? const [AutofillHints.name]
              : null,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (key == 'display_name' && text.isEmpty) {
              return 'Enter the name people know you by.';
            }
            if (text.runes.length > max) return 'Use $max characters or fewer.';
            return null;
          },
        ),
      );
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ReadingPane(
        child: CircleSkeleton(count: 3, label: 'Loading your profile'),
      );
    }
    if (_accountId == null) {
      return ReadingPane(
        child: CircleEmpty(
          title: 'Your profile couldn’t load',
          message: _error ?? 'Please try again.',
          action: FilledButton(
            onPressed: _load,
            child: const Text('Try again'),
          ),
        ),
      );
    }
    return ReadingPane(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: CircleInsets.form,
              children: [
                const CircleHeading(
                  title: 'Edit profile',
                  subtitle: 'Make this little space feel like you.',
                ),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleSectionTitle('Profile'),
                      const Text(
                        'Your name and bio are visible to members of your groups.',
                      ),
                      const SizedBox(height: Space.lg),
                      _field('display_name', 'Display name'),
                      _field('about', 'Bio (optional)', max: 500, lines: 3),
                      const CircleSectionTitle('Personal details'),
                      const Text(
                        'Only you can see these optional details. Leave a field empty to remove it.',
                      ),
                      const SizedBox(height: Space.lg),
                      _field('current_city', 'Current city (optional)'),
                      _field('hometown', 'Hometown (optional)'),
                      _field('work', 'Work (optional)'),
                      _field(
                        'education',
                        'Education (optional)',
                        max: 150,
                        lines: 2,
                      ),
                      if (_mobile.isNotEmpty)
                        TextFormField(
                          initialValue: _mobile,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number (read-only)',
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: Space.lg),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
