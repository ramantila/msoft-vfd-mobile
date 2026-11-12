import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../services/product_service.dart';

/// The portal's "Bulk Upload Products" dialog as a screen: how the template
/// works, your company ID, pick an .xlsx, upload. Pops `true` when products
/// were created.
class BulkUploadScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const BulkUploadScreen({super.key, required this.themeMode});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  static const _columns = <(String, bool, String)>[
    ('product_name', true, 'e.g. Sugar 1kg'),
    ('category_id', true, 'ID of an active category'),
    ('price', true, 'e.g. 3000'),
    ('uom_id', true, 'ID of an active unit of measure'),
    ('vat_id', false, 'ID of one of your tax types'),
    ('description', false, 'Free text'),
    ('status', false, 'ACTIVE, INACTIVE or DISCONTINUED'),
  ];

  PlatformFile? _file;
  int? _fileBytes;
  bool _uploading = false;
  String? _error;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;

  Future<void> _choose() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx']);
      if (files.isEmpty || !mounted) return;
      final f = files.first;
      if (!f.name.toLowerCase().endsWith('.xlsx')) {
        setState(() => _error = 'Choose an Excel .xlsx file');
        return;
      }
      final length = await f.xFile.length();
      if (!mounted) return;
      setState(() {
        _file = f;
        _fileBytes = length;
        _error = null;
      });
    } on PlatformException catch (e) {
      setState(() => _error = 'Couldn\'t open the file: ${e.message ?? e.code}');
    }
  }

  Future<void> _upload() async {
    final f = _file;
    if (f == null) {
      setState(() => _error = 'Please choose an .xlsx file first');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      // Read through XFile: on Android the pick is often a content:// link with no file path.
      final bytes = await f.xFile.readAsBytes();
      final message = await ProductService.instance.bulkCreate(bytes, f.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    final tp = SalesUi.text(isNeu);
    final ts = SalesUi.textSec(isNeu);
    final px = SalesUi.gutter(isNeu);
    final companyId = AuthState.session?.companyId ?? '';
    Widget card(String title, List<Widget> children) => Container(
          decoration: SalesUi.card(isNeu),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 10),
            ...children,
          ]),
        );

    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        child: Column(children: [
          SalesHeader(title: 'Bulk Upload Products', isNeu: isNeu),
          if (_uploading) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          Expanded(
            child: ListView(padding: EdgeInsets.fromLTRB(px, 6, px, 24), children: [
              card('How it works', [
                Text(
                  'Make an Excel (.xlsx) sheet whose first row has these column names, in any order. '
                  'Each row below it becomes one product. If any row is wrong, nothing is created and '
                  'the row number is shown.',
                  style: TextStyle(fontSize: 12.5, color: ts, height: 1.4),
                ),
                const SizedBox(height: 10),
                for (final (name, required, hint) in _columns)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 112,
                        child: Text('$name${required ? ' *' : ''}',
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700, color: tp)),
                      ),
                      Expanded(child: Text(hint, style: TextStyle(fontSize: 12, color: ts))),
                    ]),
                  ),
                const SizedBox(height: 8),
                Text('The portal\'s template also has a company_id column. It\'s accepted here and ignored; '
                    'products always go to your own company.',
                    style: TextStyle(fontSize: 11.5, color: ts, height: 1.35)),
                const SizedBox(height: 12),
                Row(children: [
                  Text('Your Company ID: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tp)),
                  Expanded(
                    child: Text(companyId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: ts)),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: companyId));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Company ID copied')));
                    },
                  ),
                ]),
              ]),
              const SizedBox(height: 14),
              card('Excel File (.xlsx)', [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _choose,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(_file == null ? 'Choose file' : 'Choose another file'),
                ),
                if (_file != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.description_outlined, size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${_file!.name}${_fileBytes != null ? ' · ${(_fileBytes! / 1024).toStringAsFixed(1)} KB' : ''}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tp)),
                    ),
                  ]),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                ],
              ]),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _uploading || _file == null ? null : _upload,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNeu ? 17 : 14)),
                ),
                child: Text(_uploading ? 'Uploading…' : 'Upload',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: _uploading ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
