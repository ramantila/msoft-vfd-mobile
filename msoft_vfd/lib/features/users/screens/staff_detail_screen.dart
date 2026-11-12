import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/models/sale_list_item.dart';
import '../../sales/screens/sale_detail_screen.dart';
import '../../sales/screens/sales_history_screen.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/staff.dart';
import '../services/staff_service.dart';
import 'staff_form_screen.dart';
import 'staff_password_screen.dart';
import 'staff_widgets.dart';

/// A staff member's profile, sales today / this month, recent sales and the
/// actions the server allows. Without [userId] it shows "My profile".
/// Pops `true` when anything changed.
class StaffDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String? userId;

  const StaffDetailScreen({super.key, required this.themeMode, this.userId});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  StaffDetail? _d;
  ApiException? _error;
  bool _busy = false;
  bool _changed = false;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _myProfile => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = _myProfile ? await StaffService.instance.me() : await StaffService.instance.getById(widget.userId!);
      if (mounted) setState(() => _d = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guard(Future<StaffDetail?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final d = await action();
      if (!mounted) return;
      setState(() {
        if (d != null) _d = d;
        _busy = false;
        _changed = true;
      });
      _toast(done);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  Future<void> _editMyName() async {
    final u = _d!.user;
    final first = TextEditingController(text: u.firstName);
    final middle = TextEditingController(text: u.middleName ?? '');
    final last = TextEditingController(text: u.lastName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit my name'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: first, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'First name')),
          TextField(controller: middle, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Middle name (optional)')),
          TextField(controller: last, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Last name')),
          const SizedBox(height: 10),
          const Text('Your phone and username are sign-in details; an administrator changes those.',
              style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (first.text.trim().isEmpty || last.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(
      () => StaffService.instance.updateMe(
        firstName: first.text.trim(),
        middleName: middle.text.trim().isEmpty ? null : middle.text.trim(),
        lastName: last.text.trim(),
      ),
      'Name updated',
    );
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<StaffDetail>(
        slideRight(StaffFormScreen(
          themeMode: widget.themeMode,
          edit: _d!.user,
          isMe: _d!.me,
          canResetPassword: _d!.actions.resetPassword,
        )));
    if (updated != null && mounted) {
      setState(() {
        _d = updated;
        _changed = true;
      });
    }
  }

  Future<void> _password() async {
    final u = _d!.user;
    await Navigator.of(context).push<bool>(slideRight(StaffPasswordScreen(
      themeMode: widget.themeMode,
      userId: _d!.me ? null : u.id,
      userName: u.fullName,
    )));
  }

  Future<void> _status() async {
    final u = _d!.user;
    final picked = await showModalBottomSheet<StaffStatus>(
      context: context,
      backgroundColor: SalesUi.bg(_isNeu),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Text('Status for ${u.firstName}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SalesUi.text(_isNeu))),
          for (final s in StaffStatus.values)
            ListTile(
              leading: Icon(s == u.status ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: StaffUi.statusColor(s)),
              title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(switch (s) {
                StaffStatus.active => 'Can sign in and work',
                StaffStatus.inactive => 'Can\'t sign in, e.g. left or on leave',
                StaffStatus.suspended => 'Blocked pending review',
              }),
              onTap: () => Navigator.pop(ctx, s),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null || picked == u.status) return;
    await _guard(() => StaffService.instance.setStatus(u.id, picked), '${u.firstName} is now ${picked.label.toLowerCase()}');
  }

  Future<void> _delete() async {
    final u = _d!.user;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${u.fullName}?'),
        content: const Text(
            'They lose access immediately. Their past sales stay on record.\n\n'
            'If they might come back, mark them Inactive instead.',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await StaffService.instance.delete(u.id);
      if (!mounted) return;
      _toast('${u.fullName} removed');
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
    final canEdit = d != null && (d.me ? true : d.actions.edit);
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
            SalesHeader(
              title: _myProfile ? 'My profile' : 'Staff member',
              isNeu: isNeu,
              actionIcon: canEdit ? Icons.edit_outlined : null,
              onAction: _busy || d == null
                  ? null
                  : (d.me && (_myProfile || !d.actions.edit) ? _editMyName : _edit),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
            Expanded(child: _body(isNeu, d)),
          ]),
        ),
      ),
    );
  }

  Widget _body(bool isNeu, StaffDetail? d) {
    if (d == null) {
      if (_error != null) {
        return Center(
          child: SalesMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn\'t load profile',
              subtitle: _error!.message,
              isNeu: isNeu,
              onRetry: _load),
        );
      }
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px, 6, px, bot + 24),
        children: [
          _hero(isNeu, d),
          const SizedBox(height: 14),
          _sales(isNeu, d),
          const SizedBox(height: 14),
          _details(isNeu, d),
          if (d.recentSales.isNotEmpty) ...[
            const SizedBox(height: 14),
            _recent(isNeu, d),
          ],
          const SizedBox(height: 18),
          _actions(isNeu, d),
        ],
      ),
    );
  }

  Widget _card(bool isNeu, {String? title, Widget? trailing, required List<Widget> children}) => Container(
        decoration: SalesUi.card(isNeu),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu)))),
              ?trailing,
            ]),
            const SizedBox(height: 10),
          ],
          ...children,
        ]),
      );

  Widget _hero(bool isNeu, StaffDetail d) {
    final u = d.user;
    return _card(isNeu, children: [
      Row(children: [
        StaffAvatar(name: u.fullName, size: 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.me && !_myProfile ? '${u.fullName} (you)' : u.fullName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
            const SizedBox(height: 2),
            Text('@${u.username}', style: TextStyle(fontSize: 12.5, color: SalesUi.textSec(isNeu))),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              StaffPill(
                label: u.roleLabel,
                color: u.roleNames.isEmpty && u.role != UserRole.superAdmin
                    ? AppColors.textMuted
                    : StaffUi.roleColor(u.role == UserRole.superAdmin ? UserRole.superAdmin : UserRole.manager),
              ),
              StaffPill(label: u.status.label, color: StaffUi.statusColor(u.status)),
            ]),
          ]),
        ),
      ]),
    ]);
  }

  Widget _sales(bool isNeu, StaffDetail d) {
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    Widget stat(String label, double total, int count) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ts)),
            const SizedBox(height: 4),
            Text(SalesFormat.compactMoney(total),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tp, fontFeatures: SalesUi.tabular)),
            Text('$count sale${count == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.5, color: ts)),
          ]),
        );
    return _card(isNeu, title: _myProfile ? 'My sales' : 'Sales', children: [
      Row(children: [
        stat('Today', d.totalToday, d.salesToday),
        stat('This month', d.totalThisMonth, d.salesThisMonth),
      ]),
      const SizedBox(height: 8),
      Text(
        d.lastSaleAt == null
            ? 'No completed sales yet.'
            : 'Last sale ${SalesFormat.dayLabel(d.lastSaleAt!)} at ${SalesFormat.time(d.lastSaleAt!)}',
        style: TextStyle(fontSize: 12, color: ts),
      ),
    ]);
  }

  Widget _details(bool isNeu, StaffDetail d) {
    final u = d.user;
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    final rows = <(String, String?)>[
      ('Full name', u.fullName),
      ('Role', u.roleLabel),
      ('Phone', u.phone),
      ('Branch', u.branchName ?? 'No branch'),
      ('Username', '@${u.username}'),
      if (u.createdAt != null) ('Member since', SalesFormat.date(u.createdAt!)),
    ];
    return _card(isNeu, title: 'Personal Information', children: [
      for (final (k, v) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 90, child: Text(k, style: TextStyle(fontSize: 13, color: ts))),
            Expanded(
                child: Text(v ?? '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp))),
          ]),
        ),
      if (u.role == UserRole.superAdmin)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('This is a Super Administrator account. Its details can only be changed from the Admin Portal.',
              style: TextStyle(fontSize: 11.5, color: AppColors.warningText, fontWeight: FontWeight.w600)),
        )
      else if (d.actions.lockedReason != null && !_myProfile)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(d.actions.lockedReason!, style: TextStyle(fontSize: 11.5, color: ts)),
        ),
    ]);
  }

  Widget _recent(bool isNeu, StaffDetail d) {
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    return _card(
      isNeu,
      title: 'Recent sales',
      trailing: GestureDetector(
        onTap: () => Navigator.of(context).push(slideRight(SalesHistoryScreen(
          themeMode: widget.themeMode,
          initialPeriod: HistoryPeriod.month,
          userId: d.user.id,
          title: d.me ? 'My sales' : d.user.fullName,
        ))),
        child: const Text('See all',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
      children: [
        for (final SaleListItem s in d.recentSales)
          InkWell(
            onTap: () => Navigator.of(context)
                .push(slideRight(SaleDetailScreen(themeMode: widget.themeMode, saleId: s.id))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp)),
                    Text(
                      [
                        if (s.saleDate != null) '${SalesFormat.dayLabel(s.saleDate!)} ${SalesFormat.time(s.saleDate!)}',
                        ?s.customerName,
                      ].join(' · '),
                      style: TextStyle(fontSize: 11.5, color: ts),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(SalesFormat.money(s.grandTotal),
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800, color: tp, fontFeatures: SalesUi.tabular)),
                  const SizedBox(height: 3),
                  SaleStatusBadge(status: s.status),
                ]),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _actions(bool isNeu, StaffDetail d) {
    final a = d.actions;
    final buttons = <Widget>[
      if (d.me)
        _button(Icons.lock_outline_rounded, 'Change my password', _password, isNeu)
      else if (a.resetPassword && !a.edit)
        _button(Icons.lock_reset_rounded, 'Set new password', _password, isNeu),
      if (!d.me && a.changeStatus) _button(Icons.toggle_on_outlined, 'Change status', _status, isNeu),
      if (!d.me && a.delete) _button(Icons.person_remove_outlined, 'Remove', _delete, isNeu, danger: true),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
      if (_myProfile && AuthState.session != null)
        Text('Signed in as @${AuthState.session!.username}',
            style: TextStyle(fontSize: 11.5, color: SalesUi.textSec(isNeu))),
    ]);
  }

  Widget _button(IconData icon, String label, VoidCallback onTap, bool isNeu, {bool danger = false}) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: danger ? AppColors.error : SalesUi.text(isNeu),
            side: danger ? BorderSide(color: AppColors.error.withValues(alpha: 0.5)) : null,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
