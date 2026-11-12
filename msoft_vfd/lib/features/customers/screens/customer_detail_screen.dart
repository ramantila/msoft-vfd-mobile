import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/models/sale_list_item.dart';
import '../../sales/screens/sale_detail_screen.dart';
import '../../sales/screens/sales_history_screen.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import '../widgets/customer_widgets.dart';
import 'customer_form_screen.dart';

/// One customer: contact and fiscal details, purchase totals, latest sales,
/// and the actions the user's permissions allow. Pops `true` on any change.
class CustomerDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String customerId;

  const CustomerDetailScreen({super.key, required this.themeMode, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  CustomerDetail? _detail;
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
      final d = await CustomerService.instance.getById(widget.customerId);
      if (mounted) setState(() => _detail = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _edit() async {
    final d = _detail;
    if (d == null) return;
    final updated = await Navigator.of(context)
        .push<CustomerDetail>(slideRight(CustomerFormScreen(themeMode: widget.themeMode, edit: d.customer)));
    if (updated != null && mounted) {
      setState(() {
        _detail = updated;
        _changed = true;
      });
    }
  }

  Future<void> _changeStatus() async {
    final d = _detail;
    if (d == null) return;
    final picked = await showModalBottomSheet<CustomerStatus>(
      context: context,
      backgroundColor: SalesUi.bg(_isNeu),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Text('Customer status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SalesUi.text(_isNeu))),
          const SizedBox(height: 6),
          for (final s in CustomerStatus.values)
            ListTile(
              leading: Icon(
                  s == d.customer.status ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: CustomerUi.statusColor(s)),
              title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(switch (s) {
                CustomerStatus.active => 'Can be chosen in New Sale',
                CustomerStatus.inactive => 'Hidden from New Sale; history kept',
                CustomerStatus.suspended => 'Blocked, e.g. unpaid balance or dispute',
              }),
              onTap: () => Navigator.pop(ctx, s),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null || picked == d.customer.status) return;
    setState(() => _busy = true);
    try {
      final updated = await CustomerService.instance.setStatus(d.customer.id, picked);
      if (!mounted) return;
      setState(() {
        _detail = updated;
        _busy = false;
        _changed = true;
      });
      _toast('Marked ${picked.label.toLowerCase()}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  Future<void> _delete() async {
    final d = _detail;
    if (d == null) return;
    if (d.saleCount > 0 || d.recentSales.isNotEmpty) {
      _toast('${d.customer.customerName} has sales on record. Mark them inactive instead.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text('${d.customer.customerName} will be removed permanently.',
            style: const TextStyle(fontSize: 13)),
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
      await CustomerService.instance.delete(d.customer.id);
      if (!mounted) return;
      _toast('Customer deleted');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  void _openSale(SaleListItem s) =>
      Navigator.of(context).push(slideRight(SaleDetailScreen(themeMode: widget.themeMode, saleId: s.id)));

  void _openAllSales(Customer c) => Navigator.of(context).push(slideRight(SalesHistoryScreen(
        themeMode: widget.themeMode,
        initialPeriod: HistoryPeriod.all,
        customerId: c.id,
        title: c.customerName,
      )));

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final d = _detail;
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
              title: 'Customer',
              isNeu: isNeu,
              actionIcon: d != null && AuthState.has('CUSTOMER_UPDATE') ? Icons.edit_outlined : null,
              onAction: _busy ? null : _edit,
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
            Expanded(child: _body(isNeu, d)),
          ]),
        ),
      ),
    );
  }

  Widget _body(bool isNeu, CustomerDetail? d) {
    if (d == null) {
      if (_error != null) {
        return Center(
          child: SalesMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load customer',
            subtitle: _error!.message,
            isNeu: isNeu,
            onRetry: _load,
          ),
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
          _stats(isNeu, d),
          const SizedBox(height: 14),
          _details(isNeu, d.customer),
          const SizedBox(height: 14),
          _recent(isNeu, d),
          const SizedBox(height: 18),
          _actions(isNeu, d),
        ],
      ),
    );
  }

  Widget _card(bool isNeu, {String? title, Widget? trailing, required List<Widget> children}) {
    return Container(
      decoration: SalesUi.card(isNeu),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 10),
        ],
        ...children,
      ]),
    );
  }

  Widget _hero(bool isNeu, CustomerDetail d) {
    final c = d.customer;
    return _card(isNeu, children: [
      Row(children: [
        CustomerAvatar(name: c.customerName, isNeu: isNeu, size: 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.customerName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
            const SizedBox(height: 4),
            Row(children: [
              CustomerStatusPill(status: c.status),
              if (c.createdAt != null) ...[
                const SizedBox(width: 8),
                Text('Since ${SalesFormat.date(c.createdAt!)}',
                    style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu))),
              ],
            ]),
          ]),
        ),
      ]),
    ]);
  }

  Widget _stats(bool isNeu, CustomerDetail d) {
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    Widget stat(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ts)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tp, fontFeatures: SalesUi.tabular)),
          ]),
        );
    return _card(isNeu, title: 'Purchases', children: [
      Row(children: [
        stat('Total spent', SalesFormat.compactMoney(d.totalSpent)),
        stat('Sales', SalesFormat.number(d.saleCount)),
        stat('Average', d.saleCount == 0 ? '—' : SalesFormat.compactMoney(d.averageSale)),
      ]),
      if (d.lastSaleAt != null) ...[
        const SizedBox(height: 10),
        Text(
          'Last visit ${SalesFormat.dayLabel(d.lastSaleAt!)}'
          '${d.firstSaleAt != null ? ' · first ${SalesFormat.date(d.firstSaleAt!)}' : ''}',
          style: TextStyle(fontSize: 12, color: ts),
        ),
      ],
      const SizedBox(height: 4),
      Text('Completed sales only.', style: TextStyle(fontSize: 11, color: ts)),
    ]);
  }

  Widget _details(bool isNeu, Customer c) {
    final rows = <(String, String?)>[
      ('Phone', c.phone),
      ('Email', c.email),
      ('Address', c.address),
      ('TIN / VRN', c.vrn),
      ('ID', c.idNumber == null ? null : '${c.idTypeName ?? 'ID'} · ${c.idNumber}'),
      ('Branch', c.branchName),
    ];
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    return _card(isNeu, title: 'Details', children: [
      for (final (k, v) in rows)
        InkWell(
          onLongPress: v == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: v));
                  _toast('$k copied');
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 92, child: Text(k, style: TextStyle(fontSize: 13, color: ts))),
              Expanded(
                child: Text(v ?? '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: v == null ? ts : tp)),
              ),
            ]),
          ),
        ),
      if (c.idNumber == null && c.vrn == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('No TIN or ID, so receipts show this customer by name only.',
              style: TextStyle(fontSize: 11.5, color: ts)),
        ),
    ]);
  }

  Widget _recent(bool isNeu, CustomerDetail d) {
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    final canSeeSales = AuthState.has('SALE_VIEW');
    return _card(
      isNeu,
      title: 'Recent sales',
      trailing: d.recentSales.isNotEmpty && canSeeSales
          ? GestureDetector(
              onTap: () => _openAllSales(d.customer),
              child: const Text('See all',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
            )
          : null,
      children: [
        if (d.recentSales.isEmpty)
          Text('No sales yet.', style: TextStyle(fontSize: 13, color: ts))
        else
          for (final s in d.recentSales)
            InkWell(
              onTap: canSeeSales ? () => _openSale(s) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (s.saleDate != null) '${SalesFormat.dayLabel(s.saleDate!)} ${SalesFormat.time(s.saleDate!)}',
                          '${s.itemCount} item${s.itemCount == 1 ? '' : 's'}',
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

  Widget _actions(bool isNeu, CustomerDetail d) {
    final canStatus = AuthState.has('CUSTOMER_MANAGE');
    final canDelete = AuthState.has('CUSTOMER_DELETE');
    if (!canStatus && !canDelete) return const SizedBox.shrink();
    return Row(children: [
      if (canStatus)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _changeStatus,
            icon: const Icon(Icons.toggle_on_outlined, size: 18),
            label: const Text('Change status'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SalesUi.text(isNeu),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      if (canStatus && canDelete) const SizedBox(width: 10),
      if (canDelete)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
    ]);
  }
}
