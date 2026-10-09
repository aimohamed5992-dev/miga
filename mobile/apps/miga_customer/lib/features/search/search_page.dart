import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../campaigns/campaign_detail_page.dart';
import '../products/product_detail_page.dart';
import '../stores/store_detail_page.dart';
import '../stores/store_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  late String _q = widget.initialQuery;
  final _recent = ['هاتف', 'أرز بسمتي', 'عطر عود'];
  static const _popular = ['تمر سكري', 'سماعات', 'قهوة عربية', 'حذاء رياضي', 'زيت زيتون', 'لابتوب'];

  SearchData _result = const SearchData([], [], []);
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (_q.trim().isNotEmpty) _search(_q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _controller.text = q;
    _onChanged(q);
  }

  /// Waits for a short pause in typing before calling the API.
  void _onChanged(String q) {
    setState(() => _q = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final r = await AppServices.api.catalog.search(q.trim());
      // Ignore stale responses if the user kept typing.
      if (mounted && q == _q) setState(() => _result = r);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = _q.trim();
    final campaigns = q.isEmpty ? <Campaign>[] : _result.campaigns;
    final products = q.isEmpty ? <Product>[] : _result.products;
    final stores = q.isEmpty ? <Store>[] : _result.stores;
    final empty = q.isNotEmpty && !_searching && _result.isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: TextField(
            controller: _controller,
            autofocus: widget.initialQuery.isEmpty,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن منتج أو حملة أو متجر',
              prefixIcon: const Icon(Icons.search_rounded, color: MigaColors.textHint),
              suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _setQuery('')),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body:
          q.isEmpty
              ? ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Text('عمليات البحث الأخيرة', style: t.titleMedium),
                      const Spacer(),
                      TextButton(onPressed: () => setState(_recent.clear), child: const Text('مسح')),
                    ],
                  ),
                  for (final r in _recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded, color: MigaColors.textHint),
                      title: Text(r),
                      trailing: const Icon(Icons.north_west_rounded, size: 18, color: MigaColors.textHint),
                      onTap: () => _setQuery(r),
                    ),
                  const SizedBox(height: 16),
                  Text('الأكثر بحثًا 🔥', style: t.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final p in _popular) MigaChoiceChip(label: p, selected: false, onSelected: () => _setQuery(p))],
                  ),
                ],
              )
              : empty
              ? EmptyState(image: 'empty_orders.png', title: 'لا توجد نتائج لـ "$q"', message: 'جرّب كلمات أخرى أو تصفّح الأقسام')
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (campaigns.isNotEmpty) ...[
                    _Title('الحملات', campaigns.length),
                    for (final c in campaigns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CampaignTile(campaign: c, onTap: () => migaPush(context, CampaignDetailPage(campaign: c))),
                      ),
                  ],
                  if (products.isNotEmpty) ...[
                    _Title('المنتجات', products.length),
                    for (final p in products)
                      MigaCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => migaPush(context, ProductDetailPage(product: p)),
                        child: Row(
                          children: [
                            MigaImage(p.mainImage, width: 56, height: 56, borderRadius: MigaRadius.all(MigaRadius.sm)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(p.nameAr, style: t.titleSmall)),
                            Text(MigaFormat.money(p.price), style: t.titleSmall),
                          ],
                        ),
                      ),
                  ],
                  if (stores.isNotEmpty) ...[
                    _Title('المتاجر', stores.length),
                    for (final s in stores)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: StoreLogo(store: s, size: 44),
                        title: Text(s.nameAr),
                        trailing: RatingChip(s.rating),
                        onTap: () => migaPush(context, StoreDetailPage(store: s)),
                      ),
                  ],
                ],
              ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.count);
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 10),
    child: Text('$text ($count)', style: Theme.of(context).textTheme.titleMedium),
  );
}
