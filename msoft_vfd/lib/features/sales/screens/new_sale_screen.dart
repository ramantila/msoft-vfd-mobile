import 'package:flutter/material.dart';
import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../products/models/product.dart';
import '../../customers/models/customer.dart';
import '../../customers/screens/customer_list_screen.dart';
import '../../products/screens/add_product_screen.dart';
import '../../products/services/product_service.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';
import 'sale_receipt_screen.dart';
import 'sales_report_screen.dart';

const _paymentOptions = <String, PaymentMethod>{
  'Cash': PaymentMethod.cash,
  'M-Pesa': PaymentMethod.mobileMoney,
  'Card': PaymentMethod.card,
  // No direct backend equivalent for bank transfer — settled like an
  // invoice (paid separately from the point of sale), which is the closest
  // match among CSP's PaymentMethod values.
  'Transfer': PaymentMethod.invoice,
};

class NewSaleScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const NewSaleScreen({super.key, required this.themeMode});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  late AppThemeMode _theme;
  String _payment = 'Cash';
  CustomerItem? _customer; // null = walk-in
  final _searchCtrl = TextEditingController();
  String _search = '';
  final List<_CartItem> _items = [];

  bool _loading = true;
  ApiException? _error;
  List<Product> _catalog = [];
  bool _submitting = false;

  static const _accentBg = [
    Color(0xFFDFF5EB), Color(0xFFDEEFFE), Color(0xFFFFF3E0), Color(0xFFF3E8FF),
  ];
  static const _accentFg = [
    AppColors.primary, Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF9333EA),
  ];

  @override
  void initState() {
    super.initState();
    _theme = widget.themeMode;
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products =
          await ProductService.instance.listByCompany(AuthState.session!.companyId);
      products.removeWhere((p) => p.status != ProductStatus.active);
      products.sort((a, b) => a.productName.compareTo(b.productName));
      if (!mounted) return;
      setState(() {
        _catalog = products;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeSale() async {
    if (_items.isEmpty || _submitting) return;

    setState(() => _submitting = true);

    // The cashier comes from the token and the branch defaults to the
    // cashier's own branch server-side; CSP answers 422 with a readable
    // message when the user has no branch, shown in the snackbar below.
    final input = CheckoutInput(
      branchId: AuthState.session?.branchId,
      customerId: _customer?.id,
      paymentMethod: _paymentOptions[_payment] ?? PaymentMethod.cash,
      items: _items
          .map((e) => SaleItemInput(
                productId: e.productId,
                productName: e.name,
                quantity: e.qty.toDouble(),
                unitPrice: e.price,
              ))
          .toList(),
    );

    try {
      // Create + complete in one server-side transaction, so a failure
      // (e.g. insufficient stock) never leaves a half-finished PENDING sale.
      final completed = await SaleService.instance.checkout(input);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _customer = null;
        _submitting = false;
      });
      Navigator.of(context)
          .push(_slideRight(SaleReceiptScreen(themeMode: _theme, sale: completed)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  int _colorIdx(Product p) => (p.categoryName ?? p.productName).hashCode.abs() % 4;

  List<Product> get _filtered => _search.isEmpty
      ? _catalog
      : _catalog
          .where((p) => p.productName.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  static PageRoute<T> _slideRight<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, anim, _, child) {
          final slide = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: anim,
                curve: const Interval(0.0, 0.38, curve: Curves.easeOut)),
          );
          return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child));
        },
      );

  int _qty(String productId) {
    final i = _items.indexWhere((e) => e.productId == productId);
    return i < 0 ? 0 : _items[i].qty;
  }

  void _add(Product p) => setState(() {
        final i = _items.indexWhere((e) => e.productId == p.id);
        if (i >= 0) {
          _items[i].qty++;
        } else {
          _items.add(_CartItem(p.id, p.productName, p.price, 1));
        }
      });

  void _sub(Product p) => setState(() {
        final i = _items.indexWhere((e) => e.productId == p.id);
        if (i < 0) return;
        if (_items[i].qty > 1) {
          _items[i].qty--;
        } else {
          _items.removeAt(i);
        }
      });

  Product _fromCart(_CartItem item) => _catalog.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          companyId: '',
          productName: item.name,
          price: item.price,
          status: ProductStatus.active,
        ),
      );

  int get _cartCount => _items.fold(0, (s, e) => s + e.qty);
  int get _subtotal => _items.fold(0, (s, e) => s + (e.price * e.qty).round());
  int get _vat => (_subtotal * 0.18).round();
  int get _total => _subtotal + _vat;

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return 'TSh ${buf.toString()}';
  }

  String _fmtN(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final bg = isNeu ? AppColors.bgNeu : AppColors.bgDefault;
    final tp = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isNeu, tp),
            _buildSearch(isNeu),
            Expanded(child: _buildProductList(isNeu, tp)),
            _buildCartPanel(isNeu, tp),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isNeu, Color tp) {
    final px = isNeu ? 22.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 12, px, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: _iconBox(Icons.arrow_back_ios_new, isNeu, tp, size: 14),
        ),
        const SizedBox(width: 14),
        Text('New sale',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tp)),
        if (_items.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
            child: Text('$_cartCount',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context)
              .push(_slideRight(AddProductScreen(themeMode: _theme)))
              .then((_) { if (mounted) _loadProducts(); }),
          child: _iconBox(Icons.add_box_outlined, isNeu, tp, size: 19),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.of(context)
              .push(_slideRight(SalesReportScreen(themeMode: _theme))),
          child: _iconBox(Icons.bar_chart_rounded, isNeu, tp, size: 19),
        ),
        const SizedBox(width: 8),
        _iconBox(Icons.qr_code_scanner_rounded, isNeu, AppColors.primary, size: 19),
      ]),
    );
  }

  Widget _iconBox(IconData icon, bool isNeu, Color color, {double size = 16}) {
    if (isNeu) {
      return Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 9, offset: Offset(4, 4)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 9, offset: Offset(-4, -4)),
          ],
        ),
        child: Icon(icon, color: color, size: size),
      );
    }
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  // ── Search ───────────────────────────────────────────────────────────────────

  Widget _buildSearch(bool isNeu) {
    final px = isNeu ? 22.0 : 20.0;
    final tp = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final clearBtn = _search.isNotEmpty
        ? GestureDetector(
            onTap: () => _searchCtrl.clear(),
            child: Icon(Icons.close_rounded, color: ts, size: 16))
        : null;
    final field = TextField(
      controller: _searchCtrl,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tp),
      decoration: InputDecoration(
        hintText: 'Search products…',
        hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ts),
        border: InputBorder.none, isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
      ),
    );

    if (isNeu) {
      return Padding(
        padding: EdgeInsets.fromLTRB(px, 0, px, 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgNeu,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(5, 5)),
              BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-5, -5)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Icon(Icons.search_rounded, color: ts, size: 19),
            const SizedBox(width: 10),
            Expanded(child: field),
            ?clearBtn,
          ]),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(px, 0, px, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _search.isNotEmpty ? AppColors.primary : AppColors.borderDefault,
            width: _search.isNotEmpty ? 1.5 : 1,
          ),
          boxShadow: _search.isNotEmpty
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 0, spreadRadius: 3)]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          Icon(Icons.search_rounded,
              color: _search.isNotEmpty ? AppColors.primary : ts, size: 19),
          const SizedBox(width: 10),
          Expanded(child: field),
          ?clearBtn,
        ]),
      ),
    );
  }

  // ── Product list ─────────────────────────────────────────────────────────────

  Widget _buildProductList(bool isNeu, Color tp) {
    final px = isNeu ? 22.0 : 20.0;
    final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, size: 40, color: ts),
          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: px),
            child: Text(_error!.message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ts)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _loadProducts,
            child: const Text('Retry',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ]),
      );
    }

    final prods = _filtered;
    if (prods.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, size: 40, color: ts),
          const SizedBox(height: 10),
          Text(_catalog.isEmpty ? 'No products in your catalog yet' : 'No products found',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ts)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(_slideRight(AddProductScreen(themeMode: _theme)))
              .then((_) { if (mounted) _loadProducts(); }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: isNeu ? AppColors.bgNeu : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isNeu ? null : Border.all(color: AppColors.borderDefault),
                boxShadow: isNeu
                    ? const [
                        BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 8, offset: Offset(4, 4)),
                        BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 8, offset: Offset(-4, -4)),
                      ]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text('Add product',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ]),
            ),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(px, 4, px, 8),
        itemCount: prods.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildProductRow(prods[i], isNeu, tp),
      ),
    );
  }

  Widget _buildProductRow(Product p, bool isNeu, Color tp) {
    final qty = _qty(p.id);
    final inCart = qty > 0;
    final colorIdx = _colorIdx(p);
    final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;

    final content = Row(children: [
      // Thumbnail
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: isNeu ? AppColors.bgNeu : _accentBg[colorIdx],
          borderRadius: BorderRadius.circular(13),
          boxShadow: isNeu
              ? const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 6, offset: Offset(3, 3), spreadRadius: -2),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 6, offset: Offset(-3, -3), spreadRadius: -2),
                ]
              : null,
        ),
        child: inCart
            ? Center(
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: isNeu ? AppColors.primary : _accentFg[colorIdx],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 11),
                ))
            : Center(
                child: Icon(Icons.inventory_2_outlined,
                    size: 19,
                    color: isNeu
                        ? AppColors.textSecondaryNeu
                        : _accentFg[colorIdx].withValues(alpha: 0.45))),
      ),
      const SizedBox(width: 13),
      // Name + price
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.productName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
          const SizedBox(height: 2),
          Text('TSh ${_fmtN(p.price.round())}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: inCart ? AppColors.primary : ts,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
      const SizedBox(width: 10),
      // Add button or inline stepper
      inCart
          ? Row(children: [
              _qtyBtn(Icons.remove, () => _sub(p), isNeu, false, 32),
              SizedBox(
                width: 32,
                child: Text('$qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tp)),
              ),
              _qtyBtn(Icons.add, () => _add(p), isNeu, true, 32),
            ])
          : GestureDetector(
              onTap: () => _add(p),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: isNeu
                      ? const [
                          BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 6, offset: Offset(3, 3)),
                          BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 6, offset: Offset(-3, -3)),
                        ]
                      : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 17),
              ),
            ),
    ]);

    if (isNeu) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(5, 5)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-5, -5)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: content,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: inCart ? AppColors.primary : AppColors.borderDefault,
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: inCart
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.09), blurRadius: 0, spreadRadius: 3)]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: content,
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback fn, bool isNeu, bool primary, double size) {
    if (isNeu) {
      return GestureDetector(
        onTap: fn,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: primary ? AppColors.primary : AppColors.bgNeu,
            borderRadius: BorderRadius.circular(size / 3),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 5, offset: Offset(2, 2)),
              BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 5, offset: Offset(-2, -2)),
            ],
          ),
          child: Icon(icon, size: 12, color: primary ? Colors.white : AppColors.textPrimaryNeu),
        ),
      );
    }
    return GestureDetector(
      onTap: fn,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : const Color(0xFFF0F3F1),
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(icon, size: 12, color: primary ? Colors.white : AppColors.textPrimary),
      ),
    );
  }

  // ── Cart panel ───────────────────────────────────────────────────────────────

  Widget _buildCartPanel(bool isNeu, Color tp) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final divColor = isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFF0F3F1);
    final panelBg = isNeu ? AppColors.bgNeu : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: isNeu
            ? const [
                BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 14, offset: Offset(0, -5)),
                BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 12, offset: Offset(0, 8)),
              ]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(children: [
              const Icon(Icons.shopping_cart_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Selected items',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tp)),
              if (_items.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('$_cartCount',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
              const Spacer(),
              if (_items.isNotEmpty)
                Text(_fmt(_total),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),

          Container(height: 1, color: divColor),

          // Empty state
          if (_items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
              child: Row(children: [
                Icon(Icons.touch_app_outlined, size: 18, color: ts),
                const SizedBox(width: 10),
                Text('Tap a product above to add it here',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ts)),
              ]),
            ),

          // Cart items
          if (_items.isNotEmpty) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.27,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _items.length,
                separatorBuilder: (_, _) => Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: divColor),
                itemBuilder: (_, i) => _buildCartRow(_items[i], isNeu, tp, ts),
              ),
            ),

            Container(height: 1, color: divColor),

            // Customer
            _buildCustomerRow(isNeu, tp, ts),

            Container(height: 1, color: divColor),

            // Payment
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                Text('Pay via',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts)),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Cash', 'M-Pesa', 'Card', 'Transfer'].map((m) {
                        final active = m == _payment;
                        return GestureDetector(
                          onTap: () => setState(() => _payment = m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : (isNeu ? AppColors.bgNeu : const Color(0xFFF0F3F1)),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: isNeu && !active
                                  ? const [
                                      BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 4, offset: Offset(2, 2)),
                                      BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 4, offset: Offset(-2, -2)),
                                    ]
                                  : null,
                            ),
                            child: Text(m,
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: active ? Colors.white : ts)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Complete button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 14),
              child: GestureDetector(
                onTap: _submitting ? null : _completeSale,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(isNeu ? 17 : 14),
                    boxShadow: isNeu
                        ? const [
                            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 11, offset: Offset(5, 5)),
                            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 11, offset: Offset(-5, -5)),
                          ]
                        : [
                            BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.32),
                                blurRadius: 18, offset: const Offset(0, 7)),
                          ],
                  ),
                  child: _submitting
                      ? const Center(
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ),
                        )
                      : Row(children: [
                    const Text('Complete sale',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(_fmt(_total),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final choice = await Navigator.of(context).push<CustomerChoice>(slideRight(CustomerListScreen(
      themeMode: _theme,
      pickMode: true,
      selectedId: _customer?.id,
    )));
    if (choice != null && mounted) setState(() => _customer = choice.customer);
  }

  Widget _buildCustomerRow(bool isNeu, Color tp, Color ts) {
    final c = _customer;
    final canPick = AuthState.has('CUSTOMER_VIEW');
    return GestureDetector(
      onTap: canPick ? _pickCustomer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Icon(Icons.person_outline_rounded, size: 15, color: ts),
          const SizedBox(width: 8),
          Text('Customer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ts)),
          const Spacer(),
          Flexible(
            child: Text(
              c == null ? 'Walk-in' : c.customerName,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c == null ? ts : tp),
            ),
          ),
          if (c != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _customer = null),
              child: Icon(Icons.close_rounded, size: 15, color: ts),
            ),
          ] else if (canPick) ...[
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
          ],
        ]),
      ),
    );
  }

  Widget _buildCartRow(_CartItem item, bool isNeu, Color tp, Color ts) {
    final p = _fromCart(item);
    final colorIdx = _colorIdx(p);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        // Thumbnail
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isNeu ? AppColors.bgNeu : _accentBg[colorIdx],
            borderRadius: BorderRadius.circular(11),
            boxShadow: isNeu
                ? const [
                    BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 5, offset: Offset(3, 3), spreadRadius: -2),
                    BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 5, offset: Offset(-3, -3), spreadRadius: -2),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(Icons.check_rounded, size: 14,
                color: isNeu ? AppColors.primary : _accentFg[colorIdx]),
          ),
        ),
        const SizedBox(width: 12),
        // Name + unit price
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp)),
            Text('TSh ${_fmtN(item.price.round())} / unit',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ts,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
        const SizedBox(width: 10),
        // Qty stepper
        Row(children: [
          _qtyBtn(Icons.remove, () => _sub(p), isNeu, false, 28),
          SizedBox(
            width: 28,
            child: Text('${item.qty}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tp)),
          ),
          _qtyBtn(Icons.add, () => _add(p), isNeu, true, 28),
        ]),
        const SizedBox(width: 10),
        // Line total
        SizedBox(
          width: 76,
          child: Text(_fmt((item.price * item.qty).round()),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tp,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}

class _CartItem {
  final String productId;
  final String name;
  final double price;
  int qty;
  _CartItem(this.productId, this.name, this.price, this.qty);
}