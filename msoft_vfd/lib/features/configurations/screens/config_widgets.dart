import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../../users/screens/staff_widgets.dart';
import '../models/config_models.dart';

/// "Default" badge for shared system defaults, as on the portal.
class DefaultBadge extends StatelessWidget {
  const DefaultBadge({super.key});
  @override
  Widget build(BuildContext context) => const StaffPill(label: 'Default', color: AppColors.blue);
}

class ActivePill extends StatelessWidget {
  final bool active;
  const ActivePill({super.key, required this.active});
  @override
  Widget build(BuildContext context) =>
      StaffPill(label: active ? 'Active' : 'Inactive', color: active ? AppColors.primaryDark : AppColors.textMuted);
}

/// One row of the categories / units list.
class ConfigRow extends StatelessWidget {
  final bool isNeu;
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool systemDefault;
  final bool active;
  final int productCount;
  final VoidCallback onTap;

  const ConfigRow({
    super.key,
    required this.isNeu,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.systemDefault,
    required this.active,
    required this.productCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: SalesUi.card(isNeu, radius: 16),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Opacity(opacity: active ? 1 : 0.5, child: leading),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? tp : ts)),
                ),
                if (systemDefault) ...[const SizedBox(width: 6), const DefaultBadge()],
              ]),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: ts)),
              ],
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                ActivePill(active: active),
                StaffPill(
                    label: '$productCount product${productCount == 1 ? '' : 's'}',
                    color: productCount == 0 ? AppColors.textMuted : AppColors.primaryDark),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: ts),
        ]),
      ),
    );
  }
}

/// List page shared by Categories and Units: header with Add, search,
/// All / Active / Inactive chips, pull to refresh, empty and error states.
class ConfigListPage<T> extends StatefulWidget {
  final AppThemeMode themeMode;
  final String title;
  final String searchHint;
  final String emptyTitle;
  final IconData emptyIcon;
  final bool canAdd;
  final Future<List<T>> Function(String query) load;
  final bool Function(T item) isActive;
  final Widget Function(BuildContext context, T item, VoidCallback reload) rowBuilder;
  final Future<bool> Function(BuildContext context) onAdd;

  const ConfigListPage({
    super.key,
    required this.themeMode,
    required this.title,
    required this.searchHint,
    required this.emptyTitle,
    required this.emptyIcon,
    required this.canAdd,
    required this.load,
    required this.isActive,
    required this.rowBuilder,
    required this.onAdd,
  });

  @override
  State<ConfigListPage<T>> createState() => _ConfigListPageState<T>();
}

class _ConfigListPageState<T> extends State<ConfigListPage<T>> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<T> _items = [];
  bool? _active;
  bool _loading = true;
  ApiException? _error;
  int _gen = 0;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final g = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.load(_searchCtrl.text);
      if (!mounted || g != _gen) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    if (await widget.onAdd(context)) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final px = SalesUi.gutter(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final shown = _active == null ? _items : _items.where((i) => widget.isActive(i) == _active).toList();
    final activeCount = _items.where(widget.isActive).length;
    String c(String l, int n) => n == 0 ? l : '$l · $n';

    Widget body;
    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else if (_error != null && _items.isEmpty) {
      body = Center(
        child: SalesMessage(
          icon: _error!.isForbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          title: _error!.isForbidden ? 'No access' : 'Couldn\'t load ${widget.title.toLowerCase()}',
          subtitle: _error!.message,
          isNeu: isNeu,
          onRetry: _error!.isForbidden ? null : _reload,
        ),
      );
    } else {
      final bot = MediaQuery.of(context).padding.bottom;
      body = RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _reload,
        child: shown.isEmpty
            ? ListView(children: [SalesMessage(icon: widget.emptyIcon, title: widget.emptyTitle, isNeu: isNeu)])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(px, 4, px, bot + 20),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => widget.rowBuilder(ctx, shown[i], _reload),
              ),
      );
    }

    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(
            title: widget.title,
            isNeu: isNeu,
            actionIcon: widget.canAdd ? Icons.add_rounded : null,
            onAction: widget.canAdd ? _add : null,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(px, 0, px, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), _reload);
              },
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: TextStyle(color: ts),
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: isNeu ? AppColors.bgNeu : Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDefault)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderDefault)),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.fromLTRB(px, 2, 12, 8), children: [
              SalesChip(label: c('All', _items.length), active: _active == null, isNeu: isNeu,
                  onTap: () => setState(() => _active = null)),
              SalesChip(label: c('Active', activeCount), active: _active == true, isNeu: isNeu,
                  onTap: () => setState(() => _active = true)),
              SalesChip(label: c('Inactive', _items.length - activeCount), active: _active == false, isNeu: isNeu,
                  onTap: () => setState(() => _active = false)),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

/// Detail body shared by Category and Unit views: title block with badges,
/// action buttons (Activate/Deactivate, Edit, Delete), info rows, products.
class ConfigDetailBody extends StatelessWidget {
  final bool isNeu;
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool systemDefault;
  final bool active;
  final String? note;
  final List<(String, String)> info;
  final List<ProductRef> products;
  final int productCount;
  final void Function(ProductRef p)? onProduct;
  final bool busy;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? toggleHint;
  final Future<void> Function() onRefresh;

  const ConfigDetailBody({
    super.key,
    required this.isNeu,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.systemDefault,
    required this.active,
    this.note,
    required this.info,
    required this.products,
    required this.productCount,
    this.onProduct,
    required this.busy,
    this.onToggle,
    this.onEdit,
    this.onDelete,
    this.toggleHint,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    Widget card(String? heading, List<Widget> children) => Container(
          decoration: SalesUi.card(isNeu),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (heading != null) ...[
              Text(heading, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tp)),
              const SizedBox(height: 10),
            ],
            ...children,
          ]),
        );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px, 6, px, bot + 24),
        children: [
          card(null, [
            Row(children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tp)),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12.5, color: ts)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    if (systemDefault) const DefaultBadge(),
                    ActivePill(active: active),
                  ]),
                ]),
              ),
            ]),
            if (note != null) ...[
              const SizedBox(height: 10),
              Text(note!, style: TextStyle(fontSize: 12, color: ts, height: 1.35)),
            ],
            if (onToggle != null || onEdit != null || onDelete != null) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (onToggle != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onToggle,
                    icon: Icon(active ? Icons.toggle_off_outlined : Icons.toggle_on_outlined, size: 18),
                    label: Text(active ? 'Deactivate' : 'Activate'),
                  ),
                if (onEdit != null)
                  OutlinedButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit')),
                if (onDelete != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onDelete,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                  ),
              ]),
              if (toggleHint != null) ...[
                const SizedBox(height: 6),
                Text(toggleHint!, style: TextStyle(fontSize: 11.5, color: ts)),
              ],
            ],
          ]),
          const SizedBox(height: 14),
          card('Information', [
            for (final (k, v) in info)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 100, child: Text(k, style: TextStyle(fontSize: 13, color: ts))),
                  Expanded(
                    child: Text(v,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tp)),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: 14),
          card('Products using it · $productCount', [
            if (products.isEmpty)
              Text('No products use this yet.', style: TextStyle(fontSize: 13, color: ts))
            else ...[
              for (final p in products)
                InkWell(
                  onTap: onProduct == null ? null : () => onProduct!(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(Icons.inventory_2_outlined, size: 16, color: ts),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(p.productName,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: tp))),
                      if (onProduct != null) Icon(Icons.chevron_right_rounded, size: 18, color: ts),
                    ]),
                  ),
                ),
              if (productCount > products.length)
                Text('and ${productCount - products.length} more', style: TextStyle(fontSize: 12, color: ts)),
            ],
          ]),
        ],
      ),
    );
  }
}

/// Explains why a delete isn't possible, or confirms it.
Future<bool> confirmConfigDelete(BuildContext context, {required String what, String? blocker}) async {
  if (blocker != null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Can\'t delete $what'),
        content: Text(blocker, style: const TextStyle(fontSize: 13)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    return false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete this $what?'),
          content: const Text('This can\'t be undone.', style: TextStyle(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Simple form page (title, card of fields, Create / Save button).
class ConfigFormPage extends StatelessWidget {
  final bool isNeu;
  final String title;
  final String section;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final bool saving;
  final String submitLabel;
  final VoidCallback onSubmit;

  const ConfigFormPage({
    super.key,
    required this.isNeu,
    required this.title,
    required this.section,
    required this.formKey,
    required this.fields,
    required this.saving,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final px = SalesUi.gutter(isNeu);
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        child: Column(children: [
          SalesHeader(title: title, isNeu: isNeu),
          if (saving) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(
            child: Form(
              key: formKey,
              child: ListView(padding: EdgeInsets.fromLTRB(px, 6, px, 24), children: [
                Container(
                  decoration: SalesUi.card(isNeu),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(section,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
                    const SizedBox(height: 12),
                    ...fields,
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
                  ),
                  child: Text(saving ? 'Saving…' : submitLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

InputDecoration configInput(bool isNeu, String label, {String? error, String? helper, String? hint}) =>
    staffInput(isNeu, label, error: error, helper: helper).copyWith(hintText: hint);
