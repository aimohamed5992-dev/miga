import 'package:flutter/foundation.dart';
import 'package:miga_ui/miga_ui.dart';

import 'services.dart';

/// Server cart (one cart, grouped by store). Mutations return the fresh cart from the API.
/// Errors (limits, already joined, campaign ended…) are thrown as [ApiException] for the screen to show.
class CartStore extends ChangeNotifier {
  CartStore._();
  static final instance = CartStore._();

  CartView view = CartView.empty;
  bool loading = false;

  int get count => view.itemsCount;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      view = await AppServices.api.customer.cart();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addCampaign(Campaign c, int qty) =>
      _apply(AppServices.api.customer.addToCart(c.product.id, campaignId: c.id, quantity: qty));

  Future<void> addProduct(Product p, int qty) => _apply(AppServices.api.customer.addToCart(p.id, quantity: qty));

  Future<void> setQuantity(String lineId, int qty) => _apply(AppServices.api.customer.setCartQuantity(lineId, qty));

  Future<void> remove(String lineId) => _apply(AppServices.api.customer.removeCartLine(lineId));

  Future<void> clear() async {
    await AppServices.api.customer.clearCart();
    view = CartView.empty;
    notifyListeners();
  }

  void reset() {
    view = CartView.empty;
    notifyListeners();
  }

  Future<void> _apply(Future<CartView> call) async {
    view = await call;
    notifyListeners();
  }
}
