import 'package:flutter/foundation.dart';
import 'package:miga_ui/miga_ui.dart';

import 'services.dart';

/// Saved addresses from the API (Region → City → District + name + phone).
class AddressStore extends ChangeNotifier {
  AddressStore._();
  static final instance = AddressStore._();

  List<Address> items = [];
  bool loaded = false;

  Address? get defaultAddress => items.where((a) => a.isDefault).firstOrNull ?? items.firstOrNull;

  Future<void> load() async {
    items = await AppServices.api.customer.addresses();
    loaded = true;
    notifyListeners();
  }

  Future<Address> save({
    String? id,
    required String addressName,
    required String regionId,
    required String cityId,
    required String districtId,
    required String phoneNumber,
    String? details,
    bool isDefault = false,
  }) async {
    final saved = await AppServices.api.customer.saveAddress(
      id: id,
      addressName: addressName,
      regionId: regionId,
      cityId: cityId,
      districtId: districtId,
      phoneNumber: phoneNumber,
      details: details,
      isDefault: isDefault,
    );
    await load();
    return saved;
  }

  Future<void> remove(String id) async {
    await AppServices.api.customer.deleteAddress(id);
    await load();
  }

  Future<void> makeDefault(String id) async {
    await AppServices.api.customer.makeDefaultAddress(id);
    await load();
  }

  void reset() {
    items = [];
    loaded = false;
    notifyListeners();
  }
}
