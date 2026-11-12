import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';

/// Add or edit a customer. Pops the saved [CustomerDetail], or null.
class CustomerFormScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final Customer? edit;

  /// Prefills the name when adding, e.g. from the list's search box.
  final String? initialName;

  const CustomerFormScreen({super.key, required this.themeMode, this.edit, this.initialName});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _vrn = TextEditingController();
  final _idNumber = TextEditingController();

  CustomerFormOptions? _options;
  ApiException? _loadError;
  IdTypeOption? _idType;
  CustomerStatus _status = CustomerStatus.active;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final c = widget.edit;
    if (c != null) {
      _name.text = c.customerName;
      _phone.text = c.phone ?? '';
      _email.text = c.email ?? '';
      _address.text = c.address ?? '';
      _vrn.text = c.vrn ?? '';
      _idNumber.text = c.idNumber ?? '';
      _status = c.status;
    } else {
      final n = widget.initialName ?? '';
      // A search that looks like a phone number prefills the phone instead.
      if (RegExp(r'^[+\d][\d\s-]{5,}$').hasMatch(n)) {
        _phone.text = n;
      } else {
        _name.text = n;
      }
    }
    _loadOptions();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _vrn, _idNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _loadError = null);
    try {
      final o = await CustomerService.instance.formOptions();
      if (!mounted) return;
      setState(() {
        _options = o;
        final id = widget.edit?.idTypeId;
        if (id != null) {
          _idType = o.idTypes.where((t) => t.id == id).firstOrNull ??
              IdTypeOption(id: id, name: widget.edit?.idTypeName ?? 'ID');
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _fieldErrors = const {});
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final input = CustomerInput(
      customerName: _name.text.trim(),
      phone: _v(_phone),
      email: _v(_email),
      address: _v(_address),
      vrn: _v(_vrn),
      idTypeId: _v(_idNumber) == null ? null : _idType?.id,
      idNumber: _idType == null ? null : _v(_idNumber),
      status: _editing ? _status : null,
    );

    setState(() => _saving = true);
    try {
      final saved = _editing
          ? await CustomerService.instance.update(widget.edit!.id, input)
          : await CustomerService.instance.create(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_editing ? 'Customer updated' : '${saved.customer.customerName} added')));
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors = e.fieldErrors ?? const {};
      });
      if (!e.isValidation) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _pickIdType() async {
    final types = _options?.idTypes ?? const [];
    final picked = await showModalBottomSheet<IdTypeOption>(
      context: context,
      backgroundColor: SalesUi.bg(_isNeu),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Text('ID type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SalesUi.text(_isNeu))),
          const SizedBox(height: 6),
          ListTile(
            title: const Text('None', style: TextStyle(fontWeight: FontWeight.w700)),
            trailing: _idType == null ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(ctx, const IdTypeOption(id: '', name: '')),
          ),
          for (final t in types)
            ListTile(
              title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing:
                  _idType?.id == t.id ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(ctx, t),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    setState(() => _idType = picked.id.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(title: _editing ? 'Edit customer' : 'Add customer', isNeu: isNeu),
          if (_saving) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(child: _body(isNeu)),
        ]),
      ),
    );
  }

  Widget _body(bool isNeu) {
    if (_options == null) {
      if (_loadError != null) {
        return Center(
          child: SalesMessage(
            icon: _loadError!.isForbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
            title: _loadError!.isForbidden ? 'You can\'t add customers' : 'Couldn\'t load the form',
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
          _section(isNeu, 'Contact', [
            _text(_name, 'Full name or business name', 'customerName',
                caps: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null),
            const SizedBox(height: 12),
            _text(_phone, 'Phone (optional)', 'phone',
                keyboard: TextInputType.phone,
                validator: (v) => (v ?? '').trim().length > 30 ? 'Too long' : null),
            const SizedBox(height: 12),
            _text(_email, 'Email (optional)', 'email',
                keyboard: TextInputType.emailAddress,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Enter a valid email';
                }),
            const SizedBox(height: 12),
            _text(_address, 'Address (optional)', 'address', maxLines: 2, caps: TextCapitalization.sentences),
          ]),
          const SizedBox(height: 14),
          _section(isNeu, 'Tax & ID', [
            Text('Printed on fiscal receipts. Needed when the buyer wants to claim VAT.',
                style: TextStyle(fontSize: 12, color: ts)),
            const SizedBox(height: 12),
            _text(_vrn, 'TIN / VRN (optional)', 'vrn', caps: TextCapitalization.characters),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: _saving ? null : _pickIdType,
                  child: InputDecorator(
                    isEmpty: false,
                    decoration: _decoration('ID type', _fieldErrors['idTypeId']).copyWith(
                      suffixIcon: Icon(Icons.expand_more_rounded, color: ts),
                    ),
                    child: Text(_idType?.name ?? 'None',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SalesUi.text(isNeu))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _text(_idNumber, 'ID number', 'idNumber',
                    enabled: _idType != null,
                    validator: (v) =>
                        _idType != null && (v ?? '').trim().isEmpty ? 'Enter the number' : null),
              ),
            ]),
          ]),
          if (_editing) ...[
            const SizedBox(height: 14),
            _section(isNeu, 'Status', [
              Row(children: [
                for (final s in CustomerStatus.values)
                  SalesChip(label: s.label, active: _status == s, isNeu: isNeu, onTap: () => setState(() => _status = s)),
              ]),
            ]),
          ] else if (_options!.defaultBranchName != null) ...[
            const SizedBox(height: 10),
            Text('Will be added to ${_options!.defaultBranchName}.',
                style: TextStyle(fontSize: 12, color: ts)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
              ),
              child: Text(_saving ? 'Saving…' : (_editing ? 'Save changes' : 'Add customer'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(bool isNeu, String title, List<Widget> children) => Container(
        decoration: SalesUi.card(isNeu),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  InputDecoration _decoration(String label, String? error) => InputDecoration(
        labelText: label,
        errorText: error,
        isDense: true,
        filled: true,
        fillColor: _isNeu ? const Color(0xFFEEF2F0) : const Color(0xFFF8FAF9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDefault)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDefault)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      );

  Widget _text(TextEditingController c, String label, String field,
      {TextInputType? keyboard,
      String? Function(String?)? validator,
      int maxLines = 1,
      bool enabled = true,
      TextCapitalization caps = TextCapitalization.none}) {
    return TextFormField(
      controller: c,
      enabled: enabled && !_saving,
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: caps,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SalesUi.text(_isNeu)),
      decoration: _decoration(label, _fieldErrors[field]),
    );
  }
}
