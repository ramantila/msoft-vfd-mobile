import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../../users/screens/staff_widgets.dart';
import '../models/branch.dart';
import '../services/branch_service.dart';

/// Add or edit a branch. Pops the saved [BranchDetail].
class BranchFormScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final BranchDetail? edit;

  /// The package's user limit, shown as a hint for the staff limit.
  final int? maxUsers;

  /// Package figures for the "x / y branches used" bar when adding.
  final BranchSummary? summary;

  const BranchFormScreen({super.key, required this.themeMode, this.edit, this.maxUsers, this.summary});

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _limit = TextEditingController();
  bool _hasLimit = false;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _editing => widget.edit != null;
  int get _currentStaff => widget.edit?.figures.staffCount ?? 0;

  @override
  void initState() {
    super.initState();
    final b = widget.edit;
    if (b != null) {
      _name.text = b.branchName;
      _location.text = b.location ?? '';
      if (b.noOfEmployee != null) {
        _hasLimit = true;
        _limit.text = '${b.noOfEmployee}';
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _fieldErrors = const {});
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = BranchInput(
      branchName: _name.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      noOfEmployee: _hasLimit ? int.tryParse(_limit.text.trim()) : null,
    );
    setState(() => _saving = true);
    try {
      final saved = _editing
          ? await BranchService.instance.update(widget.edit!.id, input)
          : await BranchService.instance.create(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_editing ? 'Branch saved' : '${saved.branchName} added')));
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors = e.fieldErrors ?? const {};
      });
      if (!e.isValidation) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final ts = SalesUi.textSec(isNeu);
    final px = SalesUi.gutter(isNeu);
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        child: Column(children: [
          SalesHeader(title: _editing ? 'Edit Branch' : 'Add Branch', isNeu: isNeu),
          if (_saving) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(padding: EdgeInsets.fromLTRB(px, 6, px, 24), children: [
                if (!_editing && widget.summary?.maxBranches != null) ...[
                  Container(
                    decoration: SalesUi.card(isNeu),
                    padding: const EdgeInsets.all(14),
                    child: QuotaBar(
                      used: widget.summary!.branchCount,
                      max: widget.summary!.maxBranches!,
                      noun: 'branches',
                      packageName: widget.summary!.packageName ?? '',
                      isNeu: isNeu,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Container(
                  decoration: SalesUi.card(isNeu),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Branch Information',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: SalesUi.text(isNeu))),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: staffInput(isNeu, 'Branch Name *', error: _fieldErrors['branchName']),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: staffInput(isNeu, 'Location',
                          error: _fieldErrors['location'], helper: 'e.g. Kariakoo, Dar es Salaam'),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: SalesUi.card(isNeu),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _hasLimit,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => setState(() => _hasLimit = v),
                      title: Text('Limit No. of Employees',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SalesUi.text(isNeu))),
                      subtitle: Text(
                          widget.maxUsers == null
                              ? 'Off: any number of staff.'
                              : 'Your package allows ${widget.maxUsers} users in total.',
                          style: TextStyle(fontSize: 12, color: ts)),
                    ),
                    if (_hasLimit)
                      TextFormField(
                        controller: _limit,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: staffInput(isNeu, 'No. of Employees',
                            error: _fieldErrors['noOfEmployee'],
                            helper: _editing ? '$_currentStaff assigned now' : null),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 1) return 'Enter 1 or more';
                          if (n < _currentStaff) return '$_currentStaff staff are already assigned';
                          if (widget.maxUsers != null && n > widget.maxUsers!) {
                            return "Can't exceed the ${widget.maxUsers} users allowed by your plan";
                          }
                          return null;
                        },
                      ),
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving || (!_editing && widget.summary?.canAddMore == false) ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
                  ),
                  child: Text(_saving ? 'Saving…' : (_editing ? 'Save changes' : 'Create'),
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
