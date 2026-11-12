import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/product_widgets.dart';
import 'add_product_screen.dart';
import 'bulk_upload_screen.dart';
import 'product_detail_screen.dart';

enum _Filter { all, active, inactive, attention, out }

/// Company catalog with branch stock: search, status/stock filters, paging,
/// pull to refresh. Tapping a product opens its detail.
class ProductListScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const ProductListScreen({super.key, required this.themeMode});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const _pageSize = 30;

  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  _Filter _filter = _Filter.all;
  final List<ProductItem> _items = [];
  ProductSummary? _summary;
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  ApiException? _error;
  int _generation = 0;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _canAdd => AuthState.has('PRODUCT_CREATE');
  bool get _canManage => AuthState.has('PRODUCT_MANAGE');

  // The portal's row checkboxes + bulk Activate / Inactivate / Discontinue.
  final Set<String> _selected = {};
  bool _bulkBusy = false;
  bool get _selecting => _selected.isNotEmpty;
  bool get _hasBranch => AuthState.session?.branchId != null;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
    setState(() {});
  }

  void _setFilter(_Filter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _reload();
  }

  ProductStatus? get _statusParam => switch (_filter) {
        _Filter.active => ProductStatus.active,
        _Filter.inactive => ProductStatus.inactive,
        _ => null,
      };

  StockFilter? get _stockParam => switch (_filter) {
        _Filter.attention => StockFilter.attention,
        _Filter.out => StockFilter.out,
        _ => null,
      };

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ProductService.instance.catalog(
          query: _searchCtrl.text,
          status: _statusParam,
          stock: _stockParam,
          size: _pageSize,
        ),
        ProductService.instance.summary(),
      ]);
      if (!mounted || gen != _generation) return;
      final page = results[0] as PageResponse<ProductItem>;
      setState(() {
        _items
          ..clear()
          ..addAll(page.content);
        _total = page.totalElements;
        _summary = results[1] as ProductSummary;
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
      final page = await ProductService.instance.catalog(
        query: _searchCtrl.text,
        status: _statusParam,
        stock: _stockParam,
        page: _page + 1,
        size: _pageSize,
      );
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

  void _toggleSelect(ProductItem p) => setState(() => _selected.contains(p.id) ? _selected.remove(p.id) : _selected.add(p.id));

  Future<void> _bulkStatus(ProductStatus status) async {
    setState(() => _bulkBusy = true);
    try {
      final message = await ProductService.instance.bulkStatus(_selected.toList(), status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _selected.clear();
        _bulkBusy = false;
      });
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _bulkBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openBulkUpload() async {
    final created =
        await Navigator.of(context).push<bool>(slideRight(BulkUploadScreen(themeMode: widget.themeMode)));
    if (created == true) _reload();
  }

  Widget _selectionBar(bool isNeu) {
    final px = SalesUi.gutter(isNeu);
    final allOnPage = _items.isNotEmpty && _items.every((i) => _selected.contains(i.id));
    Widget action(String label, ProductStatus s, Color color) => TextButton(
          onPressed: _bulkBusy ? null : () => _bulkStatus(s),
          style: TextButton.styleFrom(
              foregroundColor: color, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(px, 0, px, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Row(children: [
            IconButton(
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: _bulkBusy ? null : () => setState(_selected.clear),
            ),
            Expanded(
              child: Text('${_selected.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            ),
            TextButton(
              onPressed: _bulkBusy
                  ? null
                  : () => setState(() => allOnPage
                      ? _selected.removeAll(_items.map((i) => i.id))
                      : _selected.addAll(_items.map((i) => i.id))),
              child: Text(allOnPage ? 'Unselect all' : 'Select all'),
            ),
          ]),
          if (_bulkBusy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            action('Activate', ProductStatus.active, AppColors.primaryDark),
            action('Inactivate', ProductStatus.inactive, AppColors.textMuted),
            action('Discontinue', ProductStatus.discontinued, AppColors.error),
          ]),
        ]),
      ),
    );
  }

  Future<void> _openDetail(ProductItem p) async {
    final changed = await Navigator.of(context)
        .push<bool>(slideRight(ProductDetailScreen(themeMode: widget.themeMode, productId: p.id)));
    if (changed == true) _reload();
  }

  Future<void> _openAdd() async {
    final created = await Navigator.of(context)
        .push<ProductDetail>(slideRight(AddProductScreen(themeMode: widget.themeMode)));
    if (created != null) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      floatingActionButton: _canAdd && !_selecting ? _AddFab(isNeu: isNeu, onTap: _openAdd) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(
            title: _summary == null ? 'Products' : 'Products · ${SalesFormat.number(_summary!.total)}',
            isNeu: isNeu,
            // The portal's "Bulk Upload" next to "Add Product" (the FAB).
            actionIcon: _canAdd ? Icons.upload_file_rounded : null,
            onAction: _canAdd ? _openBulkUpload : null,
          ),
          _buildSearch(isNeu),
          _buildFilters(isNeu),
          if (_selecting) _selectionBar(isNeu),
          if (!_selecting && _canManage && _items.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(SalesUi.gutter(isNeu), 0, SalesUi.gutter(isNeu), 4),
              child: Text('Tip: press and hold a product to select several and change their status.',
                  style: TextStyle(fontSize: 11.5, color: SalesUi.textSec(isNeu))),
            ),
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
                    color: active ? AppColors.primary : AppColors.borderDefault,
                    width: active ? 1.5 : 1),
              ),
        child: Row(children: [
          Icon(Icons.search_rounded, color: active ? AppColors.primary : ts, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: SalesUi.text(isNeu)),
              decoration: InputDecoration(
                hintText: 'Search products…',
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
    String withCount(String label, int? n) => n == null || n == 0 ? label : '$label · $n';
    final chips = <(_Filter, String)>[
      (_Filter.all, 'All'),
      (_Filter.active, withCount('Active', s?.active)),
      (_Filter.inactive, withCount('Inactive', s?.inactive)),
      if (_hasBranch) ...[
        (_Filter.attention, withCount('Low stock', s == null ? null : s.lowStock + s.outOfStock)),
        (_Filter.out, withCount('Out of stock', s?.outOfStock)),
      ],
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(SalesUi.gutter(isNeu), 2, 12, 8),
        children: [
          for (final (f, label) in chips)
            SalesChip(label: label, active: _filter == f, isNeu: isNeu, onTap: () => _setFilter(f)),
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
          title: _error!.isForbidden ? 'No access to products' : 'Couldn\'t load products',
          subtitle: _error!.message,
          isNeu: isNeu,
          onRetry: _error!.isForbidden ? null : _reload,
        ),
      );
    }

    final bot = MediaQuery.of(context).padding.bottom;
    final px = SalesUi.gutter(isNeu);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(children: [
              SalesMessage(
                icon: _searchCtrl.text.isNotEmpty || _filter != _Filter.all
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                title: _searchCtrl.text.isNotEmpty || _filter != _Filter.all
                    ? 'No products match'
                    : 'No products yet',
                subtitle: _canAdd && _filter == _Filter.all && _searchCtrl.text.isEmpty
                    ? 'Add your first product to start selling.'
                    : null,
                isNeu: isNeu,
              ),
            ])
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(px, 4, px, bot + (_canAdd ? 92 : 20)),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
                  );
                }
                final item = _items[i];
                return _ProductRow(
                  item: item,
                  isNeu: isNeu,
                  selecting: _selecting,
                  selected: _selected.contains(item.id),
                  onTap: () => _selecting ? _toggleSelect(item) : _openDetail(item),
                  onLongPress: _canManage ? () => _toggleSelect(item) : null,
                );
              },
            ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductItem item;
  final bool isNeu;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ProductRow({
    required this.item,
    required this.isNeu,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final dimmed = item.status != ProductStatus.active;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: SalesUi.card(isNeu, radius: 16).copyWith(
          border: selected ? Border.all(color: AppColors.primary, width: 1.6) : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          if (selecting) ...[
            Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : ts, size: 22),
            const SizedBox(width: 10),
          ],
          Opacity(
            opacity: dimmed ? 0.55 : 1,
            child: ProductThumb(imageUrl: item.imageUrl, category: item.categoryName, isNeu: isNeu),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dimmed ? ts : tp)),
              const SizedBox(height: 2),
              Text(
                [item.categoryName, item.uomCode, item.vatName].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ts),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(SalesFormat.money(item.price),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFeatures: SalesUi.tabular)),
                ProductPill(label: item.status.label, color: ProductUi.statusColor(item.status)),
                StockPill(quantity: item.quantityOnHand, status: item.stockStatus),
              ]),
              if (item.createdAt != null) ...[
                const SizedBox(height: 4),
                Text('Added ${SalesFormat.date(item.createdAt!)}', style: TextStyle(fontSize: 11, color: ts)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          if (!selecting) Icon(Icons.chevron_right_rounded, size: 18, color: ts),
        ]),
      ),
    );
  }
}

class _AddFab extends StatefulWidget {
  final bool isNeu;
  final VoidCallback onTap;
  const _AddFab({required this.isNeu, required this.onTap});

  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bot + 10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? 0.95 : 1.0,
          duration: Duration(milliseconds: _down ? 80 : 220),
          curve: _down ? Curves.easeIn : Curves.easeOutBack,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(widget.isNeu ? 17 : 14),
              boxShadow: widget.isNeu
                  ? const [
                      BoxShadow(color: AppColors.shadowDarkNeu, blurRadius: 12, offset: Offset(5, 5)),
                      BoxShadow(color: AppColors.shadowLightNeu, blurRadius: 12, offset: Offset(-5, -5)),
                    ]
                  : [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.32),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Add product',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}
