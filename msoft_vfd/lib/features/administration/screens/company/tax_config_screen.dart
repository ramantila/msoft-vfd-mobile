import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/utils/auth_state.dart';
import '../../models/company_tax_config.dart';
import '../../models/tax_type.dart';
import '../../providers/company_provider.dart';
import '../../widgets/admin_widgets.dart';

class TaxConfigScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const TaxConfigScreen({super.key, required this.themeMode});

  @override
  State<TaxConfigScreen> createState() => _TaxConfigScreenState();
}

class _TaxConfigScreenState extends State<TaxConfigScreen> {
  late AppThemeMode _theme;
  late final CompanyProvider _provider;

  @override
  void initState() {
    super.initState();
    _theme = widget.themeMode;
    _provider = CompanyProvider(companyId: AuthState.session!.companyId);
    _provider.load();
  }

  Future<void> _addTaxType(bool isNeu, Color tp, Color ts) async {
    final configured = _provider.taxConfigs.map((c) => c.taxTypeId).toSet();
    final available =
        _provider.taxTypes.where((t) => !configured.contains(t.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All tax types are already configured.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<TaxType>(
      context: context,
      backgroundColor: isNeu ? AppColors.bgNeu : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add tax type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 12),
            ...available.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.taxName,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                  subtitle: Text(
                      [t.taxCode, if (t.taxPercent != null) '${t.taxPercent}%'].join(' · '),
                      style: TextStyle(fontSize: 12, color: ts)),
                  onTap: () => Navigator.of(ctx).pop(t),
                )),
          ]),
        ),
      ),
    );

    if (selected != null) await _provider.addTaxConfig(selected.id);
  }

  Future<void> _confirmRemove(CompanyTaxConfig config, bool isNeu) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Remove tax type?',
      message: '${config.taxTypeName} will no longer apply to this company.',
      confirmLabel: 'Remove',
      isNeu: isNeu,
    );
    if (confirmed) await _provider.removeTaxConfig(config.id);
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _theme == AppThemeMode.neumorphic;
    final bg = isNeu ? AppColors.bgNeu : AppColors.bgDefault;
    final tp = isNeu ? AppColors.textPrimaryNeu : AppColors.textPrimary;
    final ts = isNeu ? AppColors.textSecondaryNeu : AppColors.textSecondary;
    final bot = MediaQuery.of(context).padding.bottom;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(children: [
          AdminHeader(
            title: 'Tax configuration',
            isNeu: isNeu, tp: tp, ts: ts,
            trailing: GestureDetector(
              onTap: () => _addTaxType(isNeu, tp, ts),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          Expanded(
            child: Consumer<CompanyProvider>(
              builder: (context, provider, _) {
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: provider.load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bot + 24),
                    children: [
                      if (provider.error != null)
                        AdminErrorBanner(
                          message: provider.error!.message,
                          tp: tp, ts: ts,
                          onRetry: provider.load,
                        ),
                      if (provider.loading && provider.taxConfigs.isEmpty)
                        const AdminLoading()
                      else if (provider.taxConfigs.isEmpty)
                        AdminEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No tax types configured',
                          subtitle: 'Add a tax type to apply it to this company.',
                          tp: tp, ts: ts,
                        )
                      else
                        ...provider.taxConfigs.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AdminCard(
                                isNeu: isNeu,
                                child: Row(children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F7FA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.receipt_long_outlined,
                                        color: Color(0xFF0097A7), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(c.taxTypeName,
                                        style: TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                                  ),
                                  GestureDetector(
                                    onTap: () => _confirmRemove(c, isNeu),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.close_rounded,
                                          size: 18, color: Color(0xFFE5484D)),
                                    ),
                                  ),
                                ]),
                              ),
                            )),
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
