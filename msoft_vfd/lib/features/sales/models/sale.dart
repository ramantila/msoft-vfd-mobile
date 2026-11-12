enum PaymentMethod { cash, card, cheque, mobileMoney, invoice }

extension PaymentMethodX on PaymentMethod {
  static PaymentMethod parse(String? value) {
    final normalized = value?.replaceAll('_', '').toUpperCase();
    return PaymentMethod.values.firstWhere(
      (m) => m.name.toUpperCase() == normalized,
      orElse: () => PaymentMethod.cash,
    );
  }

  String get cspName => switch (this) {
        PaymentMethod.cash => 'CASH',
        PaymentMethod.card => 'CARD',
        PaymentMethod.cheque => 'CHEQUE',
        PaymentMethod.mobileMoney => 'MOBILE_MONEY',
        PaymentMethod.invoice => 'INVOICE',
      };

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.cheque => 'Cheque',
        PaymentMethod.mobileMoney => 'M-Pesa',
        PaymentMethod.invoice => 'Invoice',
      };
}

enum SaleStatus { pending, completed, cancelled, refunded }

extension SaleStatusX on SaleStatus {
  static SaleStatus parse(String? value) => SaleStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == value?.toUpperCase(),
        orElse: () => SaleStatus.pending,
      );

  String get cspName => name.toUpperCase();

  String get label => switch (this) {
        SaleStatus.pending => 'Pending',
        SaleStatus.completed => 'Completed',
        SaleStatus.cancelled => 'Cancelled',
        SaleStatus.refunded => 'Refunded',
      };
}

/// Mirrors CSP's SaleItemResponse.
class SaleItem {
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final String? taxCategory;
  final double taxAmount;
  final double lineTotal;

  const SaleItem({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    this.taxCategory,
    required this.taxAmount,
    required this.lineTotal,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productId: json['productId']?.toString(),
        productName: json['productName'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        taxCategory: json['taxCategory'] as String?,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      );
}

/// Mirrors CSP's SaleResponse.
class Sale {
  final String id;
  final String companyId;
  final String? companyName;
  final String branchId;
  final String? branchName;
  final String userId;
  final String? username;
  final String? customerId;
  final String? customerName;
  final DateTime? saleDate;
  final PaymentMethod paymentMethod;
  final String currency;
  final double discountAmount;
  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final SaleStatus status;
  final String? fiscalCode;
  final String? receiptNo;
  final String? receiptZNo;
  final DateTime? receiptDate;
  final String? qrCode;
  final String? notes;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.companyId,
    this.companyName,
    required this.branchId,
    this.branchName,
    required this.userId,
    this.username,
    this.customerId,
    this.customerName,
    this.saleDate,
    required this.paymentMethod,
    required this.currency,
    required this.discountAmount,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.status,
    this.fiscalCode,
    this.receiptNo,
    this.receiptZNo,
    this.receiptDate,
    this.qrCode,
    this.notes,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'].toString(),
        companyId: json['companyId'].toString(),
        companyName: json['companyName'] as String?,
        branchId: json['branchId'].toString(),
        branchName: json['branchName'] as String?,
        userId: json['userId'].toString(),
        username: json['username'] as String?,
        customerId: json['customerId']?.toString(),
        customerName: json['customerName'] as String?,
        saleDate: json['saleDate'] != null ? DateTime.tryParse(json['saleDate'] as String) : null,
        paymentMethod: PaymentMethodX.parse(json['paymentMethod'] as String?),
        currency: json['currency'] as String? ?? 'TZS',
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        taxTotal: (json['taxTotal'] as num?)?.toDouble() ?? 0,
        grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
        status: SaleStatusX.parse(json['status'] as String?),
        fiscalCode: json['fiscalCode'] as String?,
        receiptNo: json['receiptNo'] as String?,
        receiptZNo: json['receiptZNo'] as String?,
        receiptDate:
            json['receiptDate'] != null ? DateTime.tryParse(json['receiptDate'] as String) : null,
        qrCode: json['qrCode'] as String?,
        notes: json['notes'] as String?,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Request payload for creating a sale line item — mirrors CSP's
/// SaleItemRequest. `unitPrice` is sent explicitly (rather than relying on
/// the backend's product-price fallback) so the total matches exactly what
/// the cashier saw in the cart.
class SaleItemInput {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  const SaleItemInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

/// Request payload for POST /api/v1/mobile/sales/checkout — mirrors CSP's
/// MobileCheckoutRequest. The cashier is the signed-in user (taken from the
/// token server-side) and the branch defaults to the cashier's own branch,
/// so neither has to be sent. The sale is created and completed in one
/// server-side transaction.
class CheckoutInput {
  final String? branchId;
  final String? customerId;
  final PaymentMethod paymentMethod;
  final String currency;
  final String? notes;
  final List<SaleItemInput> items;

  const CheckoutInput({
    this.branchId,
    this.customerId,
    required this.paymentMethod,
    this.currency = 'TZS',
    this.notes,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        if (branchId != null) 'branchId': branchId,
        if (customerId != null) 'customerId': customerId,
        'paymentMethod': paymentMethod.cspName,
        'currency': currency,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'items': items.map((i) => i.toJson()).toList(),
      };
}
