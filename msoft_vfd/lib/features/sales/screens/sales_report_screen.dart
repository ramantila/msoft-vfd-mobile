import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sale.dart';
import '../models/sales_summary.dart';
import '../services/sale_service.dart';
import '../utils/sales_format.dart';
import '../widgets/sales_widgets.dart';
import 'sales_history_screen.dart';

class SalesReportScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const SalesReportScreen({super.key, required this.themeMode});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  late AppThemeMode _theme;
  String _period = 'Weekly';
  DateTimeRange? _custom;

  SalesSummary? _summary;
  ApiException? _error;
  bool _loading = false;
  int _generation = 0;

  static const _periods = ['Daily', 'Weekly', 'Monthly', 'Custom'];

  @override
  void initState() {
    super.initState();
    _theme = widget.themeMode;
    _load();
  }

  /// Inclusive date range for the selected period.
  (DateTime, DateTime) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      'Daily' => (today, today),
      'Monthly' => (DateTime(today.year, today.month, 1), today),
      'Custom' when _custom != null => (_custom!.start, _custom!.end),
      _ => (today.subtract(const Duration(days: 6)), today),
    };
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final (from, to) = _range;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await SaleService.instance.summary(from: from, to: to, topProducts: 5);
      if (!mounted || generation != _generation) return;
      setState(() {
        _summary = summary;
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

  Future<void> _selectPeriod(String p) async {
    if (p == 'Custom') {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: _custom,
      );
      if (picked == null) return;
      if (picked.end.difference(picked.start).inDays > 365) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Choose a range of at most one year.')));
        return;
      }
      _custom = picked;
    } else if (p == _period) {
      return;
    }
    setState(() => _period = p);
    _load();
  }

  void _openHistory() {
    final period = switch (_period) {
      'Daily' => HistoryPeriod.today,
      'Weekly' => HistoryPeriod.week,
      'Monthly' => HistoryPeriod.month,
      _ => HistoryPeriod.all,
    };
    Navigator.of(context)
        .push(slideRight(SalesHistoryScreen(themeMode: _theme, initialPeriod: period)));
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final textPrimary = SalesUi.text(isNeu);

    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SalesHeader(
              title: 'Sales report',
              isNeu: isNeu,
              actionIcon: Icons.receipt_long_outlined,
              onAction: _openHistory,
            ),
            _buildPeriodFilter(isNeu),
            Expanded(child: _buildBody(isNeu, textPrimary)),
            _buildExportRow(isNeu, textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilter(bool isNeu) {
    final px = SalesUi.gutter(isNeu);
    final (from, to) = _range;
    final rangeLabel = from == to
        ? SalesFormat.date(from)
        : '${SalesFormat.shortDate(from)} – ${SalesFormat.shortDate(to)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 0, px, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periods
                  .map((p) => SalesChip(
                        label: p == 'Custom' && _custom != null && _period == 'Custom' ? 'Custom ✓' : p,
                        active: p == _period,
                        isNeu: isNeu,
                        onTap: () => _selectPeriod(p),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(rangeLabel,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: SalesUi.textSec(isNeu))),
        ],
      ),
    );
  }

  Widget _buildBody(bool isNeu, Color textPrimary) {
    final px = SalesUi.gutter(isNeu);
    final summary = _summary;

    if (summary == null) {
      if (_error != null) {
        return Center(
          child: SalesMessage(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load the report",
            subtitle: _error!.message,
            isNeu: isNeu,
            onRetry: _load,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px, 4, px, 16),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text("Couldn't refresh: ${_error!.message}",
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ),
          _buildSummaryRow(isNeu, textPrimary, summary),
          const SizedBox(height: 16),
          _buildRevenueChart(isNeu, textPrimary, summary),
          const SizedBox(height: 16),
          _buildPaymentBreakdown(isNeu, textPrimary, summary),
          const SizedBox(height: 16),
          _buildTopProducts(isNeu, textPrimary, summary),
          if (summary.cancelledCount + summary.refundedCount + summary.pendingCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${[
                if (summary.cancelledCount > 0) '${summary.cancelledCount} cancelled',
                if (summary.refundedCount > 0) '${summary.refundedCount} refunded',
                if (summary.pendingCount > 0) '${summary.pendingCount} pending',
              ].join(' · ')} — not included in totals',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(bool isNeu, Color textPrimary, SalesSummary s) {
    final cards = [
      _StatCard('Total sales', SalesFormat.compactMoney(s.grossTotal)),
      _StatCard('Transactions', SalesFormat.number(s.saleCount)),
      _StatCard('Avg sale', SalesFormat.compactMoney(s.averageSale)),
    ];

    return Row(
      children: cards.map((c) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: c == cards.last ? 0 : 10),
            decoration: SalesUi.card(isNeu, radius: 14),
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label,
                    style: TextStyle(
                        fontSize: 11, color: SalesUi.textSec(isNeu), fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(c.value,
                      style: TextStyle(
                          fontSize: isNeu ? 16 : 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          fontFeatures: SalesUi.tabular)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _bucketLabel(TrendPoint p, SummaryGranularity g, int index, int count) {
    switch (g) {
      case SummaryGranularity.hour:
        return index % 6 == 0 ? p.start.hour.toString().padLeft(2, '0') : '';
      case SummaryGranularity.month:
        return SalesFormat.month(p.start);
      case SummaryGranularity.day:
        if (count <= 7) return SalesFormat.weekday(p.start);
        final step = (count / 6).ceil();
        return index % step == 0 ? '${p.start.day}' : '';
    }
  }

  Widget _buildRevenueChart(bool isNeu, Color textPrimary, SalesSummary s) {
    final points = s.trend;
    final max = points.fold<double>(0, (m, p) => p.total > m ? p.total : m);
    var peak = -1;
    for (var i = 0; i < points.length; i++) {
      if (max > 0 && points[i].total == max) peak = i;
    }
    final change = SalesFormat.change(s.changePercent);
    final barIdle = isNeu ? const Color(0xFFCBD3CE) : const Color(0xFFA7E3CB);
    final gap = points.length > 14 ? 1.5 : 4.0;

    return Container(
      decoration: SalesUi.card(isNeu),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Revenue trend',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
              const Spacer(),
              if (change != null)
                Text(change,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (s.changePercent ?? 0) >= 0
                            ? const Color(0xFF0E7A55)
                            : AppColors.error)),
            ],
          ),
          if (change != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text('vs ${SalesFormat.compactMoney(s.previousPeriodTotal)} previous period',
                  style: TextStyle(fontSize: 11, color: SalesUi.textSec(isNeu))),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: max == 0
                ? Center(
                    child: Text('No completed sales in this period',
                        style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu))))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(points.length, (i) {
                      final p = points[i];
                      final label = _bucketLabel(p, s.granularity, i, points.length);
                      return Expanded(
                        child: Tooltip(
                          message: '${SalesFormat.money(p.total)} · ${p.saleCount} sale${p.saleCount == 1 ? '' : 's'}',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    // A sliver for zero buckets keeps the axis readable.
                                    heightFactor: p.total <= 0 ? 0.02 : (p.total / max).clamp(0.04, 1.0),
                                    child: Container(
                                      margin: EdgeInsets.symmetric(horizontal: gap),
                                      decoration: BoxDecoration(
                                        color: i == peak ? AppColors.primary : barIdle,
                                        borderRadius: BorderRadius.circular(points.length > 14 ? 3 : 6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 13,
                                child: OverflowBox(
                                  maxWidth: 40,
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: i == peak ? textPrimary : AppColors.textSecondary,
                                          fontWeight: i == peak ? FontWeight.w700 : FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  static Color _methodColor(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => AppColors.primary,
        PaymentMethod.mobileMoney => AppColors.blue,
        PaymentMethod.card => const Color(0xFFF59E0B),
        PaymentMethod.invoice => AppColors.purple,
        PaymentMethod.cheque => const Color(0xFF64748B),
      };

  Widget _buildPaymentBreakdown(bool isNeu, Color textPrimary, SalesSummary s) {
    final methods = s.byPaymentMethod
        .map((m) => _PayMethod(
              m.paymentMethod.label,
              (m.share / 100).clamp(0.0, 1.0),
              '${m.share.round()}%',
              _methodColor(m.paymentMethod),
            ))
        .toList();

    return Container(
      decoration: SalesUi.card(isNeu),
      padding: EdgeInsets.all(isNeu ? 18 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By payment method',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 14),
          if (methods.isEmpty)
            Text('No completed sales in this period',
                style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu))),
          ...methods.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _buildBar(m, isNeu, textPrimary),
              )),
        ],
      ),
    );
  }

  Widget _buildTopProducts(bool isNeu, Color textPrimary, SalesSummary s) {
    return Container(
      decoration: SalesUi.card(isNeu),
      padding: EdgeInsets.all(isNeu ? 18 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top products',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 12),
          if (s.topProducts.isEmpty)
            Text('No completed sales in this period',
                style: TextStyle(fontSize: 12, color: SalesUi.textSec(isNeu))),
          for (var i = 0; i < s.topProducts.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: i == 0 ? AppColors.primary : AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.topProducts[i].productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                        Text('${SalesFormat.quantity(s.topProducts[i].quantity)} sold',
                            style: TextStyle(fontSize: 11, color: SalesUi.textSec(isNeu))),
                      ],
                    ),
                  ),
                  Text(SalesFormat.money(s.topProducts[i].total),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          fontFeatures: SalesUi.tabular)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBar(_PayMethod m, bool isNeu, Color textPrimary) {
    final textSec = isNeu ? AppColors.textSecondaryNeu : const Color(0xFF3A4742);
    return Row(
      children: [
        SizedBox(
          width: isNeu ? 62 : 64,
          child: Text(m.label,
              style: TextStyle(fontSize: 13, color: textSec, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: isNeu ? AppColors.bgNeu : const Color(0xFFEEF2F0),
              borderRadius: BorderRadius.circular(4),
              boxShadow: isNeu
                  ? const [
                      BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 4, offset: Offset(2, 2), spreadRadius: -2),
                      BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 4, offset: Offset(-2, -2), spreadRadius: -2),
                    ]
                  : null,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: m.fraction,
                child: Container(
                  decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: isNeu ? 34 : 36,
          child: Text(m.pct,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  fontFeatures: SalesUi.tabular)),
        ),
      ],
    );
  }

  Widget _buildExportRow(bool isNeu, Color textPrimary) {
    final px = isNeu ? 22.0 : 20.0;
    final bot = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 12, px, bot + 14),
      child: Row(
        children: [
          _exportBtn('PDF', isNeu, textPrimary, false),
          const SizedBox(width: 10),
          _exportBtn('Excel', isNeu, textPrimary, false),
          const SizedBox(width: 10),
          _exportBtn('Print', isNeu, textPrimary, true),
        ],
      ),
    );
  }

  Widget _exportBtn(String label, bool isNeu, Color textPrimary, bool primary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : (isNeu ? AppColors.bgNeu : Colors.white),
          borderRadius: BorderRadius.circular(13),
          border: primary || isNeu ? null : Border.all(color: const Color(0xFFD6DEDA)),
          boxShadow: isNeu
              ? const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(5, 5)),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-5, -5)),
                ]
              : primary
                  ? [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 8))
                    ]
                  : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primary ? Colors.white : textPrimary)),
      ),
    );
  }
}

class _StatCard {
  final String label, value;
  _StatCard(this.label, this.value);
}

class _PayMethod {
  final String label, pct;
  final double fraction;
  final Color color;
  _PayMethod(this.label, this.fraction, this.pct, this.color);
}
