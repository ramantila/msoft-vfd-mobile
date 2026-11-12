import 'sale.dart';

enum SummaryGranularity { hour, day, month }

/// GET /api/v1/mobile/sales/summary — mirrors CSP's MobileSalesSummaryResponse.
/// Money totals cover COMPLETED sales only.
class SalesSummary {
  final DateTime from;
  final DateTime to;
  final int saleCount;
  final double grossTotal;
  final double taxTotal;
  final double discountTotal;
  final double netTotal;
  final double averageSale;
  final double previousPeriodTotal;

  /// % change vs the same-length period before [from]; null when that
  /// period had no sales (nothing to compare against).
  final double? changePercent;
  final int pendingCount;
  final int cancelledCount;
  final int refundedCount;
  final SummaryGranularity granularity;
  final List<TrendPoint> trend;
  final List<PaymentShare> byPaymentMethod;
  final List<TopProduct> topProducts;

  const SalesSummary({
    required this.from,
    required this.to,
    required this.saleCount,
    required this.grossTotal,
    required this.taxTotal,
    required this.discountTotal,
    required this.netTotal,
    required this.averageSale,
    required this.previousPeriodTotal,
    this.changePercent,
    required this.pendingCount,
    required this.cancelledCount,
    required this.refundedCount,
    required this.granularity,
    required this.trend,
    required this.byPaymentMethod,
    required this.topProducts,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
        grossTotal: _d(json['grossTotal']),
        taxTotal: _d(json['taxTotal']),
        discountTotal: _d(json['discountTotal']),
        netTotal: _d(json['netTotal']),
        averageSale: _d(json['averageSale']),
        previousPeriodTotal: _d(json['previousPeriodTotal']),
        changePercent: (json['changePercent'] as num?)?.toDouble(),
        pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
        cancelledCount: (json['cancelledCount'] as num?)?.toInt() ?? 0,
        refundedCount: (json['refundedCount'] as num?)?.toInt() ?? 0,
        granularity: switch ((json['granularity'] as String?)?.toUpperCase()) {
          'HOUR' => SummaryGranularity.hour,
          'MONTH' => SummaryGranularity.month,
          _ => SummaryGranularity.day,
        },
        trend: _list(json['trend'], TrendPoint.fromJson),
        byPaymentMethod: _list(json['byPaymentMethod'], PaymentShare.fromJson),
        topProducts: _list(json['topProducts'], TopProduct.fromJson),
      );
}

class TrendPoint {
  /// Bucket start, in the server's local time (no zone on the wire).
  final DateTime start;
  final int saleCount;
  final double total;

  const TrendPoint({required this.start, required this.saleCount, required this.total});

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        start: DateTime.parse(json['start'] as String),
        saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
        total: _d(json['total']),
      );
}

class PaymentShare {
  final PaymentMethod paymentMethod;
  final int saleCount;
  final double total;

  /// Share of the period's gross total, 0–100.
  final double share;

  const PaymentShare({
    required this.paymentMethod,
    required this.saleCount,
    required this.total,
    required this.share,
  });

  factory PaymentShare.fromJson(Map<String, dynamic> json) => PaymentShare(
        paymentMethod: PaymentMethodX.parse(json['paymentMethod'] as String?),
        saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
        total: _d(json['total']),
        share: _d(json['share']),
      );
}

class TopProduct {
  final String? productId;
  final String productName;
  final double quantity;
  final double total;

  const TopProduct({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.total,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        productId: json['productId']?.toString(),
        productName: json['productName'] as String? ?? '',
        quantity: _d(json['quantity']),
        total: _d(json['total']),
      );
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) =>
    (raw as List<dynamic>? ?? const [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
