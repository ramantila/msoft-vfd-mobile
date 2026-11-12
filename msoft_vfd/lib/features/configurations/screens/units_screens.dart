import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../products/screens/product_detail_screen.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/config_models.dart';
import '../services/config_service.dart';
import 'config_widgets.dart';

class _CodeBadge extends StatelessWidget {
  final String code;
  final bool isNeu;
  final double size;
  const _CodeBadge({required this.code, required this.isNeu, this.size = 42});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isNeu ? AppColors.bgNeu : const Color(0xFFDEEFFE),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            child: Text(code,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E6FD8), letterSpacing: 0.3)),
          ),
        ),
      );
}

/// Units of Measure list, like the portal's Units page.
class UnitListScreen extends StatelessWidget {
  final AppThemeMode themeMode;
  const UnitListScreen({super.key, required this.themeMode});

  bool get _isNeu => themeMode == AppThemeMode.neumorphic;

  @override
  Widget build(BuildContext context) {
    return ConfigListPage<UnitItem>(
      themeMode: themeMode,
      title: 'Units of Measure',
      searchHint: 'Search code or name…',
      emptyTitle: 'No units found',
      emptyIcon: Icons.straighten_rounded,
      canAdd: AuthState.has('UOM_CREATE'),
      load: (q) => ConfigService.instance.units(query: q),
      isActive: (u) => u.active,
      onAdd: (ctx) async =>
          await Navigator.of(ctx).push<UnitDetail>(slideRight(UnitFormScreen(themeMode: themeMode))) != null,
      rowBuilder: (ctx, u, reload) => ConfigRow(
        isNeu: _isNeu,
        leading: _CodeBadge(code: u.code, isNeu: _isNeu),
        title: u.name,
        subtitle: [u.code, ?u.description].join(' · '),
        systemDefault: u.systemDefault,
        active: u.active,
        productCount: u.productCount,
        onTap: () async {
          final changed =
              await Navigator.of(ctx).push<bool>(slideRight(UnitDetailScreen(themeMode: themeMode, unitId: u.id)));
          if (changed == true) reload();
        },
      ),
    );
  }
}

/// Unit view. Shared defaults are read-only here (see MobileUnitServiceImpl).
class UnitDetailScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String unitId;
  const UnitDetailScreen({super.key, required this.themeMode, required this.unitId});

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  UnitDetail? _d;
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
      final d = await ConfigService.instance.unit(widget.unitId);
      if (mounted) setState(() => _d = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggle() async {
    final u = _d!.unit;
    setState(() => _busy = true);
    try {
      final d = await ConfigService.instance.setUnitActive(u.id, !u.active);
      if (!mounted) return;
      setState(() {
        _d = d;
        _busy = false;
        _changed = true;
      });
      _toast('${u.name} ${d.unit.active ? 'activated' : 'deactivated'}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context)
        .push<UnitDetail>(slideRight(UnitFormScreen(themeMode: widget.themeMode, edit: _d!.unit)));
    if (updated != null && mounted) {
      setState(() {
        _d = updated;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final d = _d!;
    final blocker = d.canDelete ? null : d.lockedReason;
    if (!await confirmConfigDelete(context, what: 'unit', blocker: blocker)) return;
    setState(() => _busy = true);
    try {
      await ConfigService.instance.deleteUnit(d.unit.id);
      if (!mounted) return;
      _toast('Unit deleted successfully.');
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
                  title: 'Failed to load unit',
                  subtitle: _error!.message,
                  isNeu: isNeu,
                  onRetry: _load))
          : const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else {
      final u = d.unit;
      body = ConfigDetailBody(
        isNeu: isNeu,
        leading: _CodeBadge(code: u.code, isNeu: isNeu, size: 56),
        title: u.name,
        subtitle: u.code,
        systemDefault: u.systemDefault,
        active: u.active,
        note: u.systemDefault ? d.lockedReason : null,
        info: [
          ('Code', u.code),
          ('Name', u.name),
          ('Description', u.description ?? '—'),
          ('Status', u.active ? 'Active' : 'Inactive'),
          if (u.createdAt != null) ('Created', SalesFormat.date(u.createdAt!)),
        ],
        products: d.products,
        productCount: u.productCount,
        onProduct: AuthState.has('PRODUCT_VIEW')
            ? (p) => Navigator.of(context)
                .push(slideRight(ProductDetailScreen(themeMode: widget.themeMode, productId: p.id)))
            : null,
        busy: _busy,
        onToggle: d.canToggle ? _toggle : null,
        onEdit: d.canEdit ? _edit : null,
        onDelete: !u.systemDefault && AuthState.has('UOM_DELETE') ? _delete : null,
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
            SalesHeader(title: d?.unit.name ?? 'Unit', isNeu: isNeu),
            if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
            Expanded(child: body),
          ]),
        ),
      ),
    );
  }
}

/// Create / edit a unit, as on the portal: code (uppercased automatically,
/// letters and digits only), name, description.
class UnitFormScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final UnitItem? edit;
  const UnitFormScreen({super.key, required this.themeMode, this.edit});

  @override
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
  static final _codePattern = RegExp(r'^[A-Za-z0-9]+$');

  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.edit?.code ?? '');
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _description = TextEditingController(text: widget.edit?.description ?? '');
  bool _saving = false;
  Map<String, String> _errors = const {};

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void dispose() {
    _code.dispose();
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
      final d = await ConfigService.instance.saveUnit(
        id: widget.edit?.id,
        code: _code.text.trim().toUpperCase(),
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.edit == null ? 'Unit created successfully!' : 'Unit updated successfully!')));
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
    final code = _code.text.trim();
    final codeInvalid = code.isNotEmpty && !_codePattern.hasMatch(code);
    return ConfigFormPage(
      isNeu: isNeu,
      title: widget.edit == null ? 'Create Unit' : 'Edit Unit',
      section: 'Unit Information',
      formKey: _formKey,
      saving: _saving,
      submitLabel: widget.edit == null ? 'Create' : 'Save changes',
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _code,
          enabled: !_saving,
          maxLength: 32,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
          ],
          onChanged: (_) => setState(() {}),
          decoration: configInput(isNeu, 'Code *',
                  error: codeInvalid ? 'Letters and digits only, e.g. PCS, KG, M2' : _errors['code'],
                  helper: 'Uppercased automatically, e.g. PCS, KG, M2')
              .copyWith(counterText: ''),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Enter a code';
            if (!_codePattern.hasMatch(t)) return 'Letters and digits only, e.g. PCS, KG, M2';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _name,
          enabled: !_saving,
          maxLength: 128,
          textCapitalization: TextCapitalization.words,
          decoration: configInput(isNeu, 'Name *', error: _errors['name'], hint: 'e.g. Pieces, Kilogram')
              .copyWith(counterText: ''),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _description,
          enabled: !_saving,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: configInput(isNeu, 'Description', error: _errors['description'], hint: 'Optional'),
        ),
      ],
    );
  }
}
