import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../services/staff_service.dart';
import 'staff_widgets.dart';

/// Change my own password (asks for the current one), or — with [userId] —
/// set a new password for a staff member. Pops `true` on success.
class StaffPasswordScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final String? userId;
  final String? userName;

  const StaffPasswordScreen({super.key, required this.themeMode, this.userId, this.userName});

  @override
  State<StaffPasswordScreen> createState() => _StaffPasswordScreenState();
}

class _StaffPasswordScreenState extends State<StaffPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  bool get _self => widget.userId == null;
  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      if (_self) {
        await StaffService.instance.changeMyPassword(_current.text, _next.text);
      } else {
        await StaffService.instance.resetPassword(widget.userId!, _next.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_self
              ? 'Password changed. Other devices were signed out.'
              : 'Password set. ${widget.userName ?? 'They'} will need to sign in again.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final ts = SalesUi.textSec(isNeu);
    final px = SalesUi.gutter(isNeu);
    final eye = IconButton(
      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
      onPressed: () => setState(() => _show = !_show),
    );
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        child: Column(children: [
          SalesHeader(title: _self ? 'Change my password' : 'Set new password', isNeu: isNeu),
          if (_saving) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(padding: EdgeInsets.fromLTRB(px, 6, px, 24), children: [
                Container(
                  decoration: SalesUi.card(isNeu),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _self
                          ? 'You\'ll stay signed in on this phone. Every other device will be signed out.'
                          : 'For ${widget.userName ?? 'this staff member'}. They\'ll be signed out everywhere '
                              'and must sign in with the new password. Tell them in person.',
                      style: TextStyle(fontSize: 12.5, color: ts, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    if (_self) ...[
                      TextFormField(
                        controller: _current,
                        obscureText: !_show,
                        decoration: staffInput(isNeu, 'Current password', suffix: eye),
                        validator: (v) => (v ?? '').isEmpty ? 'Enter your current password' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _next,
                      obscureText: !_show,
                      decoration: staffInput(isNeu, 'New password',
                          helper: 'At least 8 characters', suffix: _self ? null : eye),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if ((v ?? '').length < 8) return 'Use at least 8 characters';
                        if (_self && v == _current.text) return 'Choose a different password';
                        return null;
                      },
                    ),
                    PasswordStrengthBar(
                      password: _next.text,
                      onGenerate: _self
                          ? null
                          : () => setState(() {
                                final p = generatePassword();
                                _next.text = p;
                                _confirm.text = p;
                                _show = true;
                              }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: !_show,
                      decoration: staffInput(isNeu, 'Repeat new password'),
                      validator: (v) => v != _next.text ? 'Passwords don\'t match' : null,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save password',
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
