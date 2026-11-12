import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/screens/add_product_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../models/sale.dart';
import 'sales_report_screen.dart';

class SaleReceiptScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final Sale sale;
  const SaleReceiptScreen({
    super.key,
    required this.themeMode,
    required this.sale,
  });

  @override
  State<SaleReceiptScreen> createState() => _SaleReceiptScreenState();
}

class _SaleReceiptScreenState extends State<SaleReceiptScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Icon bounces in first
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;

  // Amount + receipt card reveal slightly after
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  // ── Receipt data, derived from the submitted sale ─────────────────────────
  Sale get _sale => widget.sale;
  String get _receiptNo => _sale.receiptNo ?? '—';
  String get _date => _sale.receiptDate != null
      ? _formatDate(_sale.receiptDate!)
      : (_sale.saleDate != null ? _formatDate(_sale.saleDate!) : '—');
  String get _time =>
      _sale.saleDate != null ? _formatTime(_sale.saleDate!) : '—';
  String get _cashier => _sale.username ?? '';
  String get _receiptZNo => _sale.receiptZNo ?? '—';
  String get _gc => _sale.fiscalCode ?? '——————';

  List<SaleItem> get _items => _sale.items;

  double get _subtotal => _sale.subtotal;
  double get _discount => _sale.discountAmount;
  double get _net => _subtotal - _discount;
  double get _vat => _sale.taxTotal;
  double get _total => _sale.grandTotal;

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _formatTime(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950));

    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _iconScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.58, curve: Curves.elasticOut)));

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.28, 0.82, curve: Curves.easeOut)));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(parent: _ctrl,
                curve: const Interval(0.28, 0.95, curve: Curves.easeOut)));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  String _fmt(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return 'TSh ${buf.toString()}';
  }

  String _fmtQty(double qty) =>
      qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isNeu = widget.themeMode == AppThemeMode.neumorphic;
    final bg  = isNeu ? AppColors.bgNeu : AppColors.bgDefault;
    final tp  = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts  = isNeu ? AppColors.textSecondaryNeu : const Color(0xFF8A988F);
    final px  = isNeu ? 22.0 : 20.0;
    final bot = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildHeader(context, isNeu, tp, px),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(px, 8, px, 16),
              child: Column(children: [
                // ── Success banner ─────────────────────────────────────────
                _buildSuccessBanner(isNeu, tp, ts),
                const SizedBox(height: 20),

                // ── Receipt card + hint (slide up together) ────────────────
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(children: [
                      _buildReceiptCard(isNeu, tp, ts),
                      const SizedBox(height: 14),
                      _buildVerifyHint(ts),
                      const SizedBox(height: 4),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          _buildActions(context, isNeu, tp, px, bot),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext ctx, bool isNeu, Color tp, double px) {
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 12, px, 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: _iconBox(Icons.arrow_back_ios_new, isNeu, tp, 14),
        ),
        const SizedBox(width: 12),
        Text('VFD Receipt',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: tp)),
        const Spacer(),
        _iconBox(Icons.share_outlined, isNeu, tp, 18),
      ]),
    );
  }

  Widget _iconBox(IconData icon, bool isNeu, Color color, double size) {
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
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  // ── Success banner ────────────────────────────────────────────────────────

  Widget _buildSuccessBanner(bool isNeu, Color tp, Color ts) {
    return Column(children: [
      // Animated check circle
      FadeTransition(
        opacity: _iconFade,
        child: ScaleTransition(
          scale: _iconScale,
          child: Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: isNeu ? AppColors.bgNeu : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: isNeu
                  ? const [
                      BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 15, offset: Offset(6, 6)),
                      BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 15, offset: Offset(-6, -6)),
                    ]
                  : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Icon(Icons.check_rounded, size: 32,
                color: isNeu ? AppColors.primary : Colors.white),
          ),
        ),
      ),
      const SizedBox(height: 13),

      // "Receipt issued" text fades in with content
      FadeTransition(
        opacity: _contentFade,
        child: Column(children: [
          Text('Receipt issued',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ts)),
          const SizedBox(height: 4),
          Text(_fmt(_total),
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                  color: isNeu ? AppColors.primary : tp,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    ]);
  }

  // ── Receipt card ──────────────────────────────────────────────────────────

  Widget _buildReceiptCard(bool isNeu, Color tp, Color ts) {
    final divClr = isNeu ? const Color(0xFFCDD6D1) : const Color(0xFFE8EDEA);

    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
      _pad(_companySection(tp, ts)),
      _dash(divClr),
      _pad(_metaSection(tp, ts)),
      _dash(divClr),
      _pad(_itemsSection(tp, ts, divClr)),
      _dash(divClr),
      _pad(_totalsSection(tp, ts, divClr, isNeu)),
      _dash(divClr),
      _pad(_paymentSection(tp, ts)),
      _dash(divClr),
      _pad(_customerSection(tp, ts)),
      _dash(divClr),
      _pad(_vatSection(tp, ts, divClr)),
      _dash(divClr),
      _pad(_controlSection(isNeu, tp, ts)),
      _fiscalFooter(isNeu, ts),
    ]);

    if (isNeu) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.bgNeu,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 14, offset: Offset(7, 7)),
            BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 14, offset: Offset(-7, -7)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: content,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDefault),
      ),
      clipBehavior: Clip.hardEdge,
      child: content,
    );
  }

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: child);

  Widget _dash(Color color) =>
      CustomPaint(size: const Size(double.infinity, 1),
          painter: _DashPainter(color));

  // ── Company section ───────────────────────────────────────────────────────

  Widget _companySection(Color tp, Color ts) {
    return Column(children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF10A56F), Color(0xFF067A53)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Container(width: 18, height: 18,
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(6))),
        ),
      ),
      const SizedBox(height: 10),
      Text((_sale.companyName ?? '').toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
              color: tp, letterSpacing: 0.5)),
      if (_sale.branchName?.isNotEmpty == true) ...[
        const SizedBox(height: 3),
        Text(_sale.branchName!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ts)),
      ],
    ]);
  }

  // ── Receipt metadata ──────────────────────────────────────────────────────

  Widget _metaSection(Color tp, Color ts) {
    return Column(children: [
      Row(children: [
        _metaCell('Receipt #', '#$_receiptNo', tp, ts, false),
        const Spacer(),
        _metaCell('Date', _date, tp, ts, true),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _metaCell('Time', _time, tp, ts, false),
        const Spacer(),
        _metaCell('Cashier', _cashier, tp, ts, true),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Text('Receipt Z', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
        const Spacer(),
        Flexible(
          child: Text(_receiptZNo, textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tp)),
        ),
      ]),
    ]);
  }

  Widget _metaCell(String label, String value, Color tp, Color ts, bool right) =>
      Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp)),
          ]);

  // ── Items section ─────────────────────────────────────────────────────────

  Widget _itemsSection(Color tp, Color ts, Color divClr) {
    return Column(children: [
      // Column headers
      Row(children: [
        Expanded(flex: 3, child: _colHdr('ITEM', ts, TextAlign.left)),
        SizedBox(width: 36, child: _colHdr('QTY', ts, TextAlign.center)),
        const SizedBox(width: 6),
        SizedBox(width: 78, child: _colHdr('AMOUNT', ts, TextAlign.right)),
      ]),
      const SizedBox(height: 7),
      Container(height: 1, color: divClr),
      const SizedBox(height: 10),

      // Item rows
      ..._items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3,
                child: Text(item.productName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tp))),
            SizedBox(width: 36,
                child: Text(_fmtQty(item.quantity),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontFeatures: [FontFeature.tabularFigures()]))),
            const SizedBox(width: 6),
            SizedBox(width: 78,
                child: Text(_fmt(item.lineTotal),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp,
                        fontFeatures: const [FontFeature.tabularFigures()]))),
          ]),
          const SizedBox(height: 1),
          Text('@ ${_fmt(item.unitPrice)} each',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ts)),
        ]),
      )),
    ]);
  }

  Widget _colHdr(String t, Color ts, TextAlign align) => Text(t,
      textAlign: align,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: ts, letterSpacing: 0.5));

  // ── Totals section ────────────────────────────────────────────────────────

  Widget _totalsSection(Color tp, Color ts, Color divClr, bool isNeu) {
    final thickDiv = isNeu
        ? const Color(0xFFC5CEC9)
        : const Color(0xFFD6DED9);

    return Column(children: [
      _totRow('Subtotal',            _fmt(_subtotal), ts, tp, false),
      if (_discount > 0) ...[
        const SizedBox(height: 6),
        _totRow('Discount',    '− ${_fmt(_discount)}', ts, AppColors.error, false),
      ],
      const SizedBox(height: 8),
      Container(height: 1, color: divClr),
      const SizedBox(height: 8),
      _totRow('Net amount',          _fmt(_net),      ts, tp, false),
      const SizedBox(height: 5),
      _totRow('VAT (18%)',           _fmt(_vat),      ts, ts, false),
      const SizedBox(height: 9),
      Container(height: 1.5, color: thickDiv),
      const SizedBox(height: 9),
      _totRow('TOTAL PAID',          _fmt(_total),    tp, tp, true),
    ]);
  }

  Widget _totRow(String label, String value,
      Color labelColor, Color valueColor, bool big) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TextStyle(
              fontSize: big ? 15 : 13,
              fontWeight: big ? FontWeight.w800 : FontWeight.w500,
              color: labelColor)),
      Text(value,
          style: TextStyle(
              fontSize: big ? 18 : 13,
              fontWeight: big ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()])),
    ]);
  }

  // ── Payment section ───────────────────────────────────────────────────────

  Widget _paymentSection(Color tp, Color ts) {
    return Column(children: [
      _payRow(Icons.payments_outlined, 'Payment method', _sale.paymentMethod.label, tp, ts),
      const SizedBox(height: 10),
      _payRow(Icons.account_balance_wallet_outlined, 'Amount paid', _fmt(_total), tp, ts),
    ]);
  }

  Widget _payRow(IconData icon, String label, String value,
      Color valueColor, Color ts) {
    return Row(children: [
      Icon(icon, size: 15, color: ts),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ts)),
      const Spacer(),
      Text(value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()])),
    ]);
  }

  // ── Customer section ──────────────────────────────────────────────────────

  Widget _customerSection(Color tp, Color ts) {
    final customerName = _sale.customerName;
    final isWalkIn = customerName == null || customerName.trim().isEmpty;
    return Row(children: [
      Icon(Icons.person_outline_rounded, size: 15, color: ts),
      const SizedBox(width: 8),
      Text('Customer',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ts)),
      const Spacer(),
      Flexible(
        child: Text(
          isWalkIn ? 'Walk-in' : customerName,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isWalkIn ? ts : tp),
        ),
      ),
    ]);
  }

  // ── VAT summary table ─────────────────────────────────────────────────────

  Widget _vatSection(Color tp, Color ts, Color divClr) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('VAT SUMMARY',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: ts, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(width: 38, child: Text('Rate', style: _tblHdrStyle(ts))),
        Expanded(child: Text('Net',   textAlign: TextAlign.right, style: _tblHdrStyle(ts))),
        Expanded(child: Text('VAT',   textAlign: TextAlign.right, style: _tblHdrStyle(ts))),
        Expanded(child: Text('Gross', textAlign: TextAlign.right, style: _tblHdrStyle(ts))),
      ]),
      const SizedBox(height: 5),
      Container(height: 1, color: divClr),
      const SizedBox(height: 7),
      Row(children: [
        SizedBox(width: 38,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
              child: const Text('A 18%', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.white)),
            )),
        Expanded(child: Text(_fmt(_net),
            textAlign: TextAlign.right,
            style: _tblValStyle(tp))),
        Expanded(child: Text(_fmt(_vat),
            textAlign: TextAlign.right,
            style: _tblValStyle(tp))),
        Expanded(child: Text(_fmt(_total),
            textAlign: TextAlign.right,
            style: _tblValStyle(tp).copyWith(fontWeight: FontWeight.w800))),
      ]),
    ]);
  }

  TextStyle _tblHdrStyle(Color ts) =>
      TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ts);

  TextStyle _tblValStyle(Color tp) =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tp,
          fontFeatures: const [FontFeature.tabularFigures()]);

  // ── Control code + QR ────────────────────────────────────────────────────

  Widget _controlSection(bool isNeu, Color tp, Color ts) {
    return Column(children: [
      Text('CONTROL CODE (GC)',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: ts, letterSpacing: 0.5)),
      const SizedBox(height: 10),

      // GC characters
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isNeu ? AppColors.bgNeu : const Color(0xFFF4F7F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isNeu ? const Color(0xFFD5DDD8) : const Color(0xFFE4EAE7)),
          boxShadow: isNeu
              ? const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 6,
                      offset: Offset(3, 3), spreadRadius: -2),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 6,
                      offset: Offset(-3, -3), spreadRadius: -2),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _gc.split('').map((c) =>
              Text(c, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                  color: tp, letterSpacing: 2,
                  fontFeatures: const [FontFeature.tabularFigures()]))).toList(),
        ),
      ),

      const SizedBox(height: 16),

      // QR placeholder
      Container(
        width: 106, height: 106,
        decoration: BoxDecoration(
          color: isNeu ? AppColors.bgNeu : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isNeu ? const Color(0xFFCDD6D1) : const Color(0xFFD6DED9),
              width: 1.5),
        ),
        child: Icon(Icons.qr_code_2_rounded, size: 90,
            color: isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary),
      ),

      const SizedBox(height: 7),
      Text('Scan to verify receipt at TRA portal',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ts)),
    ]);
  }

  // ── Fiscal footer ─────────────────────────────────────────────────────────

  Widget _fiscalFooter(bool isNeu, Color ts) {
    return Container(
      color: isNeu
          ? AppColors.shadowDarkNeu.withValues(alpha: 0.15)
          : const Color(0xFFF5F8F6),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_outlined, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          const Text('Issued by MSOFT Virtual Fiscal Device',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 3),
        Text('www.tra.go.tz  ·  TRA Dar es Salaam',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: ts)),
      ]),
    );
  }

  // ── Verify hint ───────────────────────────────────────────────────────────

  Widget _buildVerifyHint(Color ts) {
    return Text(
      'Keep this receipt as proof of purchase.\n'
      'Verify at tra.go.tz using the control code above.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: ts, height: 1.55),
    );
  }

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

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext ctx, bool isNeu, Color tp,
      double px, double bot) {
    return Container(
      color: isNeu ? AppColors.bgNeu : AppColors.bgDefault,
      padding: EdgeInsets.fromLTRB(px, 10, px, bot + 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: _btn(Icons.print_outlined,    'Print', false, isNeu, tp, () {})),
          const SizedBox(width: 10),
          Expanded(child: _btn(Icons.ios_share_rounded, 'Share', false, isNeu, tp, () {})),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _btn(Icons.add_box_outlined, 'Add product', false, isNeu, tp, () {
              Navigator.of(ctx).push(
                _slideRight(AddProductScreen(themeMode: widget.themeMode)),
              );
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _btn(Icons.bar_chart_rounded, 'Reports', false, isNeu, tp, () {
              Navigator.of(ctx).push(
                _slideRight(SalesReportScreen(themeMode: widget.themeMode)),
              );
            }),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _btn(Icons.add_rounded, 'New sale', true, isNeu, tp, () {
            Navigator.of(ctx).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (_, _, _) =>
                    DashboardScreen(themeMode: widget.themeMode),
                transitionDuration: const Duration(milliseconds: 320),
                reverseTransitionDuration: Duration.zero,
                transitionsBuilder: (_, anim, _, child) {
                  final slide = Tween<Offset>(
                    begin: const Offset(-1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic));
                  final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                        parent: anim,
                        curve: const Interval(0.0, 0.38, curve: Curves.easeOut)),
                  );
                  return FadeTransition(
                      opacity: fade,
                      child: SlideTransition(position: slide, child: child));
                },
              ),
              (route) => false,
            );
          }),
        ),
      ]),
    );
  }

  Widget _btn(IconData icon, String label, bool primary,
      bool isNeu, Color tp, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : (isNeu ? AppColors.bgNeu : Colors.white),
          borderRadius: BorderRadius.circular(isNeu ? 15 : 13),
          border: primary || isNeu ? null : Border.all(color: AppColors.borderDefault),
          boxShadow: isNeu
              ? const [
                  BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 10, offset: Offset(5, 5)),
                  BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 10, offset: Offset(-5, -5)),
                ]
              : primary
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 16, offset: const Offset(0, 7))]
                  : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: primary ? Colors.white : tp),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: primary ? Colors.white : tp)),
        ]),
      ),
    );
  }
}

// ── Dashed line painter ───────────────────────────────────────────────────────

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), paint);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}