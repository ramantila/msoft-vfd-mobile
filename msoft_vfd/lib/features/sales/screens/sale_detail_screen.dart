import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';
import '../utils/sales_format.dart';
import '../widgets/sales_widgets.dart';
import 'sale_receipt_screen.dart';

enum _SaleAction { cancel, refund }

/// Full sale: status, fiscal receipt fields, line items, totals, and
/// cancel/refund for users holding SALE_MANAGE. Pops `true` if the sale was
/// changed so the caller can refresh its list.
class SaleDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String saleId;

  const SaleDetailScreen({super.key, required this.themeMode, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Sale? _sale;
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
      final sale = await SaleService.instance.getById(widget.saleId);
      if (mounted) setState(() => _sale = sale);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(_SaleAction action) async {
    final sale = _sale;
    if (sale == null || _busy) return;
    final reason = await _confirm(action, sale);
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = action == _SaleAction.cancel
          ? await SaleService.instance.cancel(sale.id, reason: reason)
          : await SaleService.instance.refund(sale.id, reason: reason);
      if (!mounted) return;
      setState(() {
        _sale = updated;
        _busy = false;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == _SaleAction.cancel ? 'Sale cancelled' : 'Sale refunded')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Returns the (possibly empty) reason, or null if the user backed out.
  Future<String?> _confirm(_SaleAction action, Sale sale) {
    final ctrl = TextEditingController();
    final verb = action == _SaleAction.cancel ? 'Cancel' : 'Refund';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$verb this sale?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${SalesFormat.money(sale.grandTotal)} · '
              '${sale.receiptNo != null ? 'Receipt #${sale.receiptNo}' : 'No receipt no'}\n'
              '${sale.status == SaleStatus.completed ? 'Stock for these items will be returned.' : ''}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep sale')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(verb),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: SalesUi.bg(isNeu),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SalesHeader(
                title: _sale?.receiptNo != null ? 'Sale #${_sale!.receiptNo}' : 'Sale',
                isNeu: isNeu,
                actionIcon: _sale != null ? Icons.receipt_outlined : null,
                onAction: _sale == null
                    ? null
                    : () => Navigator.of(context).push(
                        slideRight(SaleReceiptScreen(themeMode: widget.themeMode, sale: _sale!))),
              ),
              Expanded(child: _buildBody(isNeu)),
              if (_sale != null) _buildActions(isNeu, _sale!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isNeu) {
    if (_error != null) {
      return Center(
        child: SalesMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load this sale",
          subtitle: _error!.message,
          isNeu: isNeu,
          onRetry: _load,
        ),
      );
    }
    final sale = _sale;
    if (sale == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final px = SalesUi.gutter(isNeu);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px, 4, px, 16),
        children: [
          _buildSummaryCard(isNeu, sale),
          const SizedBox(height: 14),
          _buildItems(isNeu, sale),
          const SizedBox(height: 14),
          _buildTotals(isNeu, sale),
          const SizedBox(height: 14),
          _buildInfo(isNeu, sale),
          if (sale.notes != null && sale.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _section(isNeu, 'Notes', [
              Text(sale.notes!.trim(),
                  style: TextStyle(fontSize: 13, height: 1.4, color: SalesUi.text(isNeu))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isNeu, Sale sale) {
    return Container(
      decoration: SalesUi.card(isNeu),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SaleStatusBadge(status: sale.status),
              const Spacer(),
              Text(sale.paymentMethod.label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: SalesUi.textSec(isNeu))),
            ],
          ),
          const SizedBox(height: 10),
          Text(SalesFormat.money(sale.grandTotal),
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: SalesUi.text(isNeu),
                  fontFeatures: SalesUi.tabular)),
          if (sale.saleDate != null)
            Text('${SalesFormat.date(sale.saleDate!)} · ${SalesFormat.time(sale.saleDate!)}',
                style: TextStyle(fontSize: 13, color: SalesUi.textSec(isNeu))),
        ],
      ),
    );
  }

  Widget _buildItems(bool isNeu, Sale sale) {
    return _section(isNeu, '${sale.items.length} item${sale.items.length == 1 ? '' : 's'}', [
      for (var i = 0; i < sale.items.length; i++) ...[
        if (i > 0) Divider(height: 18, color: isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1)),
        _itemRow(isNeu, sale.items[i]),
      ],
    ]);
  }

  Widget _itemRow(bool isNeu, SaleItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: SalesUi.text(isNeu))),
              const SizedBox(height: 2),
              Text(
                '${SalesFormat.quantity(item.quantity)} × ${SalesFormat.money(item.unitPrice)}'
                '${item.discount > 0 ? ' · −${SalesFormat.money(item.discount)}' : ''}'
                '${item.taxCategory != null ? ' · Tax ${item.taxCategory}' : ''}',
                style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(SalesFormat.money(item.lineTotal),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SalesUi.text(isNeu),
                fontFeatures: SalesUi.tabular)),
      ],
    );
  }

  Widget _buildTotals(bool isNeu, Sale sale) {
    return _section(isNeu, null, [
      _kv(isNeu, 'Subtotal', SalesFormat.money(sale.subtotal)),
      if (sale.discountAmount > 0) _kv(isNeu, 'Discount', '−${SalesFormat.money(sale.discountAmount)}'),
      _kv(isNeu, 'Tax', SalesFormat.money(sale.taxTotal)),
      const SizedBox(height: 4),
      _kv(isNeu, 'Total', SalesFormat.money(sale.grandTotal), strong: true),
    ]);
  }

  Widget _buildInfo(bool isNeu, Sale sale) {
    return _section(isNeu, 'Details', [
      if (sale.receiptNo != null) _kv(isNeu, 'Receipt no', sale.receiptNo!),
      if (sale.fiscalCode != null) _kv(isNeu, 'Fiscal code', sale.fiscalCode!),
      if (sale.receiptZNo != null) _kv(isNeu, 'Z number', sale.receiptZNo!),
      _kv(isNeu, 'Branch', sale.branchName ?? '—'),
      _kv(isNeu, 'Cashier', sale.username ?? '—'),
      _kv(isNeu, 'Customer', sale.customerName ?? 'Walk-in'),
      _kv(isNeu, 'Currency', sale.currency),
    ]);
  }

  Widget _section(bool isNeu, String? title, List<Widget> children) {
    return Container(
      decoration: SalesUi.card(isNeu),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: SalesUi.text(isNeu))),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _kv(bool isNeu, String k, String v, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(k,
              style: TextStyle(
                  fontSize: strong ? 15 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  color: strong ? SalesUi.text(isNeu) : SalesUi.textSec(isNeu))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: strong ? 15 : 13,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    color: SalesUi.text(isNeu),
                    fontFeatures: SalesUi.tabular)),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isNeu, Sale sale) {
    final canManage = AuthState.has('SALE_MANAGE');
    final canCancel = canManage &&
        (sale.status == SaleStatus.pending || sale.status == SaleStatus.completed);
    final canRefund = canManage && sale.status == SaleStatus.completed;
    if (!canCancel && !canRefund) return const SizedBox.shrink();

    final px = SalesUi.gutter(isNeu);
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 8, px, MediaQuery.of(context).padding.bottom + 14),
      child: Row(
        children: [
          if (canCancel)
            Expanded(child: _actionButton(isNeu, 'Cancel sale', () => _run(_SaleAction.cancel))),
          if (canCancel && canRefund) const SizedBox(width: 10),
          if (canRefund)
            Expanded(child: _actionButton(isNeu, 'Refund', () => _run(_SaleAction.refund))),
        ],
      ),
    );
  }

  Widget _actionButton(bool isNeu, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: SalesUi.card(isNeu, radius: 13),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.error))
            : Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error)),
      ),
    );
  }
}
