import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../configurations/screens/config_widgets.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../../users/screens/staff_detail_screen.dart';
import '../../users/screens/staff_widgets.dart';
import '../models/access_models.dart';
import '../services/access_service.dart';

/// Role view: status, Activate/Deactivate, Edit, Delete, its permissions
/// grouped by module, and the users who have it.
class RoleDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String roleId;
  const RoleDetailScreen({super.key, required this.themeMode, required this.roleId});

  @override
  State<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends State<RoleDetailScreen> {
  RoleDetail? _d;
  ApiException? _error;
  bool _busy = false;
  bool _changed = false;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await AccessService.instance.role(widget.roleId);
      if (mounted) setState(() => _d = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggle() async {
    final r = _d!.role;
    setState(() => _busy = true);
    try {
      final d = await AccessService.instance.setActive(r.id, !r.active);
      if (!mounted) return;
      setState(() {
        _d = d;
        _busy = false;
        _changed = true;
      });
      _toast('${r.name} ${d.role.active ? 'activated' : 'deactivated'}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  Future<void> _edit() async {
    final updated =
        await Navigator.of(context).push<RoleDetail>(slideRight(RoleFormScreen(themeMode: widget.themeMode, edit: _d)));
    if (updated != null && mounted) {
      setState(() {
        _d = updated;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final d = _d!;
    if (!await confirmConfigDelete(context, what: 'role', blocker: d.deleteBlocker)) return;
    setState(() => _busy = true);
    try {
      await AccessService.instance.deleteRole(d.role.id);
      if (!mounted) return;
      _toast('Role deleted successfully.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final d = _d;
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final px = SalesUi.gutter(isNeu);
    Widget card(String? title, List<Widget> children) => Container(
          decoration: SalesUi.card(isNeu),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tp)),
              const SizedBox(height: 10),
            ],
            ...children,
          ]),
        );

    Widget body;
    if (d == null) {
      body = _error != null
          ? Center(
              child: SalesMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Failed to load role',
                  subtitle: _error!.message,
                  isNeu: isNeu,
                  onRetry: _load))
          : const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else {
      final r = d.role;
      body = RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(px, 6, px, MediaQuery.of(context).padding.bottom + 24),
          children: [
            card(null, [
              Text(r.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tp)),
              if (r.description != null) ...[
                const SizedBox(height: 2),
                Text(r.description!, style: TextStyle(fontSize: 13, color: ts)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                ActivePill(active: r.active),
                StaffPill(label: '${r.permissionCount} permissions', color: AppColors.purple),
                if (r.createdAt != null)
                  StaffPill(label: 'Created ${SalesFormat.date(r.createdAt!)}', color: AppColors.textMuted),
              ]),
              if (!r.active) ...[
                const SizedBox(height: 8),
                Text('Inactive roles can\'t be newly assigned to users, but stay in effect for anyone who already has them.',
                    style: TextStyle(fontSize: 11.5, color: ts)),
              ],
              if (d.canEdit || AuthState.has('ROLE_DELETE')) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (d.canEdit)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _toggle,
                      icon: Icon(r.active ? Icons.toggle_off_outlined : Icons.toggle_on_outlined, size: 18),
                      label: Text(r.active ? 'Deactivate' : 'Activate'),
                    ),
                  if (d.canEdit)
                    OutlinedButton.icon(
                        onPressed: _busy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit')),
                  if (AuthState.has('ROLE_DELETE'))
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _delete,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                    ),
                ]),
              ],
            ]),
            if (d.notInPackage.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Text(
                  'Your package no longer includes ${d.notInPackage.length} of this role\'s permissions '
                  '(${d.notInPackage.take(3).join(', ')}${d.notInPackage.length > 3 ? '…' : ''}). '
                  'Edit the role to remove them before saving other changes.',
                  style: const TextStyle(fontSize: 12, color: AppColors.warningText, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 14),
            card('Permissions', [
              if (d.permissions.isEmpty) Text('This role has no permissions yet.', style: TextStyle(fontSize: 13, color: ts)),
              for (final g in d.permissions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ts)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final p in g.items)
                        StaffPill(label: p.actionLabel, color: p.inPackage ? AppColors.purple : AppColors.warningText),
                    ]),
                  ]),
                ),
            ]),
            const SizedBox(height: 14),
            card('Assigned to · ${d.users.length}', [
              if (d.users.isEmpty)
                Text('No one has this role. Assign it from System Users.', style: TextStyle(fontSize: 13, color: ts)),
              for (final u in d.users)
                InkWell(
                  onTap: AuthState.has('USER_VIEW')
                      ? () => Navigator.of(context)
                          .push(slideRight(StaffDetailScreen(themeMode: widget.themeMode, userId: u.id)))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      StaffAvatar(name: u.fullName, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.fullName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp)),
                          Text('@${u.username}', style: TextStyle(fontSize: 11.5, color: ts)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
          ],
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: SalesUi.bg(isNeu),
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            SalesHeader(title: d?.role.name ?? 'Role', isNeu: isNeu),
            if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
            Expanded(child: body),
          ]),
        ),
      ),
    );
  }
}

/// New / Edit Role, as on the portal: Role Name, Description, Active, and the
/// grouped permission checklist (Select All, per-module toggle, per-action),
/// limited to the permissions in your company's package.
class RoleFormScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final RoleDetail? edit;
  const RoleFormScreen({super.key, required this.themeMode, this.edit});

  @override
  State<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends State<RoleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.edit?.role.name ?? '');
  late final _description = TextEditingController(text: widget.edit?.role.description ?? '');
  late bool _active = widget.edit?.role.active ?? true;
  late Set<String> _selected = {...?widget.edit?.permissionIds};

  PermissionOptions? _options;
  ApiException? _loadError;
  bool _saving = false;
  final Set<String> _expanded = {};

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final o = await AccessService.instance.permissionOptions();
      if (!mounted) return;
      final allowed = {for (final g in o.groups) for (final p in g.items) p.id};
      setState(() {
        _options = o;
        // Permissions the package no longer includes would make the save fail; drop them.
        _selected = _selected.where(allowed.contains).toSet();
        for (final g in o.groups) {
          if (g.items.any((p) => _selected.contains(p.id))) _expanded.add(g.key);
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  bool get _allSelected {
    final o = _options;
    if (o == null || o.total == 0) return false;
    return o.groups.every((g) => g.items.every((p) => _selected.contains(p.id)));
  }

  bool? _groupState(PermissionGroup g) {
    final n = g.items.where((p) => _selected.contains(p.id)).length;
    if (n == 0) return false;
    if (n == g.items.length) return true;
    return null; // some
  }

  void _toggleGroup(PermissionGroup g) => setState(() {
        if (_groupState(g) == true) {
          _selected.removeAll(g.items.map((p) => p.id));
        } else {
          _selected.addAll(g.items.map((p) => p.id));
        }
      });

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final d = await AccessService.instance.saveRole(
        id: widget.edit?.role.id,
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        permissionIds: _selected,
        active: _active,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.edit == null ? 'Role created successfully.' : 'Role updated successfully.')));
      Navigator.of(context).pop(d);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final px = SalesUi.gutter(isNeu);
    final o = _options;

    Widget checklist;
    if (o == null) {
      checklist = _loadError != null
          ? SalesMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn\'t load permissions',
              subtitle: _loadError!.message,
              isNeu: isNeu,
              onRetry: _load)
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
    } else if (o.total == 0) {
      checklist = Padding(
        padding: const EdgeInsets.all(8),
        child: Text(o.emptyReason ?? 'No permissions available.', style: TextStyle(fontSize: 13, color: ts)),
      );
    } else {
      checklist = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${_selected.length} of ${o.total} selected${o.packageName != null ? ' · ${o.packageName} package' : ''}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts),
            ),
          ),
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() => _allSelected
                    ? _selected.clear()
                    : _selected.addAll({for (final g in o.groups) for (final p in g.items) p.id})),
            child: Text(_allSelected ? 'Clear all' : 'Select All', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        for (final g in o.groups)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderDefault),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              InkWell(
                onTap: () => setState(() => _expanded.contains(g.key) ? _expanded.remove(g.key) : _expanded.add(g.key)),
                child: Row(children: [
                  Checkbox(
                    tristate: true,
                    value: _groupState(g),
                    activeColor: AppColors.primary,
                    onChanged: _saving ? null : (_) => _toggleGroup(g),
                  ),
                  Expanded(
                    child: Text(g.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp)),
                  ),
                  Text('${g.items.where((p) => _selected.contains(p.id)).length}/${g.items.length}',
                      style: TextStyle(fontSize: 12, color: ts)),
                  Icon(_expanded.contains(g.key) ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: ts),
                  const SizedBox(width: 6),
                ]),
              ),
              if (_expanded.contains(g.key))
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in g.items)
                      FilterChip(
                        label: Text(p.actionLabel),
                        selected: _selected.contains(p.id),
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primaryDark,
                        tooltip: p.name,
                        onSelected: _saving
                            ? null
                            : (v) => setState(() => v ? _selected.add(p.id) : _selected.remove(p.id)),
                      ),
                  ]),
                ),
            ]),
          ),
      ]);
    }

    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        child: Column(children: [
          SalesHeader(title: widget.edit == null ? 'New Role' : 'Edit Role', isNeu: isNeu),
          if (_saving) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(padding: EdgeInsets.fromLTRB(px, 6, px, 24), children: [
                Container(
                  decoration: SalesUi.card(isNeu),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: configInput(isNeu, 'Role Name *', hint: 'e.g. Store Manager').copyWith(counterText: ''),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a role name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: configInput(isNeu, 'Description (optional)', hint: 'What is this role for?'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _active,
                      activeTrackColor: AppColors.primary,
                      onChanged: _saving ? null : (v) => setState(() => _active = v),
                      title: Text('Active', style: TextStyle(fontWeight: FontWeight.w700, color: tp)),
                      subtitle: Text(
                          'Inactive roles can\'t be newly assigned to users, but stay in effect for anyone who already has them.',
                          style: TextStyle(fontSize: 11.5, color: ts)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: SalesUi.card(isNeu),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Permissions', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: tp)),
                    const SizedBox(height: 4),
                    checklist,
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
                  ),
                  child: Text(_saving ? 'Saving...' : (widget.edit == null ? 'Create Role' : 'Save Changes'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
