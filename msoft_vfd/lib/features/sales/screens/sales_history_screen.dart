import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sale.dart';
import '../models/sale_list_item.dart';
import '../services/sale_service.dart';
import '../utils/sales_format.dart';
import '../widgets/sales_widgets.dart';
import 'sale_detail_screen.dart';

enum HistoryPeriod { today, yesterday, week, month, all }

extension on HistoryPeriod {
  String get label => switch (this) {
        HistoryPeriod.today => 'Today',
        HistoryPeriod.yesterday => 'Yesterday',
        HistoryPeriod.week => '7 days',
        HistoryPeriod.month => '30 days',
        HistoryPeriod.all => 'All',
      };

  /// Inclusive [from, to] dates, or nulls for no date filter.
  (DateTime?, DateTime?) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      HistoryPeriod.today => (today, today),
      HistoryPeriod.yesterday => (
          today.subtract(const Duration(days: 1)),
          today.subtract(const Duration(days: 1))
        ),
      HistoryPeriod.week => (today.subtract(const Duration(days: 6)), today),
      HistoryPeriod.month => (today.subtract(const Duration(days: 29)), today),
      HistoryPeriod.all => (null, null),
    };
  }
}

/// Paginated, filterable list of the company's sales, newest first.
class SalesHistoryScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final HistoryPeriod initialPeriod;

  /// Limits the list to one customer's or one cashier's sales; [title] then names them.
  final String? customerId;
  final String? userId;
  final String? title;

  const SalesHistoryScreen({
    super.key,
    required this.themeMode,
    this.initialPeriod = HistoryPeriod.today,
    this.customerId,
    this.userId,
    this.title,
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  static const _pageSize = 20;

  late HistoryPeriod _period = widget.initialPeriod;
  SaleStatus? _status;
  String _query = '';
  Timer? _debounce;
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  final List<SaleListItem> _sales = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  ApiException? _error;

  // Bumped on every filter change so a slow response for an old filter
  // can't append into the list for a new one.
  int _generation = 0;

  bool get _hasMore => _sales.length < _total;
  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

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

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _sales.clear();
      _total = 0;
      _page = 0;
      _error = null;
      _loading = false;
    });
    await _fetch();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _error != null) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    final generation = _generation;
    final (from, to) = _period.range;
    setState(() => _loading = true);
    try {
      final page = await SaleService.instance.history(
        from: from,
        to: to,
        status: _status,
        customerId: widget.customerId,
        userId: widget.userId,
        query: _query,
        page: _page,
        size: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _sales.addAll(page.content);
        _total = page.totalElements;
        _page++;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {}); // show/hide the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (value.trim() == _query) return;
      _query = value.trim();
      _reload();
    });
  }

  Future<void> _open(SaleListItem sale) async {
    final changed = await Navigator.of(context).push<bool>(
        slideRight(SaleDetailScreen(themeMode: widget.themeMode, saleId: sale.id)));
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SalesHeader(title: widget.title ?? 'Sales history', isNeu: isNeu),
            _buildSearch(isNeu),
            _buildChips(isNeu),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _reload,
                child: _buildList(isNeu),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(bool isNeu) {
    final px = SalesUi.gutter(isNeu);
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 0, px, 12),
      child: Container(
        decoration: isNeu ? AppTheme.neuInset(radius: 14) : SalesUi.card(false, radius: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: SalesUi.textSec(isNeu)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 14, color: SalesUi.text(isNeu)),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Receipt no, fiscal code or customer',
                  hintStyle: TextStyle(fontSize: 14, color: SalesUi.textSec(isNeu)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _onSearchChanged('');
                  setState(() {});
                },
                child: Icon(Icons.close, size: 18, color: SalesUi.textSec(isNeu)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChips(bool isNeu) {
    final px = SalesUi.gutter(isNeu);
    final statuses = <SaleStatus?>[
      null,
      SaleStatus.completed,
      SaleStatus.cancelled,
      SaleStatus.refunded,
      SaleStatus.pending,
    ];
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(px, 0, px, 10),
          child: Row(
            children: HistoryPeriod.values
                .map((p) => SalesChip(
                      label: p.label,
                      active: p == _period,
                      isNeu: isNeu,
                      onTap: () {
                        if (p == _period) return;
                        _period = p;
                        _reload();
                      },
                    ))
                .toList(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(px, 0, px, 12),
          child: Row(
            children: statuses
                .map((s) => SalesChip(
                      label: s?.label ?? 'Any status',
                      active: s == _status,
                      isNeu: isNeu,
                      onTap: () {
                        if (s == _status) return;
                        _status = s;
                        _reload();
                      },
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildList(bool isNeu) {
    final px = SalesUi.gutter(isNeu);

    // Empty / error states still need a scrollable for pull-to-refresh.
    if (_sales.isEmpty) {
      Widget child;
      if (_loading) {
        child = const Padding(
          padding: EdgeInsets.only(top: 64),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        );
      } else if (_error != null) {
        child = SalesMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load sales",
          subtitle: _error!.message,
          isNeu: isNeu,
          onRetry: _reload,
        );
      } else {
        child = SalesMessage(
          icon: Icons.receipt_long_outlined,
          title: 'No sales found',
          subtitle: _query.isNotEmpty || _status != null
              ? 'Try a different search or filter.'
              : 'Sales recorded ${_period == HistoryPeriod.all ? '' : 'in this period '}will appear here.',
          isNeu: isNeu,
        );
      }
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [child]);
    }

    // Flatten into day headers + rows.
    final entries = <Object>[];
    String? lastDay;
    for (final s in _sales) {
      final day = s.saleDate != null ? SalesFormat.dayLabel(s.saleDate!) : 'Unknown date';
      if (day != lastDay) {
        entries.add(day);
        lastDay = day;
      }
      entries.add(s);
    }

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(px, 0, px, MediaQuery.of(context).padding.bottom + 16),
      itemCount: entries.length + 1,
      itemBuilder: (context, i) {
        if (i == entries.length) return _buildFooter(isNeu);
        final e = entries[i];
        if (e is String) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 14, bottom: 8, left: 4),
            child: Text(e,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: SalesUi.textSec(isNeu))),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SaleRow(sale: e as SaleListItem, isNeu: isNeu, onTap: () => _open(e)),
        );
      },
    );
  }

  Widget _buildFooter(bool isNeu) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary))),
      );
    }
    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _error = null);
            _loadMore();
          },
          child: const Text("Couldn't load more — tap to retry"),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          _hasMore ? '' : '$_total sale${_total == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu)),
        ),
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final SaleListItem sale;
  final bool isNeu;
  final VoidCallback onTap;

  const _SaleRow({required this.sale, required this.isNeu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = sale.status == SaleStatus.cancelled || sale.status == SaleStatus.refunded;
    final parts = <String>[
      if (sale.saleDate != null) SalesFormat.time(sale.saleDate!),
      sale.paymentMethod.label,
      '${sale.itemCount} item${sale.itemCount == 1 ? '' : 's'}',
      if (sale.customerName != null && sale.customerName!.isNotEmpty) sale.customerName!,
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: SalesUi.card(isNeu, radius: 16),
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isNeu ? AppColors.bgNeu : const Color(0xFFE7F6EF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isNeu
                    ? const [
                        BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 6, offset: Offset(3, 3), spreadRadius: -1),
                        BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 6, offset: Offset(-3, -3), spreadRadius: -1),
                      ]
                    : null,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 19, color: muted ? SalesUi.textSec(isNeu) : AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(sale.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: SalesUi.text(isNeu))),
                      ),
                      if (sale.status != SaleStatus.completed) ...[
                        const SizedBox(width: 8),
                        SaleStatusBadge(status: sale.status),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(parts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: SalesUi.textSec(isNeu), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(SalesFormat.money(sale.grandTotal),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: muted ? SalesUi.textSec(isNeu) : SalesUi.text(isNeu),
                  decoration: muted ? TextDecoration.lineThrough : null,
                  fontFeatures: SalesUi.tabular,
                )),
          ],
        ),
      ),
    );
  }
}
