import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../configurations/screens/config_widgets.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../../users/screens/staff_widgets.dart';
import '../models/access_models.dart';
import '../services/access_service.dart';
import 'role_screens.dart';

/// The portal's Access Control page: a Roles tab (your company's roles) and a
/// browse-only Permissions tab (the platform-wide catalog).
class AccessControlScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const AccessControlScreen({super.key, required this.themeMode});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  final _rolesKey = GlobalKey<_RolesTabState>();

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _newRole() async {
    final created =
        await Navigator.of(context).push<RoleDetail>(slideRight(RoleFormScreen(themeMode: widget.themeMode)));
    if (created != null) _rolesKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final canCreate = AuthState.has('ROLE_CREATE') && _tabs.index == 0;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(
            title: 'Access Control',
            isNeu: isNeu,
            actionIcon: canCreate ? Icons.add_moderator_outlined : null,
            onAction: canCreate ? _newRole : null,
          ),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: SalesUi.textSec(isNeu),
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: const [Tab(text: 'Roles'), Tab(text: 'Permissions')],
          ),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _RolesTab(key: _rolesKey, themeMode: widget.themeMode),
              _PermissionsTab(themeMode: widget.themeMode),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RolesTab extends StatefulWidget {
  final AppThemeMode themeMode;
  const _RolesTab({super.key, required this.themeMode});

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  List<RoleItem> _roles = [];
  bool _loading = true;
  ApiException? _error;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AccessService.instance.roles();
      if (mounted) {
        setState(() {
          _roles = r;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    if (_loading && _roles.isEmpty) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null && _roles.isEmpty) {
      return Center(
          child: SalesMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Failed to load roles',
              subtitle: _error!.message,
              isNeu: isNeu,
              onRetry: reload));
    }
    final px = SalesUi.gutter(isNeu);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px, 12, px, MediaQuery.of(context).padding.bottom + 20),
        children: [
          Text('Your Company\'s Roles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ts)),
          const SizedBox(height: 10),
          if (_roles.isEmpty)
            SalesMessage(
              icon: Icons.shield_outlined,
              title: 'No roles yet',
              subtitle: AuthState.has('ROLE_CREATE')
                  ? 'Create a role, then assign it to staff under System Users.'
                  : null,
              isNeu: isNeu,
            ),
          for (final r in _roles) ...[
            GestureDetector(
              onTap: () async {
                final changed = await Navigator.of(context)
                    .push<bool>(slideRight(RoleDetailScreen(themeMode: widget.themeMode, roleId: r.id)));
                if (changed == true) reload();
              },
              child: Container(
                decoration: SalesUi.card(isNeu, radius: 16),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.shield_outlined, color: r.active ? AppColors.purple : AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                      if (r.description != null)
                        Text(r.description!,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: ts)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        ActivePill(active: r.active),
                        StaffPill(label: '${r.permissionCount} permissions', color: AppColors.purple),
                        StaffPill(
                            label: '${r.userCount} user${r.userCount == 1 ? '' : 's'}',
                            color: r.userCount == 0 ? AppColors.textMuted : AppColors.primaryDark),
                      ]),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PermissionsTab extends StatefulWidget {
  final AppThemeMode themeMode;
  const _PermissionsTab({required this.themeMode});

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<PermissionGroup> _groups = [];
  bool _loading = true;
  ApiException? _error;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final g = await AccessService.instance.catalog(query: _search.text);
      if (mounted) {
        setState(() {
          _groups = g;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final ts = SalesUi.textSec(isNeu);
    final px = SalesUi.gutter(isNeu);
    final total = _groups.fold<int>(0, (n, g) => n + g.items.length);
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(px, 12, px, 6),
        child: Text(
          'This is the platform-wide permission catalog, shared across every company — browse only. '
          'Use the Roles tab to pick which of these apply to your own company\'s staff.',
          style: TextStyle(fontSize: 12, color: ts, height: 1.4),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(px, 4, px, 8),
        child: TextField(
          controller: _search,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), _load);
          },
          decoration: InputDecoration(
            hintText: 'Search permissions…',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: true,
            fillColor: isNeu ? AppColors.bgNeu : Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDefault)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDefault)),
          ),
        ),
      ),
      Expanded(
        child: _loading && _groups.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null && _groups.isEmpty
                ? Center(
                    child: SalesMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Failed to load permissions',
                        subtitle: _error!.message,
                        isNeu: isNeu,
                        onRetry: _load))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(px, 0, px, MediaQuery.of(context).padding.bottom + 20),
                      children: [
                        Text('All Permissions · $total',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ts)),
                        const SizedBox(height: 8),
                        for (final g in _groups) ...[
                          Container(
                            decoration: SalesUi.card(isNeu, radius: 14),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(g.label,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final p in g.items)
                                  Tooltip(
                                    message: '${p.name}${p.inPackage ? '' : ' (not in your package)'}',
                                    child: StaffPill(
                                      label: p.actionLabel,
                                      color: p.inPackage ? AppColors.primaryDark : AppColors.textMuted,
                                    ),
                                  ),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(children: [
                          const StaffPill(label: 'Green', color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text('in your package; grey = not included',
                                  style: TextStyle(fontSize: 11.5, color: ts))),
                        ]),
                      ],
                    ),
                  ),
      ),
    ]);
  }
}
