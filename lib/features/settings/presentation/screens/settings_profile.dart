part of 'settings_screen.dart';

class SettingsProfile {
  const SettingsProfile({
    required this.userId,
    required this.displayName,
    required this.roleLabel,
    required this.isEditable,
    this.email,
  });

  final String userId;
  final String displayName;
  final String? email;
  final String roleLabel;
  final bool isEditable;

  String get initial => displayName.trim().isEmpty
      ? '?'
      : displayName.trim().characters.first.toUpperCase();

  String get subtitle {
    final normalizedEmail = email?.trim();
    if (normalizedEmail == null || normalizedEmail.isEmpty) return roleLabel;
    return '$normalizedEmail · $roleLabel';
  }
}

final settingsProfileProvider = StreamProvider<SettingsProfile>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final household = ref.watch(activeHouseholdContextProvider);
  final roleLabel = _titleCase(household?.role.name ?? 'account');
  if (auth == null) {
    return Stream.value(
      SettingsProfile(
        userId: '',
        displayName: 'Account',
        roleLabel: roleLabel,
        isEditable: false,
      ),
    );
  }

  final db = ref.watch(firestoreProvider);
  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream.value(
        SettingsProfile(
          userId: '',
          displayName: 'Signed out',
          roleLabel: roleLabel,
          isEditable: false,
        ),
      );
    }
    return db.collection('users').doc(user.uid).snapshots().map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      final storedName = (data['displayName'] as String?)?.trim();
      final authName = user.displayName?.trim();
      final email = (data['email'] as String?)?.trim() ?? user.email?.trim();
      final emailName = email?.split('@').first.trim();
      final displayName = switch ((storedName, authName, emailName)) {
        (final value?, _, _) when value.isNotEmpty => value,
        (_, final value?, _) when value.isNotEmpty => value,
        (_, _, final value?) when value.isNotEmpty => value,
        _ => 'Account',
      };
      return SettingsProfile(
        userId: user.uid,
        displayName: displayName,
        email: email,
        roleLabel: roleLabel,
        isEditable: true,
      );
    });
  });
});

final settingsProfileControllerProvider = Provider<SettingsProfileController>((
  ref,
) {
  return SettingsProfileController(
    auth: ref.watch(firebaseAuthProvider),
    db: ref.watch(firebaseAuthProvider) == null
        ? null
        : ref.watch(firestoreProvider),
  );
});

class SettingsProfileController {
  const SettingsProfileController({required this.auth, required this.db});

  final FirebaseAuth? auth;
  final FirebaseFirestore? db;

  Future<void> updateDisplayName(String rawName) async {
    final name = rawName.trim();
    final validation = validateDisplayName(name);
    if (validation != null) throw StateError(validation);
    final user = auth?.currentUser;
    final db = this.db;
    if (user == null || db == null) {
      throw StateError('Sign in before editing your profile.');
    }
    await user.updateDisplayName(name);
    await db.collection('users').doc(user.uid).set({
      'displayName': name,
      if (user.email != null) 'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String? validateDisplayName(String name) {
    final normalized = name.trim();
    if (normalized.length < 2) return 'Name must have at least 2 characters.';
    if (normalized.length > 80) return 'Name must be 80 characters or fewer.';
    return null;
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile, required this.onTap});

  final SettingsProfile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: KsTokens.space4),
      child: Row(
        children: [
          KsMemberAvatar(initial: profile.initial, seat: 0, size: 48),
          const SizedBox(width: KsTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KsTokens.headlineLarge.copyWith(
                    color: ks.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 19,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: KsTokens.space2),
                Text(
                  profile.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KsTokens.labelSmall.copyWith(
                    color: ks.textTertiary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              onPressed: onTap,
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KsTokens.radius12),
        child: content,
      ),
    );
  }
}

class _ProfileLoadingRow extends StatelessWidget {
  const _ProfileLoadingRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.centerLeft,
        child: CircularProgressIndicator(),
      ),
    );
  }
}

Future<void> _showProfileEditor(
  BuildContext context,
  WidgetRef ref,
  SettingsProfile profile,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProfileEditSheet(profile: profile),
  );
}

class _ProfileEditSheet extends ConsumerStatefulWidget {
  const _ProfileEditSheet({required this.profile});

  final SettingsProfile profile;

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final TextEditingController _nameController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final validation = SettingsProfileController.validateDisplayName(
      _nameController.text,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsProfileControllerProvider)
          .updateDisplayName(_nameController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update profile: $error';
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KsTokens.space16,
          KsTokens.space16,
          KsTokens.space16,
          MediaQuery.viewInsetsOf(context).bottom + KsTokens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Profile',
              style: KsTokens.headlineMedium.copyWith(color: ks.textPrimary),
            ),
            const SizedBox(height: KsTokens.space12),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Display name',
                errorText: _error,
              ),
            ),
            if (widget.profile.email != null) ...[
              const SizedBox(height: KsTokens.space4),
              Text(
                widget.profile.email!,
                style: KsTokens.bodySmall.copyWith(color: ks.textTertiary),
              ),
            ],
            const SizedBox(height: KsTokens.space12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
