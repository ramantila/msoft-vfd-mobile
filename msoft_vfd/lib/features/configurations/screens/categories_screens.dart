import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../products/screens/product_detail_screen.dart';
import '../../products/widgets/product_widgets.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/config_models.dart';
import '../services/config_service.dart';
import 'config_widgets.dart';

/// Categories list, like the portal's Categories page: your own plus shared
/// defaults (marked "Default"), status, and how many products use each.
class CategoryListScreen extends StatelessWidget {
  final AppThemeMode themeMode;
  const CategoryListScreen({super.key, required this.themeMode});

  bool get _isNeu => themeMode == AppThemeMode.neumorphic;

  @override
  Widget build(BuildContext context) {
    return ConfigListPage<CategoryItem>(
      themeMode: themeMode,
      title: 'Categories',
      searchHint: 'Search categories…',
      emptyTitle: 'No categories found',
      emptyIcon: Icons.category_outlined,
      canAdd: AuthState.has('CATEGORY_CREATE'),
      load: (q) => ConfigService.instance.categories(query: q),
      isActive: (c) => c.active,
      onAdd: (ctx) async =>
          await Navigator.of(ctx).push<CategoryDetail>(slideRight(CategoryFormScreen(themeMode: themeMode))) != null,
      rowBuilder: (ctx, c, reload) => ConfigRow(
        isNeu: _isNeu,
        leading: ProductThumb(category: c.categoryName, isNeu: _isNeu, size: 42),
        title: c.categoryName,
        subtitle: c.description,
        systemDefault: c.systemDefault,
        active: c.active,
        productCount: c.productCount,
        onTap: () async {
          final changed = await Navigator.of(ctx)
              .push<bool>(slideRight(CategoryDetailScreen(themeMode: themeMode, categoryId: c.id)));
          if (changed == true) reload();
        },
      ),
    );
  }
}

/// Category view: Activate / Deactivate (per company for shared defaults),
/// Edit and Delete for your own, info, and the products using it.
class CategoryDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String categoryId;
  const CategoryDetailScreen({super.key, required this.themeMode, required this.categoryId});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  CategoryDetail? _d;
  ApiException? _error;
  bool _busy = false;
  bool _changed = false;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await ConfigService.instance.category(widget.categoryId);
      if (mounted) setState(() => _d = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggle() async {
    final c = _d!.category;
    setState(() => _busy = true);
    try {
      final d = await ConfigService.instance.setCategoryActive(c.id, !c.active);
      if (!mounted) return;
      setState(() {
        _d = d;
        _busy = false;
        _changed = true;
      });
      _toast('${c.categoryName} ${d.category.active ? 'activated' : 'deactivated'}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context)
        .push<CategoryDetail>(slideRight(CategoryFormScreen(themeMode: widget.themeMode, edit: _d!.category)));
    if (updated != null && mounted) {
      setState(() {
        _d = updated;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final d = _d!;
    if (!await confirmConfigDelete(context, what: 'category', blocker: d.deleteBlocker)) return;
    setState(() => _busy = true);
    try {
      await ConfigService.instance.deleteCategory(d.category.id);
      if (!mounted) return;
      _toast('Category deleted successfully.');
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
    final d = _d;
    Widget body;
    if (d == null) {
      body = _error != null
          ? Center(
              child: SalesMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Failed to load category',
                  subtitle: _error!.message,
                  isNeu: isNeu,
                  onRetry: _load))
          : const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else {
      final c = d.category;
      final canToggle = AuthState.has('CATEGORY_UPDATE');
      body = ConfigDetailBody(
        isNeu: isNeu,
        leading: ProductThumb(category: c.categoryName, isNeu: isNeu, size: 56),
        title: c.categoryName,
        systemDefault: c.systemDefault,
        active: c.active,
        note: c.systemDefault ? 'Shared default category, available to every company. You can switch it off for your company.' : null,
        info: [
          ('Description', c.description ?? '—'),
          ('Status', c.active ? 'Active' : 'Inactive'),
          if (c.createdAt != null) ('Created', SalesFormat.date(c.createdAt!)),
          if (c.updatedAt != null) ('Updated', SalesFormat.date(c.updatedAt!)),
        ],
        products: d.products,
        productCount: c.productCount,
        onProduct: AuthState.has('PRODUCT_VIEW')
            ? (p) => Navigator.of(context)
                .push(slideRight(ProductDetailScreen(themeMode: widget.themeMode, productId: p.id)))
            : null,
        busy: _busy,
        onToggle: canToggle ? _toggle : null,
        toggleHint: canToggle && c.systemDefault
            ? 'Only changes this default for your own company. Every other company keeps seeing it.'
            : null,
        onEdit: d.canEdit ? _edit : null,
        onDelete: !c.systemDefault && AuthState.has('CATEGORY_DELETE') ? _delete : null,
        onRefresh: _load,
      );
    }
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
            SalesHeader(title: d?.category.categoryName ?? 'Category', isNeu: isNeu),
            if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
            Expanded(child: body),
          ]),
        ),
      ),
    );
  }
}

/// Add / edit a category: name (required) and description, as on the portal.
class CategoryFormScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final CategoryItem? edit;
  const CategoryFormScreen({super.key, required this.themeMode, this.edit});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.edit?.categoryName ?? '');
  late final _description = TextEditingController(text: widget.edit?.description ?? '');
  bool _saving = false;
  Map<String, String> _errors = const {};

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _errors = const {});
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final d = await ConfigService.instance.saveCategory(
        id: widget.edit?.id,
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.edit == null ? 'Category created successfully!' : 'Category updated successfully!')));
      Navigator.of(context).pop(d);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.fieldErrors ?? const {};
      });
      if (!e.isValidation) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return ConfigFormPage(
      isNeu: isNeu,
      title: widget.edit == null ? 'Add Category' : 'Edit Category',
      section: 'Category Information',
      formKey: _formKey,
      saving: _saving,
      submitLabel: widget.edit == null ? 'Create' : 'Save changes',
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _name,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          decoration: configInput(isNeu, 'Category Name *', error: _errors['categoryName']),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a category name' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _description,
          enabled: !_saving,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: configInput(isNeu, 'Description',
              error: _errors['description'], hint: 'Enter category description (optional)'),
        ),
      ],
    );
  }
}
