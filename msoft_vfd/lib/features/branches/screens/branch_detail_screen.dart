import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../products/screens/product_detail_screen.dart';
import '../../products/widgets/product_widgets.dart';
import '../../sales/screens/sale_detail_screen.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../../users/models/staff.dart';
import '../../users/screens/staff_detail_screen.dart';
import '../../users/screens/staff_widgets.dart';
import '../models/branch.dart';
import '../services/branch_service.dart';
import 'branch_form_screen.dart';

/// One branch: figures, staff, stock alerts, recent sales, edit and delete.
/// Pops `true` when anything changed.
class BranchDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String branchId;
  final int? maxUsers;

  const BranchDetailScreen({super.key, required this.themeMode, required this.branchId, this.maxUsers});

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  BranchDetail? _d;
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
      final d = await BranchService.instance.getById(widget.branchId);
      if (mounted) setState(() => _d = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<BranchDetail>(
        slideRight(BranchFormScreen(themeMode: widget.themeMode, edit: _d, maxUsers: widget.maxUsers)));
    if (updated != null && mounted) {
      setState(() {
        _d = updated;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final d = _d!;
    final check = d.deleteCheck;
    if (!check.allowed) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Can\'t delete ${d.branchName} yet'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final b in check.blockers)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 13))),
                ]),
              ),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${d.branchName}?'),
        content: Text(
          [
            'This can\'t be undone.',
            ...check.notes.map((n) => '$n.'),
            'Any empty stock records for this branch will be removed.',
          ].join('\n\n'),
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await BranchService.instance.delete(d.id);
      if (!mounted) return;
      _toast('${d.branchName} deleted');
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
              title: d?.branchName ?? 'Branch',
              isNeu: isNeu,
              actionIcon: d != null && AuthState.has('BRANCH_UPDATE') ? Icons.edit_outlined : null,
              onAction: _busy ? null : _edit,
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
            Expanded(child: _body(isNeu, d)),
          ]),
        ),
      ),
    );
  }

  Widget _body(bool isNeu, BranchDetail? d) {
    if (d == null) {
      if (_error != null) {
        return Center(
          child: SalesMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn\'t load branch',
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
          _overview(isNeu, d),
          const SizedBox(height: 14),
          _staff(isNeu, d),
          if (d.stockAlerts.isNotEmpty) ...[
            const SizedBox(height: 14),
            _stock(isNeu, d),
          ],
          if (d.recentSales.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sales(isNeu, d),
          ],
          if (AuthState.has('BRANCH_DELETE')) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(d.deleteCheck.allowed ? 'Delete branch' : 'Delete branch (see what\'s in the way)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(bool isNeu, String? title, List<Widget> children, {Widget? trailing}) => Container(
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

  Widget _overview(bool isNeu, BranchDetail d) {
    final f = d.figures;
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    Widget stat(String label, String value, String? sub) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ts)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tp, fontFeatures: SalesUi.tabular)),
            if (sub != null) Text(sub, style: TextStyle(fontSize: 11, color: ts)),
          ]),
        );
    return _card(isNeu, null, [
      Row(children: [
        const Icon(Icons.place_outlined, size: 16, color: AppColors.primaryDark),
        const SizedBox(width: 6),
        Expanded(
            child: Text(d.location ?? 'No location set',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: d.location == null ? ts : tp))),
        if (f.mine) const StaffPill(label: 'My branch', color: AppColors.primaryDark),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        stat('Today', SalesFormat.compactMoney(f.totalToday), '${f.salesToday} sales'),
        stat('This month', SalesFormat.compactMoney(f.totalThisMonth), null),
        stat('Customers', SalesFormat.number(f.customerCount), null),
      ]),
    ]);
  }

  Widget _staff(bool isNeu, BranchDetail d) {
    final f = d.figures;
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    final canOpen = AuthState.has('USER_VIEW');
    return _card(
      isNeu,
      'Staff',
      [
        if (d.staff.isEmpty)
          Text('No one is assigned here yet. Assign staff from Administration → Staff.',
              style: TextStyle(fontSize: 13, color: ts))
        else
          for (final s in d.staff)
            InkWell(
              onTap: canOpen
                  ? () => Navigator.of(context)
                      .push(slideRight(StaffDetailScreen(themeMode: widget.themeMode, userId: s.id)))
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  StaffAvatar(name: s.fullName, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(s.fullName,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp))),
                  StaffPill(label: s.role.label, color: StaffUi.roleColor(s.role)),
                  if (s.status != StaffStatus.active) ...[
                    const SizedBox(width: 6),
                    StaffPill(label: s.status.label, color: StaffUi.statusColor(s.status)),
                  ],
                ]),
              ),
            ),
      ],
      trailing: Text(f.capacity == null ? '${f.staffCount}' : '${f.staffCount} of ${f.capacity}',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: f.full ? AppColors.warningText : ts)),
    );
  }

  Widget _stock(bool isNeu, BranchDetail d) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final canOpen = AuthState.has('PRODUCT_VIEW');
    final total = d.figures.lowStock + d.figures.outOfStock;
    return _card(
      isNeu,
      'Needs restocking',
      [
        for (final a in d.stockAlerts)
          InkWell(
            onTap: canOpen
                ? () => Navigator.of(context)
                    .push(slideRight(ProductDetailScreen(themeMode: widget.themeMode, productId: a.productId)))
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.productName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp)),
                    Text('Reorder at ${a.reorderLevel}', style: TextStyle(fontSize: 11.5, color: ts)),
                  ]),
                ),
                Text('${a.quantityOnHand}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ProductUi.stockColor(a.status),
                        fontFeatures: SalesUi.tabular)),
              ]),
            ),
          ),
        if (total > d.stockAlerts.length)
          Text('and ${total - d.stockAlerts.length} more', style: TextStyle(fontSize: 12, color: ts)),
      ],
      trailing: Text('$total', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.warningText)),
    );
  }

  Widget _sales(bool isNeu, BranchDetail d) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    return _card(isNeu, 'Recent sales', [
      for (final s in d.recentSales)
        InkWell(
          onTap: () => Navigator.of(context)
              .push(slideRight(SaleDetailScreen(themeMode: widget.themeMode, saleId: s.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp)),
                  Text(
                    [
                      if (s.saleDate != null) '${SalesFormat.dayLabel(s.saleDate!)} ${SalesFormat.time(s.saleDate!)}',
                      ?s.username,
                    ].join(' · '),
                    style: TextStyle(fontSize: 11.5, color: ts),
                  ),
                ]),
              ),
              Text(SalesFormat.money(s.grandTotal),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: tp, fontFeatures: SalesUi.tabular)),
            ]),
          ),
        ),
    ]);
  }
}
