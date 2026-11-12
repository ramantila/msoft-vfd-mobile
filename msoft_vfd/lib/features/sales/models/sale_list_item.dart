import 'sale.dart';

/// One row of GET /api/v1/mobile/sales — mirrors CSP's MobileSaleListItem.
/// Has no line items; load the full [Sale] by [id] for the detail screen.
class SaleListItem {
  final String id;
  final String? receiptNo;
  final String? fiscalCode;
  final DateTime? saleDate;
  final SaleStatus status;
  final PaymentMethod paymentMethod;
  final String currency;
  final double grandTotal;
  final int itemCount;
  final String? branchId;
  final String? branchName;
  final String? username;
  final String? customerName;

  const SaleListItem({
    required this.id,
    this.receiptNo,
    this.fiscalCode,
    this.saleDate,
    required this.status,
    required this.paymentMethod,
    required this.currency,
    required this.grandTotal,
    required this.itemCount,
    this.branchId,
    this.branchName,
    this.username,
    this.customerName,
  });

  /// "Sale #638", falling back to a short id for a sale without a receipt no.
  String get title => receiptNo != null && receiptNo!.isNotEmpty
      ? 'Sale #$receiptNo'
      : 'Sale ${id.substring(0, id.length < 8 ? id.length : 8)}';

  factory SaleListItem.fromJson(Map<String, dynamic> json) => SaleListItem(
        id: json['id'].toString(),
        receiptNo: json['receiptNo'] as String?,
        fiscalCode: json['fiscalCode'] as String?,
        saleDate: json['saleDate'] != null ? DateTime.tryParse(json['saleDate'] as String) : null,
        status: SaleStatusX.parse(json['status'] as String?),
        paymentMethod: PaymentMethodX.parse(json['paymentMethod'] as String?),
        currency: json['currency'] as String? ?? 'TZS',
        grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        branchId: json['branchId']?.toString(),
        branchName: json['branchName'] as String?,
        username: json['username'] as String?,
        customerName: json['customerName'] as String?,
      );
}
