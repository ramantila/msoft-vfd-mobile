import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/staff.dart';
import '../services/staff_service.dart';
import 'staff_widgets.dart';

/// Add / edit staff, following the web portal's user-create and user-edit pages:
/// live preview, Personal Information (name, phone, branch with occupancy),
/// Account Information (username; password + confirm + strength + generate on
/// create), and a Roles checklist. There is no role picker — access comes from
/// the company's custom roles. Editing yourself locks roles and branch.
/// On edit, a Reset Password card appears when [canResetPassword].
class StaffFormScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final StaffUser? edit;
  final bool isMe;
  final bool canResetPassword;

  const StaffFormScreen({
    super.key,
    required this.themeMode,
    this.edit,
    this.isMe = false,
    this.canResetPassword = false,
  });

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  static final _localPhone = RegExp(r'^0[0-9]{9}$');

  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _resetPassword = TextEditingController();
  final _resetConfirm = TextEditingController();

  StaffFormOptions? _options;
  ApiException? _loadError;
  String? _branchId;
  Set<String> _roleIds = {};
  bool _saving = false;
  bool _resetting = false;
  bool _usernameTouched = false;
  bool _showPassword = false;
  bool _showReset = false;
  Map<String, String> _fieldErrors = const {};

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _editing => widget.edit != null;
  bool get _locked => widget.isMe;
  String get _originalPhone => widget.edit?.phone ?? '';

  @override
  void initState() {
    super.initState();
    final u = widget.edit;
    if (u != null) {
      _first.text = u.firstName;
      _middle.text = u.middleName ?? '';
      _last.text = u.lastName;
      _phone.text = u.phone;
      _username.text = u.username;
      _branchId = u.branchId;
      _roleIds = u.roleIds.toSet();
      _usernameTouched = true;
    }
    for (final c in [_first, _middle, _last, _phone, _username, _password, _confirm, _resetPassword, _resetConfirm]) {
      c.addListener(_refresh);
    }
    _load();
  }

  void _refresh() {
    if (!_usernameTouched && !_editing) {
      String part(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final suggestion = [part(_first.text), part(_last.text)].where((s) => s.isNotEmpty).join('.');
      if (_username.text != suggestion) _username.text = suggestion;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _phone, _username, _password, _confirm, _resetPassword, _resetConfirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final o = await StaffService.instance.formOptions();
      if (!mounted) return;
      setState(() {
        _options = o;
        if (!_editing && o.branches.length == 1 && !o.branches.first.full) _branchId = o.branches.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  // ---- derived state (the portal's plain methods) ----

  BranchOption? get _branch => _options?.branches.where((b) => b.id == _branchId).firstOrNull;

  /// Capacity only matters when moving someone onto a branch (portal: unchanged branch is fine).
  bool get _branchAtCapacity {
    final b = _branch;
    if (b == null || b.capacity == null) return false;
    if (_editing && _branchId == widget.edit!.branchId) return false;
    return b.staffCount >= b.capacity!;
  }

  bool get _phoneInvalid {
    final p = _phone.text.trim();
    if (p.isEmpty) return false;
    if (_editing && p == _originalPhone) return false;
    return !_localPhone.hasMatch(p);
  }

  bool get _passwordsMismatch => _confirm.text.isNotEmpty && _password.text != _confirm.text;
  bool get _quotaReached => !_editing && (_options?.quota?.reached ?? false);

  List<String> get _selectedRoleNames =>
      (_options?.customRoles ?? const []).where((r) => _roleIds.contains(r.id)).map((r) => r.name).toList();

  // ---- actions ----

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _fieldErrors = const {});
    if (!(_formKey.currentState?.validate() ?? false)) return;
    String? problem;
    if (_branchId == null) problem = 'Please select a branch';
    if (_branchAtCapacity) problem = '${_branch!.name} has reached its capacity of ${_branch!.capacity} employees.';
    if (_quotaReached) problem = 'Your plan\'s user limit is reached.';
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final input = StaffInput(
      firstName: _first.text.trim(),
      middleName: _middle.text.trim().isEmpty ? null : _middle.text.trim(),
      lastName: _last.text.trim(),
      phone: _phone.text.trim(),
      username: _username.text.trim(),
      roleIds: _roleIds.toList(),
      branchId: _branchId,
      password: _editing ? null : _password.text,
    );
    setState(() => _saving = true);
    try {
      final saved = _editing
          ? await StaffService.instance.update(widget.edit!.id, input)
          : await StaffService.instance.create(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_editing ? 'User updated successfully!' : 'User created successfully! Share the password with ${saved.user.firstName}.')));
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors = e.fieldErrors ?? const {};
      });
      if (!e.isValidation) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _doReset() async {
    final p = _resetPassword.text;
    String? problem;
    if (p.isEmpty) problem = 'Please enter a new password';
    if (p.isNotEmpty && p.length < 8) problem = 'Use at least 8 characters';
    if (_resetConfirm.text != p) problem = 'Passwords do not match';
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _resetting = true);
    try {
      await StaffService.instance.resetPassword(widget.edit!.id, p);
      if (!mounted) return;
      _resetPassword.clear();
      _resetConfirm.clear();
      setState(() {
        _resetting = false;
        _showReset = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password reset successfully! ${widget.edit!.firstName} must sign in again.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(title: _editing ? (_locked ? 'Edit my details' : 'Edit User') : 'Add User', isNeu: isNeu),
          if (_saving) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(child: _body(isNeu)),
        ]),
      ),
    );
  }

  Widget _body(bool isNeu) {
    final o = _options;
    if (o == null) {
      if (_loadError != null) {
        return Center(
          child: SalesMessage(
            icon: _loadError!.isForbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
            title: _loadError!.isForbidden ? 'You can\'t manage users' : 'Couldn\'t load the form',
            subtitle: _loadError!.message,
            isNeu: isNeu,
            onRetry: _loadError!.isForbidden ? null : _load,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    final ts = SalesUi.textSec(isNeu);
    final q = o.quota;
    final blocked = _saving || _quotaReached || _branchAtCapacity || _phoneInvalid || (!_editing && _passwordsMismatch);

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(px, 6, px, bot + 24),
        children: [
          if (!_editing && q != null) ...[
            Container(
              decoration: SalesUi.card(isNeu),
              padding: const EdgeInsets.all(14),
              child: QuotaBar(
                  used: q.currentUsers, max: q.maxUsers, noun: 'users', packageName: q.packageName, isNeu: isNeu),
            ),
            const SizedBox(height: 14),
          ],
          _preview(isNeu),
          const SizedBox(height: 14),
          _section(isNeu, 'Personal Information', 'Who this account belongs to', [
            _field(_first, 'First Name *', 'firstName', required: true),
            const SizedBox(height: 12),
            _field(_middle, 'Middle Name', 'middleName'),
            const SizedBox(height: 12),
            _field(_last, 'Last Name *', 'lastName', required: true),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: _inputStyle(isNeu),
              decoration: staffInput(isNeu, 'Phone *',
                      error: _phoneInvalid ? 'Must be 10 digits and start with 0, e.g. 0712345678' : _fieldErrors['phone'],
                      helper: 'Used to sign in — 10 digits starting with 0')
                  .copyWith(counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter a phone number' : null,
            ),
            const SizedBox(height: 14),
            Text('Branch *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ts)),
            const SizedBox(height: 8),
            if (o.branches.isEmpty)
              Text('No branches yet. Add one under Branches first.', style: TextStyle(fontSize: 12, color: ts))
            else
              Wrap(children: [
                for (final b in o.branches)
                  SalesChip(
                    label: b.name,
                    active: _branchId == b.id,
                    isNeu: isNeu,
                    onTap: _locked ? () {} : () => setState(() => _branchId = b.id),
                  ),
              ]),
            if (_branch?.capacity != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _branchAtCapacity
                      ? 'This branch is at capacity (${_branch!.staffCount} / ${_branch!.capacity} employees).'
                      : '${_branch!.staffCount} / ${_branch!.capacity} employees assigned to this branch.',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _branchAtCapacity ? AppColors.error : ts),
                ),
              ),
            if (_locked)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('You can\'t change your own branch or roles. Ask another administrator.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.warningText, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 14),
          _section(isNeu, 'Account Information', 'Login credentials for this user', [
            _field(_username, 'Username *', 'username',
                onChanged: (_) => _usernameTouched = true,
                validator: (v) => (v ?? '').trim().length < 3 ? 'At least 3 characters' : null),
            if (!_editing) ...[
              const SizedBox(height: 12),
              _passwordField(isNeu, _password, 'Password *', 'password',
                  validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null),
              const SizedBox(height: 12),
              _passwordField(isNeu, _confirm, 'Confirm Password *', 'confirmPassword',
                  error: _passwordsMismatch ? 'Passwords do not match' : null,
                  validator: (v) => (v ?? '').isEmpty ? 'Please confirm the password' : null),
              PasswordStrengthBar(
                password: _password.text,
                onGenerate: () => setState(() {
                  final p = generatePassword();
                  _password.text = p;
                  _confirm.text = p;
                  _showPassword = true;
                }),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          _roles(isNeu, o),
          if (_editing && widget.canResetPassword && !_locked) ...[
            const SizedBox(height: 14),
            _resetCard(isNeu),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: blocked ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
            ),
            child: Text(_saving ? 'Saving…' : (_editing ? 'Save changes' : 'Create'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// The portal's live preview card: initials, name, roles or @username, branch, phone.
  Widget _preview(bool isNeu) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final name = [_first.text, _middle.text, _last.text].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
    final roles = _selectedRoleNames;
    return Container(
      decoration: SalesUi.card(isNeu),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        StaffAvatar(name: name.isEmpty ? '?' : name, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? (_editing ? '—' : 'New team member') : name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 2),
            Text(
              roles.isNotEmpty
                  ? roles.join(', ')
                  : (_username.text.isNotEmpty ? '@${_username.text}' : 'New account'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 4),
            Text(
              [_branch?.name ?? '—', if (_phone.text.isNotEmpty) _phone.text].join('  ·  '),
              style: TextStyle(fontSize: 12, color: ts),
            ),
          ]),
        ),
      ]),
    );
  }

  /// The portal's RoleChecklist: Select All, name + description, empty hint.
  Widget _roles(bool isNeu, StaffFormOptions o) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final all = o.customRoles.isNotEmpty && o.customRoles.every((r) => _roleIds.contains(r.id));
    return _section(
      isNeu,
      'Roles',
      'What this user can do',
      [
        if (o.customRoles.isEmpty)
          Text('Your company hasn\'t configured any roles yet. Create one from Access Control to assign it here.',
              style: TextStyle(fontSize: 12.5, color: ts, height: 1.4))
        else ...[
          if (!_locked)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => setState(() =>
                    _roleIds = all ? <String>{} : o.customRoles.map((r) => r.id).toSet()),
                child: Text(all ? 'Clear all' : 'Select All', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          for (final r in o.customRoles)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              value: _roleIds.contains(r.id),
              onChanged: _locked
                  ? null
                  : (v) => setState(() => v == true ? _roleIds.add(r.id) : _roleIds.remove(r.id)),
              title: Text(r.name, style: TextStyle(fontWeight: FontWeight.w700, color: tp)),
              subtitle: r.description == null ? null : Text(r.description!, maxLines: 2),
            ),
          // Roles the user still has but that are no longer active stay assigned on save.
          if (_roleIds.any((id) => !o.customRoles.any((r) => r.id == id)))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_roleIds.where((id) => !o.customRoles.any((r) => r.id == id)).length} inactive role(s) stay assigned.',
                style: TextStyle(fontSize: 11.5, color: ts),
              ),
            ),
        ],
      ],
    );
  }

  Widget _resetCard(bool isNeu) {
    return _section(isNeu, 'Reset Password', 'Set a new password for ${widget.edit!.firstName}', [
      Text('They\'ll be signed out everywhere and must sign in with the new password. Tell them in person.',
          style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu), height: 1.4)),
      const SizedBox(height: 12),
      _passwordField(isNeu, _resetPassword, 'New Password', 'newPassword', reset: true),
      const SizedBox(height: 12),
      _passwordField(isNeu, _resetConfirm, 'Confirm New Password', 'confirmNewPassword',
          reset: true,
          error: _resetConfirm.text.isNotEmpty && _resetConfirm.text != _resetPassword.text
              ? 'Passwords do not match'
              : null),
      PasswordStrengthBar(
        password: _resetPassword.text,
        onGenerate: () => setState(() {
          final p = generatePassword();
          _resetPassword.text = p;
          _resetConfirm.text = p;
          _showReset = true;
        }),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _resetting ? null : _doReset,
          icon: const Icon(Icons.lock_reset_rounded, size: 18),
          label: Text(_resetting ? 'Resetting…' : 'Reset password'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }

  TextStyle _inputStyle(bool isNeu) =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SalesUi.text(isNeu));

  Widget _section(bool isNeu, String title, String subtitle, List<Widget> children) => Container(
        decoration: SalesUi.card(isNeu),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
          Text(subtitle, style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu))),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _field(TextEditingController c, String label, String field,
      {bool required = false, String? Function(String?)? validator, ValueChanged<String>? onChanged}) {
    return TextFormField(
      controller: c,
      enabled: !_saving,
      onChanged: onChanged,
      textCapitalization: field == 'username' ? TextCapitalization.none : TextCapitalization.words,
      style: _inputStyle(_isNeu),
      decoration: staffInput(_isNeu, label, error: _fieldErrors[field]),
      validator: validator ?? (required ? (v) => (v ?? '').trim().isEmpty ? 'Required' : null : null),
    );
  }

  Widget _passwordField(bool isNeu, TextEditingController c, String label, String field,
      {String? error, String? Function(String?)? validator, bool reset = false}) {
    final shown = reset ? _showReset : _showPassword;
    return TextFormField(
      controller: c,
      enabled: !(reset ? _resetting : _saving),
      obscureText: !shown,
      style: _inputStyle(isNeu),
      validator: reset ? null : validator,
      decoration: staffInput(isNeu, label,
          error: error ?? _fieldErrors[field],
          suffix: IconButton(
            icon: Icon(shown ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            onPressed: () => setState(() => reset ? _showReset = !_showReset : _showPassword = !_showPassword),
          )),
    );
  }
}
