import 'package:flutter/foundation.dart';
import 'package:miga_ui/miga_ui.dart';

import 'services.dart';

/// The customer's saved campaigns (server-side), so hearts stay in sync across screens.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final instance = FavoritesStore._();

  List<Campaign> items = [];
  final Set<String> _ids = {};

  bool contains(String campaignId) => _ids.contains(campaignId);

  Future<List<Campaign>> load() async {
    items = await AppServices.api.customer.favorites();
    _ids
      ..clear()
      ..addAll(items.map((c) => c.id));
    notifyListeners();
    return items;
  }

  /// Optimistic toggle; reverts and rethrows if the server refuses.
  Future<bool> toggle(Campaign c) async {
    final adding = !_ids.contains(c.id);
    adding ? _ids.add(c.id) : _ids.remove(c.id);
    if (!adding) items = items.where((x) => x.id != c.id).toList();
    notifyListeners();
    try {
      adding ? await AppServices.api.customer.addFavorite(c.id) : await AppServices.api.customer.removeFavorite(c.id);
      return adding;
    } catch (_) {
      adding ? _ids.remove(c.id) : _ids.add(c.id);
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    items = [];
    _ids.clear();
    notifyListeners();
  }
}
