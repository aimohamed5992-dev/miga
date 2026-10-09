import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../search/search_page.dart';
import '../../core/services.dart';
import 'campaign_detail_page.dart';

enum CampaignFilter {
  all('الكل', Icons.apps_rounded),
  endingSoon('تنتهي قريبًا', Icons.timer_outlined),
  almostComplete('قاربت على الاكتمال', Icons.local_fire_department_outlined),
  biggestDiscount('الأعلى خصمًا', Icons.percent_rounded),
  newest('الأحدث', Icons.fiber_new_outlined);

  const CampaignFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// "الحملات" tab — also opened standalone from the home "see all" links.
class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key, this.initialFilter = CampaignFilter.all, this.standalone = false});
  final CampaignFilter initialFilter;
  final bool standalone;

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  late CampaignFilter _filter = widget.initialFilter;
  String? _categoryId;
  bool _grid = true;

  List<Campaign> _items = [];
  List<StoreCategory> _categories = [];
  bool _loading = true;
  Object? _error;

  static const _sorts = {
    CampaignFilter.all: 'newest',
    CampaignFilter.newest: 'newest',
    CampaignFilter.endingSoon: 'endingSoon',
    CampaignFilter.almostComplete: 'almostComplete',
    CampaignFilter.biggestDiscount: 'biggestDiscount',
  };

  @override
  void initState() {
    super.initState();
    AppServices.api.catalog
        .storeCategories()
        .then((c) {
          if (mounted) setState(() => _categories = c);
        })
        .catchError((Object _) {});
    _load();
  }

  /// Filtering and sorting happen on the server (live campaigns only).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppServices.api.catalog.campaigns(sort: _sorts[_filter]!, storeCategoryId: _categoryId, pageSize: 50);
      if (mounted) setState(() => _items = page.items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(CampaignFilter f) {
    setState(() => _filter = f);
    _load();
  }

  void _setCategory(String? id) {
    setState(() => _categoryId = id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: const Text('الحملات النشطة'),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => migaPush(context, const SearchPage())),
          IconButton(
            icon: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: CampaignFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = CampaignFilter.values[i];
                final sel = f == _filter;
                return Center(child: MigaChoiceChip(icon: f.icon, label: f.label, selected: sel, onSelected: () => _setFilter(f)));
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryTab(label: 'كل الأقسام', selected: _categoryId == null, onTap: () => _setCategory(null)),
                for (final c in _categories) _CategoryTab(label: c.nameAr, selected: _categoryId == c.id, onTap: () => _setCategory(c.id)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [Text('${items.length} حملة', style: t.bodySmall)]),
          ),
          Expanded(
            child:
                _loading && items.isEmpty
                    ? ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, __) => const MigaTileSkeleton(),
                    )
                    : _error != null
                    ? MigaErrorView(offline: _error is ApiException && (_error as ApiException).isNetwork, onRetry: _load)
                    : items.isEmpty
                    ? const EmptyState(image: 'empty_campaigns.png', title: 'لا توجد حملات مطابقة', message: 'جرّب تغيير الفلتر أو القسم')
                    : RefreshIndicator(
                      onRefresh: _load,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child:
                            _grid
                                ? GridView.builder(
                                  key: ValueKey('g$_filter$_categoryId'),
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 300,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder:
                                      (_, i) => CampaignCard(
                                        campaign: items[i],
                                        onTap: () => migaPush(context, CampaignDetailPage(campaign: items[i])),
                                      ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: .08),
                                )
                                : ListView.separated(
                                  key: ValueKey('l$_filter$_categoryId'),
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder:
                                      (_, i) => CampaignTile(
                                        campaign: items[i],
                                        trailing: CountdownChip(items[i].timeLeft),
                                        onTap: () => migaPush(context, CampaignDetailPage(campaign: items[i])),
                                      ).animate().fadeIn(delay: (i * 50).ms),
                                ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsetsDirectional.only(end: 18),
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? MigaColors.primary : Colors.transparent, width: 2))),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? MigaColors.primary : MigaColors.textSecondary),
      ),
    ),
  );
}
