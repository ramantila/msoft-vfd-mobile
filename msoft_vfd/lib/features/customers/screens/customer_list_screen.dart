import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import '../widgets/customer_widgets.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

/// Result of [CustomerListScreen] in pick mode: a customer, or walk-in
/// (`customer == null`). Backing out pops null instead.
class CustomerChoice {
  final CustomerItem? customer;
  const CustomerChoice(this.customer);
}

/// Customer list with search, status filters and paging. With [pickMode]
/// it lists active customers only and pops a [CustomerChoice].
class CustomerListScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final bool pickMode;
  final String? selectedId;

  const CustomerListScreen({super.key, required this.themeMode, this.pickMode = false, this.selectedId});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  static const _pageSize = 30;

  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  CustomerStatus? _status;
  final List<CustomerItem> _items = [];
  CustomerSummary? _summary;
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  ApiException? _error;
  int _generation = 0;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _canAdd => AuthState.has('CUSTOMER_CREATE');
  CustomerStatus? get _statusParam => widget.pickMode ? CustomerStatus.active : _status;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
    setState(() {});
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        CustomerService.instance.list(query: _searchCtrl.text, status: _statusParam, size: _pageSize),
        if (!widget.pickMode) CustomerService.instance.summary(),
      ]);
      final page = results[0] as PageResponse<CustomerItem>;
      final s = results.length > 1 ? results[1] as CustomerSummary : null;
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.content);
        _total = page.totalElements;
        _summary = s ?? _summary;
        _page = 0;
        _hasMore = _items.length < _total;
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

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final PageResponse<CustomerItem> page = await CustomerService.instance
          .list(query: _searchCtrl.text, status: _statusParam, page: _page + 1, size: _pageSize);
      if (!mounted || gen != _generation) return;
      setState(() {
        _page++;
        _items.addAll(page.content);
        _total = page.totalElements;
        _hasMore = page.content.isNotEmpty && _items.length < _total;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _onTap(CustomerItem c) async {
    if (widget.pickMode) {
      Navigator.of(context).pop(CustomerChoice(c));
      return;
    }
    final changed = await Navigator.of(context)
        .push<bool>(slideRight(CustomerDetailScreen(themeMode: widget.themeMode, customerId: c.id)));
    if (changed == true) _reload();
  }

  Future<void> _openAdd() async {
    final created = await Navigator.of(context).push<CustomerDetail>(slideRight(CustomerFormScreen(
      themeMode: widget.themeMode,
      initialName: _searchCtrl.text.trim(),
    )));
    if (created == null || !mounted) return;
    if (widget.pickMode) {
      Navigator.of(context).pop(CustomerChoice(CustomerItem.fromCustomer(created.customer)));
    } else {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final title = widget.pickMode
        ? 'Choose customer'
        : _summary == null
            ? 'Customers'
            : 'Customers · ${SalesFormat.number(_summary!.total)}';
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(
            title: title,
            isNeu: isNeu,
            actionIcon: _canAdd ? Icons.person_add_alt_1_rounded : null,
            onAction: _canAdd ? _openAdd : null,
          ),
          _buildSearch(isNeu),
          if (!widget.pickMode) _buildFilters(isNeu),
          Expanded(child: _buildBody(isNeu)),
        ]),
      ),
    );
  }

  Widget _buildSearch(bool isNeu) {
    final px = SalesUi.gutter(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final active = _searchCtrl.text.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 0, px, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: isNeu
            ? SalesUi.card(true, radius: 14)
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: active ? AppColors.primary : AppColors.borderDefault, width: active ? 1.5 : 1),
              ),
        child: Row(children: [
          Icon(Icons.search_rounded, color: active ? AppColors.primary : ts, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              autofocus: widget.pickMode,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: SalesUi.text(isNeu)),
              decoration: InputDecoration(
                hintText: 'Name, phone, TIN or ID…',
                hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ts),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (active)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                _onSearch('');
              },
              child: Icon(Icons.close_rounded, color: ts, size: 17),
            ),
        ]),
      ),
    );
  }

  Widget _buildFilters(bool isNeu) {
    final s = _summary;
    String c(String label, int? n) => n == null || n == 0 ? label : '$label · $n';
    final chips = <(CustomerStatus?, String)>[
      (null, 'All'),
      (CustomerStatus.active, c('Active', s?.active)),
      (CustomerStatus.inactive, c('Inactive', s?.inactive)),
      (CustomerStatus.suspended, c('Suspended', s?.suspended)),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(SalesUi.gutter(isNeu), 2, 12, 8),
        children: [
          for (final (st, label) in chips)
            SalesChip(
              label: label,
              active: _status == st,
              isNeu: isNeu,
              onTap: () {
                if (_status == st) return;
                setState(() => _status = st);
                _reload();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isNeu) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: SalesMessage(
          icon: _error!.isForbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          title: _error!.isForbidden ? 'No access to customers' : 'Couldn\'t load customers',
          subtitle: _error!.message,
          isNeu: isNeu,
          onRetry: _error!.isForbidden ? null : _reload,
        ),
      );
    }
    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    final searching = _searchCtrl.text.isNotEmpty;
    final header = <Widget>[
      if (widget.pickMode && !searching)
        _WalkInRow(
          isNeu: isNeu,
          selected: widget.selectedId == null,
          onTap: () => Navigator.of(context).pop(const CustomerChoice(null)),
        ),
    ];

    if (_items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _reload,
        child: ListView(padding: EdgeInsets.fromLTRB(px, 4, px, bot + 20), children: [
          ...header,
          SalesMessage(
            icon: searching || _status != null ? Icons.search_off_rounded : Icons.people_outline_rounded,
            title: searching || _status != null ? 'No customers match' : 'No customers yet',
            subtitle: _canAdd ? 'Tap + to add a customer.' : null,
            isNeu: isNeu,
          ),
          if (_canAdd && searching)
            Center(
              child: TextButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text('Add "${_searchCtrl.text.trim()}"'),
              ),
            ),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px, 4, px, bot + 20),
        itemCount: header.length + _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i < header.length) return header[i];
          final j = i - header.length;
          if (j >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                  child: SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
            );
          }
          final c = _items[j];
          return _CustomerRow(
            item: c,
            isNeu: isNeu,
            selected: widget.pickMode && c.id == widget.selectedId,
            onTap: () => _onTap(c),
          );
        },
      ),
    );
  }
}

class _WalkInRow extends StatelessWidget {
  final bool isNeu;
  final bool selected;
  final VoidCallback onTap;
  const _WalkInRow({required this.isNeu, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: SalesUi.card(isNeu, radius: 16),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF0F3F1)),
            child: Icon(Icons.directions_walk_rounded, color: SalesUi.textSec(isNeu)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Walk-in customer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SalesUi.text(isNeu))),
              Text('No customer on the receipt',
                  style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu))),
            ]),
          ),
          if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final CustomerItem item;
  final bool isNeu;
  final bool selected;
  final VoidCallback onTap;
  const _CustomerRow({required this.item, required this.isNeu, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final contact = [item.phone, item.email].whereType<String>().join(' · ');
    final history = item.saleCount == 0
        ? 'No purchases yet'
        : '${item.saleCount} sale${item.saleCount == 1 ? '' : 's'} · ${SalesFormat.compactMoney(item.totalSpent)}'
            '${item.lastSaleAt != null ? ' · last ${SalesFormat.shortDate(item.lastSaleAt!)}' : ''}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: SalesUi.card(isNeu, radius: 16),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CustomerAvatar(name: item.customerName, isNeu: isNeu),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(item.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                ),
                if (item.status != CustomerStatus.active) ...[
                  const SizedBox(width: 6),
                  CustomerStatusPill(status: item.status),
                ],
              ]),
              if (contact.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(contact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ts)),
              ],
              const SizedBox(height: 4),
              Text(history,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: item.saleCount == 0 ? ts : AppColors.primaryDark)),
            ]),
          ),
          const SizedBox(width: 8),
          selected
              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              : Icon(Icons.chevron_right_rounded, size: 18, color: ts),
        ]),
      ),
    );
  }
}
