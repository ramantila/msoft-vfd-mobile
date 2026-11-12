import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/branch.dart';
import '../services/branch_service.dart';
import 'branch_detail_screen.dart';
import 'branch_form_screen.dart';
import '../../users/screens/staff_widgets.dart';

/// All branches with today's sales, staff vs limit and stock alerts.
class BranchListScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const BranchListScreen({super.key, required this.themeMode});

  @override
  State<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends State<BranchListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<BranchItem> _items = [];
  BranchSummary? _summary;
  bool _loading = true;
  ApiException? _error;
  int _generation = 0;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _canAdd => AuthState.has('BRANCH_CREATE');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        BranchService.instance.list(query: _searchCtrl.text),
        BranchService.instance.summary(),
      ]);
      final items = results[0] as List<BranchItem>;
      final s = results[1] as BranchSummary;
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = items;
        _summary = s;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final s = _summary;
    if (s != null && !s.canAddMore) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Limit reached for the ${s.packageName ?? 'current'} plan (${s.maxBranches} branches).')));
      return;
    }
    final created = await Navigator.of(context)
        .push<BranchDetail>(slideRight(BranchFormScreen(themeMode: widget.themeMode, maxUsers: s?.maxUsers, summary: s)));
    if (created != null) _reload();
  }

  Future<void> _open(BranchItem b) async {
    final changed = await Navigator.of(context).push<bool>(slideRight(
        BranchDetailScreen(themeMode: widget.themeMode, branchId: b.id, maxUsers: _summary?.maxUsers)));
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(
            title: 'Branches',
            isNeu: isNeu,
            actionIcon: _canAdd ? Icons.add_business_outlined : null,
            onAction: _canAdd ? _add : null,
          ),
          if (_summary != null) _summaryCard(isNeu, _summary!),
          if (_items.length > 4 || _searchCtrl.text.isNotEmpty) _search(isNeu),
          Expanded(child: _body(isNeu)),
        ]),
      ),
    );
  }

  Widget _summaryCard(bool isNeu, BranchSummary s) {
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    final px = SalesUi.gutter(isNeu);
    final limit = s.maxBranches;
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 0, px, 12),
      child: Container(
        decoration: SalesUi.card(isNeu),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          if (limit != null) ...[
            QuotaBar(used: s.branchCount, max: limit, noun: 'branches', packageName: s.packageName ?? '', isNeu: isNeu),
            const SizedBox(height: 12),
          ],
          Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('All Branches', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ts)),
              const SizedBox(height: 3),
              Text('${s.branchCount}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tp)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sales today', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ts)),
              const SizedBox(height: 3),
              Text(SalesFormat.compactMoney(s.totalToday),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tp, fontFeatures: SalesUi.tabular)),
              Text('${s.salesToday} sale${s.salesToday == 1 ? '' : 's'} across branches',
                  style: TextStyle(fontSize: 11, color: ts)),
            ]),
          ),
          ]),
        ]),
      ),
    );
  }

  Widget _search(bool isNeu) {
    final px = SalesUi.gutter(isNeu);
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 0, px, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), _reload);
        },
        decoration: InputDecoration(
          hintText: 'Search name or location…',
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
    );
  }

  Widget _body(bool isNeu) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: SalesMessage(
          icon: _error!.isForbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          title: _error!.isForbidden ? 'No access to branches' : 'Couldn\'t load branches',
          subtitle: _error!.message,
          isNeu: isNeu,
          onRetry: _error!.isForbidden ? null : _reload,
        ),
      );
    }
    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(children: [
              SalesMessage(
                icon: Icons.store_mall_directory_outlined,
                title: _searchCtrl.text.isEmpty ? 'No branches yet' : 'No branches match',
                subtitle: _canAdd && _searchCtrl.text.isEmpty ? 'Add your first location to start selling.' : null,
                isNeu: isNeu,
              ),
            ])
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(px, 0, px, bot + 20),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _BranchCard(item: _items[i], isNeu: isNeu, onTap: () => _open(_items[i])),
            ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final BranchItem item;
  final bool isNeu;
  final VoidCallback onTap;
  const _BranchCard({required this.item, required this.isNeu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    Widget metric(IconData icon, String text, {Color? color}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color ?? ts),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color ?? ts)),
        ]);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: SalesUi.card(isNeu, radius: 16),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: const Color(0xFFDFF5EB), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront_rounded, color: AppColors.primaryDark, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.mine ? '${item.branchName} (my branch)' : item.branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: tp)),
                if (item.location != null)
                  Text(item.location!,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: ts)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(item.salesToday == 0 ? '—' : SalesFormat.compactMoney(item.totalToday),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: item.salesToday == 0 ? ts : AppColors.primaryDark,
                      fontFeatures: SalesUi.tabular)),
              Text('today', style: TextStyle(fontSize: 10.5, color: ts)),
            ]),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            metric(Icons.people_outline_rounded,
                item.capacity == null ? '${item.staffCount} staff' : '${item.staffCount}/${item.capacity} staff',
                color: item.full ? AppColors.warningText : null),
            metric(Icons.calendar_month_outlined, '${SalesFormat.compactMoney(item.totalThisMonth)} this month'),
            if (item.stockAlerts > 0)
              metric(Icons.warning_amber_rounded,
                  '${item.stockAlerts} stock alert${item.stockAlerts == 1 ? '' : 's'}',
                  color: item.outOfStock > 0 ? AppColors.error : AppColors.warningText),
            if (item.customerCount > 0) metric(Icons.person_outline_rounded, '${item.customerCount} customers'),
          ]),
        ]),
      ),
    );
  }
}
