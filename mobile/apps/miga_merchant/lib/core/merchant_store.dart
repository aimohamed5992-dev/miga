import 'package:flutter/foundation.dart';
import 'package:miga_ui/miga_ui.dart';

import 'services.dart';

/// The signed-in merchant's catalog from the API: Stores → ProductCategories → Products, for the current store.
/// Mutations call the API, then reload; errors surface as [ApiException] for the screen to show.
class MerchantData extends ChangeNotifier {
  MerchantData._();
  static final instance = MerchantData._();

  MerchantApi get _api => AppServices.api.merchant;

  List<Store> _stores = [];
  String? _currentStoreId;
  List<ProductCategoryNode> _tree = [];
  List<Product> _products = [];
  bool loading = false;
  Object? error;

  List<Store> get stores => List.unmodifiable(_stores);
  bool get hasStores => _stores.isNotEmpty;
  Store get currentStore => _stores.firstWhere((s) => s.id == _currentStoreId, orElse: () => _stores.first);
  bool isStoreActive(String id) => _stores.firstWhere((s) => s.id == id).status == StoreStatus.active;

  /// Flat list (main categories followed by their sub-categories) for pickers and filters.
  List<ProductCategory> get categories => [
    for (final c in _tree) ...[
      ProductCategory(id: c.id, storeId: currentStore.id, nameAr: c.nameAr),
      for (final ch in c.children) ProductCategory(id: ch.id, storeId: currentStore.id, nameAr: ch.nameAr, parentId: c.id),
    ],
  ];
  List<ProductCategory> get rootCategories => categories.where((c) => c.parentId == null).toList();
  List<ProductCategory> childrenOf(String id) => categories.where((c) => c.parentId == id).toList();
  String categoryName(String id) => categories.where((c) => c.id == id).firstOrNull?.nameAr ?? '—';
  String categoryPath(ProductCategory c) => c.parentId == null ? c.nameAr : '${categoryName(c.parentId!)} › ${c.nameAr}';

  List<Product> get products => List.unmodifiable(_products);
  int productsIn(String categoryId) =>
      _products.where((p) => p.categoryId == categoryId || childrenOf(categoryId).any((c) => c.id == p.categoryId)).length;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _stores = await _api.stores();
      if (_stores.isNotEmpty && !_stores.any((s) => s.id == _currentStoreId)) _currentStoreId = _stores.first.id;
      await _loadStoreData();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadStoreData() async {
    if (_stores.isEmpty) return;
    final id = currentStore.id;
    final results = await Future.wait([_api.categories(id), _api.products(id)]);
    _tree = results[0] as List<ProductCategoryNode>;
    _products = results[1] as List<Product>;
  }

  Future<void> switchStore(String id) async {
    _currentStoreId = id;
    notifyListeners();
    await _reloadStore();
  }

  Future<void> setStoreActive(String id, bool active) async {
    await _api.setStoreActive(id, active);
    _stores = await _api.stores();
    notifyListeners();
  }

  Future<void> saveStore(Store s, {bool isNew = false}) async {
    await _api.saveStore(
      id: isNew ? null : s.id,
      nameAr: s.nameAr,
      storeCategoryId: s.categoryId,
      descriptionAr: s.descriptionAr,
      logoUrl: s.logo.isEmpty ? null : s.logo,
      coverImageUrl: s.cover.isEmpty ? null : s.cover,
      pickupAddress: s.pickupAddress,
      cityId: s.cityId,
    );
    _stores = await _api.stores();
    notifyListeners();
  }

  Future<void> saveCategory(ProductCategory c, {bool isNew = false}) async {
    await _api.saveCategory(currentStore.id, id: isNew ? null : c.id, nameAr: c.nameAr, parentId: c.parentId);
    await _reloadStore();
  }

  Future<void> deleteCategory(String id) async {
    await _api.deleteCategory(currentStore.id, id);
    await _reloadStore();
  }

  Future<void> saveProduct(Product p, {bool isNew = false}) async {
    await _api.saveProduct(
      currentStore.id,
      id: isNew ? null : p.id,
      categoryId: p.categoryId,
      nameAr: p.nameAr,
      descriptionAr: p.descriptionAr,
      price: p.price,
      stockQuantity: p.stockQuantity,
      isActive: p.isActive,
      imageUrls: p.images,
    );
    await _reloadStore();
  }

  Future<void> deleteProduct(String id) async {
    await _api.deleteProduct(currentStore.id, id);
    await _reloadStore();
  }

  Future<void> toggleProduct(Product p, bool active) async {
    await _api.setProductActive(currentStore.id, p.id, active);
    await _reloadStore();
  }

  Future<String> uploadImage(String folder, String filePath) => _api.upload(folder, filePath);

  Future<void> _reloadStore() async {
    await _loadStoreData();
    notifyListeners();
  }

  void reset() {
    _stores = [];
    _tree = [];
    _products = [];
    _currentStoreId = null;
    notifyListeners();
  }
}
