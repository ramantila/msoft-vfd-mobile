import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/product.dart';
import '../services/product_service.dart';

/// Add / edit a product, following the web portal's product-create page:
///
/// * **Product Image** (with PRODUCT_UPLOAD_IMAGE): choose, change or clear;
///   uploaded right after the product is saved.
/// * **Product Information**: Product Name *, Category *, Price *, Unit of
///   Measure *, Tax Type (your company's tax configuration, 18% preselected),
///   Status, Description.
///
/// Names and prices are cleaned as you type, exactly like the portal. The
/// optional opening stock section is the app's own extra (the portal does
/// stock from its separate Stocks page). Pops the saved [ProductDetail].
class AddProductScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final ProductDetail? edit;

  const AddProductScreen({super.key, required this.themeMode, this.edit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _ProductNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final clean = sanitizeProductName(newValue.text);
    if (clean == newValue.text) return newValue;
    final caret = (newValue.selection.end - (newValue.text.length - clean.length)).clamp(0, clean.length);
    return TextEditingValue(text: clean, selection: TextSelection.collapsed(offset: caret));
  }
}

/// Portal's sanitizePrice: digits, one decimal point, at most two decimals.
String sanitizePrice(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^\d.]'), ''); // commas (thousands) dropped
  final dot = cleaned.indexOf('.');
  if (dot == -1) return cleaned;
  final whole = cleaned.substring(0, dot);
  var decimals = cleaned.substring(dot + 1).replaceAll('.', '');
  if (decimals.length > 2) decimals = decimals.substring(0, 2);
  return '${whole.isEmpty ? '0' : whole}.$decimals';
}

/// Portal's sanitizeProductName: letters and digits in any script plus single
/// spaces; leading spaces dropped while typing.
String sanitizeProductName(String value) => value
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
    .replaceAll(RegExp(r' +'), ' ')
    .replaceFirst(RegExp(r'^ +'), '');

class _PriceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final clean = sanitizePrice(newValue.text);
    if (clean == newValue.text) return newValue;
    return TextEditingValue(text: clean, selection: TextSelection.collapsed(offset: clean.length));
  }
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const _maxImageBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _openingStock = TextEditingController();
  final _reorder = TextEditingController(text: '5');

  ProductFormOptions? _options;
  ApiException? _loadError;
  bool _saving = false;
  bool _submitted = false;
  Map<String, String> _fieldErrors = const {};

  FormOption? _category;
  FormOption? _unit;
  FormOption? _vat;
  ProductStatus _status = ProductStatus.active;
  bool _trackStock = false;

  XFile? _pickedImage;
  bool _removeImage = false;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _editing => widget.edit != null;
  bool get _canUploadImage => AuthState.has('PRODUCT_UPLOAD_IMAGE');
  String? get _existingImageUrl => _removeImage ? null : widget.edit?.product.imageUrl;

  BranchStock? get _myStock => widget.edit?.stockAt(_options?.defaultBranchId);
  bool get _showOpeningStock =>
      !_editing && AuthState.has('STOCK_CREATE') && _options?.defaultBranchId != null;
  bool get _showReorderOnEdit => _editing && _myStock != null && AuthState.has('STOCK_MANAGE');

  @override
  void initState() {
    super.initState();
    final p = widget.edit?.product;
    if (p != null) {
      _name.text = p.productName;
      _price.text = p.price == p.price.roundToDouble() ? p.price.toStringAsFixed(0) : p.price.toStringAsFixed(2);
      _description.text = p.description ?? '';
      _status = p.status;
    }
    _loadOptions();
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _description, _openingStock, _reorder]) {
      c.dispose();
    }
    super.dispose();
  }

  FormOption? _find(List<FormOption> list, String? id) {
    if (id == null) return null;
    for (final o in list) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> _loadOptions() async {
    setState(() => _loadError = null);
    try {
      final o = await ProductService.instance.formOptions();
      if (!mounted) return;
      final p = widget.edit?.product;
      setState(() {
        _options = o;
        if (p != null) {
          _category = _find(o.categories, p.categoryId) ??
              (p.categoryId != null ? FormOption(id: p.categoryId!, label: p.categoryName ?? 'Category') : null);
          _unit = _find(o.units, p.uomId) ??
              (p.uomId != null ? FormOption(id: p.uomId!, label: p.uomCode ?? 'Unit', detail: p.uomName) : null);
          _vat = _find(o.taxTypes, p.vatId) ??
              (p.vatId != null ? FormOption(id: p.vatId!, label: p.vatName ?? p.vatCode ?? 'Tax') : null);
          final mine = widget.edit!.stockAt(o.defaultBranchId);
          if (mine != null) _reorder.text = mine.reorderLevel.toString();
        } else {
          _vat = _find(o.taxTypes, o.defaultTaxId); // 18% preselected, as on the portal
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  // ---- image ----

  Future<void> _chooseImage() async {
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
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (file == null || !mounted) return;
      final lower = file.path.toLowerCase();
      final okType = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
      if (!okType) {
        _toast('Choose a JPEG, PNG or WebP image.');
        return;
      }
      if (await file.length() > _maxImageBytes) {
        _toast('That image is larger than 5 MB. Choose a smaller one.');
        return;
      }
      setState(() {
        _pickedImage = file;
        _removeImage = false;
      });
    } on PlatformException catch (e) {
      _toast(e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
          ? 'Allow photo access in your phone\'s settings to add a product image.'
          : 'Couldn\'t open the image: ${e.message ?? e.code}');
    }
  }

  void _clearImage() => setState(() {
        _pickedImage = null;
        if (widget.edit?.product.imageUrl != null) _removeImage = true;
      });

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ---- save ----

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _fieldErrors = const {};
      _submitted = true;
    });
    final valid = _formKey.currentState?.validate() ?? false;
    if (_category == null) {
      _toast('Please select a category');
      return;
    }
    if (_unit == null) {
      _toast('Please select a unit of measure');
      return;
    }
    if (!valid) return;

    final opening = _showOpeningStock && _trackStock ? int.tryParse(_openingStock.text.trim()) ?? 0 : null;
    final reorder =
        (_showOpeningStock && _trackStock) || _showReorderOnEdit ? int.tryParse(_reorder.text.trim()) : null;
    final input = ProductInput(
      productName: _name.text.trim(),
      categoryId: _category!.id,
      price: double.parse(_price.text.trim()),
      vatId: _vat?.id,
      uomId: _unit!.id,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      status: _status,
      openingStock: opening,
      reorderLevel: reorder,
    );

    setState(() => _saving = true);
    ProductDetail saved;
    try {
      saved = _editing
          ? await ProductService.instance.update(widget.edit!.product.id, input)
          : await ProductService.instance.create(input);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors = e.fieldErrors ?? const {};
      });
      if (!e.isValidation) _toast(e.message);
      return;
    }

    // Like the portal: the image is a separate upload after the product exists.
    // A failed upload is reported but the saved product is kept.
    var message = _editing ? 'Product updated successfully!' : 'Product created successfully!';
    try {
      if (_pickedImage != null) {
        saved = await ProductService.instance.uploadImage(saved.product.id, _pickedImage!.path);
      } else if (_removeImage && _editing) {
        saved = await ProductService.instance.deleteImage(saved.product.id);
      }
    } on ApiException catch (e) {
      message = '${_editing ? 'Product updated' : 'Product created'}, but the image failed to upload: ${e.message}';
    }
    if (!mounted) return;
    _toast(message);
    Navigator.of(context).pop(saved);
  }

  Future<FormOption?> _pick(String title, List<FormOption> options, {FormOption? selected, String? noneLabel}) {
    return showModalBottomSheet<FormOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        isNeu: _isNeu,
        title: title,
        options: options,
        selectedId: selected?.id,
        noneLabel: noneLabel,
      ),
    );
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(title: _editing ? 'Edit Product' : 'Add Product', isNeu: isNeu),
          if (_saving) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(child: _body(isNeu)),
        ]),
      ),
    );
  }

  Widget _body(bool isNeu) {
    final o = _options;
    if (o == null) {
      if (_loadError != null) {
        return Center(
          child: SalesMessage(
            icon: _loadError!.isForbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
            title: _loadError!.isForbidden ? 'You can\'t add products' : 'Couldn\'t load the form',
            subtitle: _loadError!.message,
            isNeu: isNeu,
            onRetry: _loadError!.isForbidden ? null : _loadOptions,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    final ts = SalesUi.textSec(isNeu);
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(px, 6, px, bot + 24),
        children: [
          if (_canUploadImage) ...[
            _section(isNeu, 'Product Image', [_imagePicker(isNeu)]),
            const SizedBox(height: 14),
          ],
          _section(isNeu, 'Product Information', [
            _text(
              controller: _name,
              label: 'Product Name *',
              field: 'productName',
              maxLength: 255,
              formatters: [_ProductNameFormatter()],
              textCapitalization: TextCapitalization.words,
              helper: 'Letters, numbers and spaces only',
              validator: (v) => (v ?? '').trim().isEmpty ? 'Product name is required' : null,
            ),
            const SizedBox(height: 12),
            _select(
              isNeu,
              label: 'Category *',
              value: _category?.label,
              error: _submitted && _category == null ? 'Category is required' : _fieldErrors['categoryId'],
              onTap: () async {
                if (o.categories.isEmpty) {
                  _toast('No active categories yet. Add one under Configurations → Categories.');
                  return;
                }
                final c = await _pick('Category', o.categories, selected: _category);
                if (c != null) setState(() => _category = c);
              },
            ),
            const SizedBox(height: 12),
            _text(
              controller: _price,
              label: 'Price *',
              field: 'price',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              formatters: [_PriceFormatter()],
              prefix: 'TSh ',
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null) return 'Price is required';
                if (n <= 0) return 'Price must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _select(
              isNeu,
              label: 'Unit of Measure *',
              value: _unit == null ? null : (_unit!.detail ?? _unit!.label),
              error: _submitted && _unit == null ? 'Unit of measure is required' : _fieldErrors['uomId'],
              onTap: () async {
                if (o.units.isEmpty) {
                  _toast('No active units yet. Add one under Configurations → Units of Measure.');
                  return;
                }
                final u = await _pick(
                  'Unit of Measure',
                  // The portal lists units by name; keep the code as the detail line.
                  o.units.map((u) => FormOption(id: u.id, label: u.detail ?? u.label, detail: u.label)).toList(),
                  selected: _unit,
                );
                if (u != null) {
                  setState(() => _unit = _find(o.units, u.id) ?? u);
                }
              },
            ),
            const SizedBox(height: 12),
            _select(
              isNeu,
              label: 'Tax Type',
              value: _vat == null ? 'None' : _vat!.label,
              error: _fieldErrors['vatId'],
              onTap: () async {
                if (o.taxTypes.isEmpty) {
                  _toast('Your company has no tax types configured. Set them under Company Info.');
                  return;
                }
                final v = await _pick('Tax Type', o.taxTypes, selected: _vat, noneLabel: 'None');
                if (v != null) setState(() => _vat = v.id.isEmpty ? null : v);
              },
            ),
            const SizedBox(height: 14),
            Text('Status', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ts)),
            const SizedBox(height: 8),
            Wrap(children: [
              for (final s in ProductStatus.values)
                SalesChip(label: s.label, active: _status == s, isNeu: isNeu, onTap: () => setState(() => _status = s)),
            ]),
            const SizedBox(height: 14),
            _text(
              controller: _description,
              label: 'Description',
              field: 'description',
              hint: 'Product description (optional)',
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
          ]),
          if (_showOpeningStock) ...[
            const SizedBox(height: 14),
            _section(isNeu, 'Opening Stock (optional)', [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _trackStock,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _trackStock = v),
                title: Text('Track stock at ${o.defaultBranchName ?? 'my branch'}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SalesUi.text(isNeu))),
                subtitle: Text(
                  o.stockTrackingEnabled
                      ? 'Sales will reduce the count and stop at zero.'
                      : 'Stock tracking is off for your company, so sales won\'t reduce it yet.',
                  style: TextStyle(fontSize: 12, color: ts),
                ),
              ),
              if (_trackStock)
                Row(children: [
                  Expanded(
                    child: _text(
                      controller: _openingStock,
                      label: 'Quantity on hand',
                      field: 'openingStock',
                      keyboardType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _text(
                      controller: _reorder,
                      label: 'Reorder level',
                      field: 'reorderLevel',
                      keyboardType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ]),
            ]),
          ],
          if (_showReorderOnEdit) ...[
            const SizedBox(height: 14),
            _section(isNeu, 'Stock at ${o.defaultBranchName ?? 'my branch'}', [
              _text(
                controller: _reorder,
                label: 'Reorder level',
                field: 'reorderLevel',
                keyboardType: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 6),
              Text('To change the count, use Adjust stock on the product page.',
                  style: TextStyle(fontSize: 12, color: ts)),
            ]),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
            ),
            child: Text(_saving ? 'Saving…' : (_editing ? 'Save changes' : 'Create'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Preview + Choose / Change Image + Clear, like the portal's image card.
  Widget _imagePicker(bool isNeu) {
    final ts = SalesUi.textSec(isNeu);
    final hasImage = _pickedImage != null || _existingImageUrl != null;
    Widget preview;
    if (_pickedImage != null) {
      preview = Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
    } else if (_existingImageUrl != null) {
      preview = Image.network(_existingImageUrl!,
          fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: ts, size: 32));
    } else {
      preview = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_outlined, color: ts, size: 34),
        const SizedBox(height: 4),
        Text('No image', style: TextStyle(fontSize: 11.5, color: ts)),
      ]);
    }
    return Row(children: [
      Container(
        width: 96,
        height: 96,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isNeu ? const Color(0xFFEEF2F0) : const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: preview,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OutlinedButton.icon(
            onPressed: _saving ? null : _chooseImage,
            icon: const Icon(Icons.upload_rounded, size: 18),
            label: Text(hasImage ? 'Change Image' : 'Choose Image'),
          ),
          if (hasImage)
            TextButton.icon(
              onPressed: _saving ? null : _clearImage,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Clear'),
            ),
          Text('JPEG, PNG or WebP, up to 5 MB', style: TextStyle(fontSize: 11.5, color: ts)),
        ]),
      ),
    ]);
  }

  Widget _section(bool isNeu, String title, List<Widget> children) {
    return Container(
      decoration: SalesUi.card(isNeu),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  InputDecoration _decoration(String label, String? error, {String? helper, String? hint, String? prefix}) =>
      InputDecoration(
        labelText: label,
        errorText: error,
        helperText: helper,
        hintText: hint,
        prefixText: prefix,
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: _isNeu ? const Color(0xFFEEF2F0) : const Color(0xFFF8FAF9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  Widget _text({
    required TextEditingController controller,
    required String label,
    required String field,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    String? helper,
    String? hint,
    String? prefix,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SalesUi.text(_isNeu)),
      decoration: _decoration(label, _fieldErrors[field], helper: helper, hint: hint, prefix: prefix),
    );
  }

  Widget _select(bool isNeu, {required String label, String? value, String? error, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _saving ? null : onTap,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: _decoration(label, error).copyWith(
          suffixIcon: Icon(Icons.expand_more_rounded, color: SalesUi.textSec(isNeu)),
        ),
        child: Text(value ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SalesUi.text(isNeu))),
      ),
    );
  }
}

/// Searchable option list. With [noneLabel], the first row returns an option
/// with an empty id meaning "none".
class _PickerSheet extends StatefulWidget {
  final bool isNeu;
  final String title;
  final List<FormOption> options;
  final String? selectedId;
  final String? noneLabel;

  const _PickerSheet({
    required this.isNeu,
    required this.title,
    required this.options,
    this.selectedId,
    this.noneLabel,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final isNeu = widget.isNeu;
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final q = _q.toLowerCase();
    final shown = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.label.toLowerCase().contains(q) || (o.detail ?? '').toLowerCase().contains(q))
            .toList();

    Widget row({required String label, String? detail, required bool selected, required VoidCallback onTap}) =>
        ListTile(
          onTap: onTap,
          title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: tp)),
          subtitle: detail == null ? null : Text(detail, style: TextStyle(color: ts)),
          trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
        );

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isNeu ? AppColors.bgNeu : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(color: AppColors.borderDefault, borderRadius: BorderRadius.circular(2)),
          ),
          Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tp)),
          // The portal's selects are searchable.
          if (widget.options.length > 6)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (widget.noneLabel != null && q.isEmpty)
                row(
                  label: widget.noneLabel!,
                  selected: widget.selectedId == null,
                  onTap: () => Navigator.pop(context, const FormOption(id: '', label: '')),
                ),
              for (final o in shown)
                row(
                  label: o.label,
                  detail: o.detail,
                  selected: o.id == widget.selectedId,
                  onTap: () => Navigator.pop(context, o),
                ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Nothing matches', textAlign: TextAlign.center, style: TextStyle(color: ts)),
                ),
            ]),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
