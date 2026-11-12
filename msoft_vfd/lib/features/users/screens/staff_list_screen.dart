import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/page_transitions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_state.dart';
import '../../sales/utils/sales_format.dart';
import '../../sales/widgets/sales_widgets.dart';
import '../models/staff.dart';
import '../services/staff_service.dart';
import 'staff_detail_screen.dart';
import 'staff_form_screen.dart';
import 'staff_widgets.dart';

/// Staff list: search, status / role filters, today's sales per person.
class StaffListScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  const StaffListScreen({super.key, required this.themeMode});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  static const _pageSize = 30;

  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  StaffStatus? _status;
  final List<StaffItem> _items = [];
  StaffSummary? _summary;
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  ApiException? _error;
  int _generation = 0;

  bool get _isNeu => widget.themeMode == AppThemeMode.neumorphic;
  bool get _canAdd => AuthState.has('USER_CREATE');

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        StaffService.instance.list(query: _searchCtrl.text, status: _status, size: _pageSize),
        StaffService.instance.summary(),
      ]);
      final page = results[0] as PageResponse<StaffItem>;
      final s = results[1] as StaffSummary;
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.content);
        _total = page.totalElements;
        _summary = s;
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
      final page = await StaffService.instance
          .list(query: _searchCtrl.text, status: _status, page: _page + 1, size: _pageSize);
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

  Future<void> _open(StaffItem s) async {
    final changed = await Navigator.of(context)
        .push<bool>(slideRight(StaffDetailScreen(themeMode: widget.themeMode, userId: s.id)));
    if (changed == true) _reload();
  }

  Future<void> _add() async {
    final q = _summary?.quota;
    if (q != null && q.reached) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Limit reached for the ${q.packageName} plan (${q.maxUsers} users).')));
      return;
    }
    final created =
        await Navigator.of(context).push<StaffDetail>(slideRight(StaffFormScreen(themeMode: widget.themeMode)));
    if (created != null) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isNeu = _isNeu;
    return Scaffold(
      backgroundColor: SalesUi.bg(isNeu),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SalesHeader(
            title: 'System Users',
            isNeu: isNeu,
            actionIcon: _canAdd ? Icons.person_add_alt_1_rounded : null,
            onAction: _canAdd ? _add : null,
          ),
          if (_summary?.quota != null)
            Padding(
              padding: EdgeInsets.fromLTRB(SalesUi.gutter(isNeu), 0, SalesUi.gutter(isNeu), 10),
              child: QuotaBar(
                used: _summary!.quota!.currentUsers,
                max: _summary!.quota!.maxUsers,
                noun: 'users',
                packageName: _summary!.quota!.packageName,
                isNeu: isNeu,
              ),
            ),
          if (_summary != null && _summary!.sellingToday > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(SalesUi.gutter(isNeu), 0, SalesUi.gutter(isNeu), 8),
              child: Row(children: [
                const Icon(Icons.point_of_sale_rounded, size: 15, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Text('${_summary!.sellingToday} selling today',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
              ]),
            ),
          _search(isNeu),
          _filters(isNeu),
          Expanded(child: _body(isNeu)),
        ]),
      ),
    );
  }

  Widget _search(bool isNeu) {
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
                border: Border.all(color: active ? AppColors.primary : AppColors.borderDefault, width: active ? 1.5 : 1),
              ),
        child: Row(children: [
          Icon(Icons.search_rounded, color: active ? AppColors.primary : ts, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _reload);
                setState(() {});
              },
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: SalesUi.text(isNeu)),
              decoration: InputDecoration(
                hintText: 'Name, username or phone…',
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
                _reload();
              },
              child: Icon(Icons.close_rounded, color: ts, size: 17),
            ),
        ]),
      ),
    );
  }

  Widget _filters(bool isNeu) {
    final s = _summary;
    String c(String l, int? n) => n == null || n == 0 ? l : '$l · $n';
    final chips = <(StaffStatus?, String)>[
      (null, c('All', s?.total)),
      (StaffStatus.active, c('Active', s?.active)),
      (StaffStatus.inactive, c('Inactive', s?.inactive)),
      (StaffStatus.suspended, c('Suspended', s?.suspended)),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(SalesUi.gutter(isNeu), 2, 12, 8),
        children: [
          for (final (st, label) in chips)
            SalesChip(
              label: label,
              active: _status == st,
              isNeu: isNeu,
              onTap: () {
                if (_status == st) return;
                setState(() => _status = st);
                _reload();
              },
            ),
        ],
      ),
    );
  }

  Widget _body(bool isNeu) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: SalesMessage(
          icon: _error!.isForbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          title: _error!.isForbidden ? 'No access to staff' : 'Couldn\'t load staff',
          subtitle: _error!.message,
          isNeu: isNeu,
          onRetry: _error!.isForbidden ? null : _reload,
        ),
      );
    }
    final px = SalesUi.gutter(isNeu);
    final bot = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(children: [
              SalesMessage(icon: Icons.people_outline_rounded, title: 'No staff match', isNeu: isNeu),
            ])
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(px, 4, px, bot + 20),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  );
                }
                return _StaffRow(item: _items[i], isNeu: isNeu, onTap: () => _open(_items[i]));
              },
            ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  final StaffItem item;
  final bool isNeu;
  final VoidCallback onTap;
  const _StaffRow({required this.item, required this.isNeu, required this.onTap});

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
          Opacity(opacity: item.status == StaffStatus.active ? 1 : 0.5, child: StaffAvatar(name: item.fullName)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(item.me ? '${item.fullName} (you)' : item.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(['@${item.username}', ?item.branchName].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ts)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                StaffPill(
                  label: item.roleLabel,
                  color: item.roleNames.isEmpty && item.role != UserRole.superAdmin
                      ? AppColors.textMuted
                      : StaffUi.roleColor(item.role == UserRole.superAdmin ? UserRole.superAdmin : UserRole.manager),
                ),
                StaffPill(label: item.status.label, color: StaffUi.statusColor(item.status)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(item.salesToday == 0 ? '—' : SalesFormat.compactMoney(item.totalToday),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: item.salesToday == 0 ? ts : AppColors.primaryDark,
                    fontFeatures: SalesUi.tabular)),
            Text(item.salesToday == 0 ? 'no sales today' : '${item.salesToday} today',
                style: TextStyle(fontSize: 10.5, color: ts)),
          ]),
        ]),
      ),
    );
  }
}
