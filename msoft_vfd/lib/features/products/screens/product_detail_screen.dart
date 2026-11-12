import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/product_widgets.dart';
import 'add_product_screen.dart';

/// One product: price, stock per branch, 30-day sales, and the actions the
/// user's permissions allow (edit, adjust stock, change status, delete).
/// Pops `true` when anything changed so the list can refresh.
class ProductDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String productId;

  const ProductDetailScreen({super.key, required this.themeMode, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _detail;
  ApiException? _error;
  bool _busy = false;
  bool _changed = false;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  String? get _myBranch => AuthState.session?.branchId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await ProductService.instance.getById(widget.productId);
      if (mounted) setState(() => _detail = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<ProductDetail> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final d = await action();
      if (!mounted) return;
      setState(() {
        _detail = d;
        _busy = false;
        _changed = true;
      });
      _toast(done);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  Future<void> _edit() async {
    final d = _detail;
    if (d == null) return;
    final updated = await Navigator.of(context)
        .push<ProductDetail>(slideRight(AddProductScreen(themeMode: widget.themeMode, edit: d)));
    if (updated != null && mounted) {
      setState(() {
        _detail = updated;
        _changed = true;
      });
    }
  }

  Future<void> _adjust(BranchStock? current) async {
    final d = _detail;
    if (d == null) return;
    final result = await showModalBottomSheet<_Adjustment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdjustSheet(
        isNeu: _isNeu,
        productName: d.product.productName,
        current: current,
      ),
    );
    if (result == null) return;
    await _run(
      () => ProductService.instance.adjustStock(
        d.product.id,
        type: result.type,
        quantity: result.quantity,
        reorderLevel: result.reorderLevel,
        branchId: current?.branchId,
      ),
      'Stock updated',
    );
  }

  Future<void> _delete() async {
    final d = _detail;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '${d.product.productName} will be removed from your catalog'
          '${d.stocks.isNotEmpty ? ', along with its stock at ${d.stocks.length} branch${d.stocks.length == 1 ? '' : 'es'}' : ''}. '
          'Past sales keep their records.\n\nTo stop selling it but keep its history, mark it Discontinued instead.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ProductService.instance.delete(d.product.id);
      if (!mounted) return;
      _toast('Product deleted');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final d = _detail;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: SalesUi.bg(isNeu),
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            SalesHeader(
              title: 'Product',
              isNeu: isNeu,
              actionIcon: d != null && AuthState.has('PRODUCT_UPDATE') ? Icons.edit_outlined : null,
              onAction: _busy ? null : _edit,
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
            Expanded(child: _body(isNeu, d)),
          ]),
        ),
      ),
    );
  }

  Widget _body(bool isNeu, ProductDetail? d) {
    if (d == null) {
      if (_error != null) {
        return Center(
          child: SalesMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load product',
            subtitle: _error!.message,
            isNeu: isNeu,
            onRetry: _load,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px, 6, px, bot + 24),
        children: [
          _hero(isNeu, d),
          const SizedBox(height: 12),
          _actions(isNeu, d),
          if (AuthState.has('PRODUCT_UPLOAD_IMAGE')) ...[
            const SizedBox(height: 14),
            _imageCard(isNeu, d),
          ],
          const SizedBox(height: 14),
          _detailsCard(isNeu, d),
          const SizedBox(height: 14),
          _stockCard(isNeu, d),
          const SizedBox(height: 14),
          _salesCard(isNeu, d),

        ],
      ),
    );
  }

  Widget _card(bool isNeu, {String? title, Widget? trailing, required List<Widget> children}) {
    return Container(
      decoration: SalesUi.card(isNeu),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 10),
        ],
        ...children,
      ]),
    );
  }

  Widget _hero(bool isNeu, ProductDetail d) {
    final p = d.product;
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    return _card(isNeu, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ProductThumb(imageUrl: p.imageUrl, category: p.categoryName, isNeu: isNeu, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.productName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 3),
            Text([p.categoryName, p.uomName ?? p.uomCode].whereType<String>().join(' · '),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: ts)),
            const SizedBox(height: 8),
            ProductPill(label: p.status.label, color: ProductUi.statusColor(p.status)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(SalesFormat.money(p.price),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary, fontFeatures: SalesUi.tabular)),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(p.uomCode != null ? 'per ${p.uomCode}' : '',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts)),
        ),
        const Spacer(),
        if (p.vatCode != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(d.vatPercent != null ? 'VAT ${d.vatPercent}% incl.' : p.vatCode!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts)),
          ),
      ]),
    ]);
  }

  Widget _stockCard(bool isNeu, ProductDetail d) {
    final ts = SalesUi.textSec(isNeu);
    final canAdjust = AuthState.has('STOCK_MANAGE');
    final mine = d.stockAt(_myBranch);
    final stocks = [...d.stocks]..sort((a, b) {
        if (a.branchId == _myBranch) return -1;
        if (b.branchId == _myBranch) return 1;
        return a.branchName.compareTo(b.branchName);
      });

    return _card(
      isNeu,
      title: 'Stock',
      trailing: d.stocks.length > 1
          ? Text('${SalesFormat.number(d.totalOnHand)} total',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ts))
          : null,
      children: [
        if (!d.stockTrackingEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: const Text(
                'Stock tracking is off for your company, so sales don\'t reduce these counts.',
                style: TextStyle(fontSize: 12, color: AppColors.warningText, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (stocks.isEmpty)
          Text('Not tracked at any branch yet. Sales of this product won\'t check stock.',
              style: TextStyle(fontSize: 13, color: ts))
        else
          for (final s in stocks) _stockRow(isNeu, s, highlight: s.branchId == _myBranch),
        if (canAdjust && _myBranch != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _adjust(mine),
              icon: Icon(mine == null ? Icons.add_chart_rounded : Icons.tune_rounded, size: 18),
              label: Text(mine == null ? 'Start tracking at my branch' : 'Adjust stock at my branch'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _stockRow(bool isNeu, BranchStock s, {required bool highlight}) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final canAdjust = AuthState.has('STOCK_MANAGE');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: canAdjust && !_busy ? () => _adjust(s) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(highlight ? '${s.branchName} (my branch)' : s.branchName,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tp)),
              const SizedBox(height: 2),
              Text(
                'Reorder at ${s.reorderLevel}'
                '${s.lastRestock != null ? ' · restocked ${SalesFormat.shortDate(s.lastRestock!)}' : ''}',
                style: TextStyle(fontSize: 11.5, color: ts),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(SalesFormat.number(s.quantityOnHand),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ProductUi.stockColor(s.status),
                    fontFeatures: SalesUi.tabular)),
            ProductPill(label: s.status.label, color: ProductUi.stockColor(s.status)),
          ]),
        ]),
      ),
    );
  }

  Widget _salesCard(bool isNeu, ProductDetail d) {
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    Widget stat(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tp, fontFeatures: SalesUi.tabular)),
          ]),
        );
    return _card(isNeu, title: 'Last 30 days', children: [
      Row(children: [
        stat('Units sold', SalesFormat.quantity(d.soldQuantity30d)),
        stat('Revenue', SalesFormat.compactMoney(d.revenue30d)),
      ]),
    ]);
  }

  /// The portal's "Product Information" section, same fields and order.
  Widget _detailsCard(bool isNeu, ProductDetail d) {
    final p = d.product;
    String stamp(DateTime? t) => t == null ? '—' : '${SalesFormat.date(t)} ${SalesFormat.time(t)}';
    final rows = <(String, String)>[
      ('Product Name', p.productName),
      ('Category', p.categoryName ?? '—'),
      ('Price', SalesFormat.money(p.price)),
      ('Unit of Measure', p.uomName ?? p.uomCode ?? '—'),
      ('VAT', p.vatName ?? '—'),
      ('Status', p.status.label),
      ('Description', (p.description ?? '').trim().isEmpty ? '—' : p.description!.trim()),
      ('Created At', stamp(p.createdAt)),
      ('Updated At', stamp(p.updatedAt)),
    ];
    final ts = SalesUi.textSec(isNeu);
    final tp = SalesUi.text(isNeu);
    return _card(isNeu, title: 'Product Information', children: [
      for (final (k, v) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 118, child: Text(k, style: TextStyle(fontSize: 13, color: ts))),
            Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp, height: 1.35)),
            ),
          ]),
        ),
    ]);
  }

  /// The portal's "Product Image" card: Upload / Replace Image (uploads at once) and Remove.
  Widget _imageCard(bool isNeu, ProductDetail d) {
    final url = d.product.imageUrl;
    final ts = SalesUi.textSec(isNeu);
    return _card(isNeu, title: 'Product Image', children: [
      Row(children: [
        Container(
          width: 96,
          height: 96,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isNeu ? const Color(0xFFEEF2F0) : const Color(0xFFF4F6F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: url == null
              ? Icon(Icons.image_outlined, color: ts, size: 34)
              : Image.network(url,
                  fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: ts)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _uploadImage,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(_busy ? 'Uploading…' : (url == null ? 'Upload Image' : 'Replace Image')),
            ),
            if (url != null)
              TextButton.icon(
                onPressed: _busy ? null : _removeImage,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove'),
              ),
            Text('JPEG, PNG or WebP, up to 5 MB', style: TextStyle(fontSize: 11.5, color: ts)),
          ]),
        ),
      ]),
    ]);
  }

  Future<void> _uploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: SalesUi.bg(_isNeu),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (source == null) return;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    } on PlatformException catch (e) {
      _toast('Couldn\'t open the image: ${e.message ?? e.code}');
      return;
    }
    if (file == null || !mounted) return;
    if (await file.length() > 5 * 1024 * 1024) {
      _toast('That image is larger than 5 MB. Choose a smaller one.');
      return;
    }
    await _run(() => ProductService.instance.uploadImage(_detail!.product.id, file!.path),
        'Product image uploaded successfully.');
  }

  Future<void> _removeImage() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this product\'s image?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ProductService.instance.deleteImage(_detail!.product.id), 'Product image removed.');
  }

  /// The portal's header buttons: Activate / Inactivate / Discontinue (the ones that
  /// aren't the current status), Edit and Delete.
  Widget _actions(bool isNeu, ProductDetail d) {
    final canStatus = AuthState.has('PRODUCT_MANAGE');
    final canEdit = AuthState.has('PRODUCT_UPDATE');
    final canDelete = AuthState.has('PRODUCT_DELETE');
    final current = d.product.status;
    Widget btn(IconData icon, String label, VoidCallback onTap, {Color? color}) => OutlinedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color ?? SalesUi.text(isNeu),
            side: color == null ? null : BorderSide(color: color.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
    final buttons = <Widget>[
      if (canStatus && current != ProductStatus.active)
        btn(Icons.check_circle_outline_rounded, 'Activate', () => _setStatus(ProductStatus.active),
            color: AppColors.primaryDark),
      if (canStatus && current != ProductStatus.inactive)
        btn(Icons.pause_circle_outline_rounded, 'Inactivate', () => _setStatus(ProductStatus.inactive)),
      if (canStatus && current != ProductStatus.discontinued)
        btn(Icons.block_rounded, 'Discontinue', () => _setStatus(ProductStatus.discontinued)),
      if (canEdit) btn(Icons.edit_outlined, 'Edit', _edit),
      if (canDelete) btn(Icons.delete_outline_rounded, 'Delete', _delete, color: AppColors.error),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Future<void> _setStatus(ProductStatus status) =>
      _run(() => ProductService.instance.setStatus(_detail!.product.id, status), 'Product status updated successfully.');

}

class _Adjustment {
  final StockAdjustment type;
  final int quantity;
  final int? reorderLevel;
  const _Adjustment(this.type, this.quantity, this.reorderLevel);
}

/// Bottom sheet for receiving, removing or counting stock at one branch.
class _AdjustSheet extends StatefulWidget {
  final bool isNeu;
  final String productName;
  final BranchStock? current;

  const _AdjustSheet({required this.isNeu, required this.productName, this.current});

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late StockAdjustment _type = widget.current == null ? StockAdjustment.set : StockAdjustment.add;
  final _qty = TextEditingController();
  late final _reorder = TextEditingController(text: widget.current?.reorderLevel.toString() ?? '0');

  @override
  void dispose() {
    _qty.dispose();
    _reorder.dispose();
    super.dispose();
  }

  int get _before => widget.current?.quantityOnHand ?? 0;
  int? get _q => int.tryParse(_qty.text.trim());

  int? get _after {
    final q = _q;
    if (q == null) return null;
    return switch (_type) {
      StockAdjustment.add => _before + q,
      StockAdjustment.remove => _before - q,
      StockAdjustment.set => q,
    };
  }

  String? get _problem {
    final q = _q;
    if (q == null) return null;
    if (_type != StockAdjustment.set && q <= 0) return 'Enter more than 0';
    if (_type == StockAdjustment.remove && q > _before) return 'Only $_before in stock';
    return null;
  }

  void _submit() {
    final q = _q;
    if (q == null || _problem != null) return;
    final r = int.tryParse(_reorder.text.trim());
    final reorder = r != null && r != widget.current?.reorderLevel ? r : null;
    Navigator.pop(context, _Adjustment(_type, q, reorder));
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = widget.isNeu;
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final types = widget.current == null
        ? const [StockAdjustment.set, StockAdjustment.add]
        : StockAdjustment.values;
    final after = _after;
    final problem = _problem;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isNeu ? AppColors.bgNeu : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, inset + MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AppColors.borderDefault, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text(widget.current == null ? 'Start tracking stock' : 'Adjust stock',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
        const SizedBox(height: 2),
        Text(
          '${widget.productName} · ${widget.current?.branchName ?? 'my branch'} · $_before on hand',
          style: TextStyle(fontSize: 12.5, color: ts),
        ),
        const SizedBox(height: 14),
        Row(children: [
          for (final t in types)
            SalesChip(
              label: t.label,
              active: _type == t,
              isNeu: isNeu,
              onTap: () => setState(() => _type = t),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _qty,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: _type.hint,
            errorText: problem,
            border: const OutlineInputBorder(),
            suffixText: after != null && problem == null ? '→ $after' : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reorder,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Reorder level',
            helperText: 'Marked low stock at or below this count',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _q != null && problem == null ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}
