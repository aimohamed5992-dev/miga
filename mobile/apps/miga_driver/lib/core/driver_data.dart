import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:miga_ui/miga_ui.dart';

import 'location_reporter.dart';
import 'services.dart';

/// The signed-in driver's live state from the API: home summary (availability, today's numbers, profile),
/// open requests in the driver's city and in-progress deliveries. Requests refresh every 20 s while online.
/// Mutations call the API, then reload; errors surface as [ApiException] for the screen to show.
class DriverData extends ChangeNotifier {
  DriverData._();
  static final instance = DriverData._();

  DriverApi get _api => AppServices.api.driver;

  DriverHome? home;
  List<DeliveryRequest> requests = [];
  List<DriverDelivery> active = [];
  bool loading = false;
  Object? error;
  Timer? _poll;

  bool get online => home?.isAvailable ?? false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _fetch();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
    _poll ??= Timer.periodic(const Duration(seconds: 20), (_) => refresh());
  }

  /// Silent background refresh (keeps the last data on failure).
  Future<void> refresh() async {
    try {
      await _fetch();
      error = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _fetch() async {
    final results = await Future.wait([_api.home(), _api.deliveries()]);
    home = results[0] as DriverHome;
    active = results[1] as List<DriverDelivery>;
    requests = home!.isVerified && home!.isAvailable ? await _api.requests() : [];
    // Share the position while on duty: online, or carrying a delivery.
    if (home!.isVerified && (home!.isAvailable || active.isNotEmpty)) {
      LocationReporter.instance.start();
    } else {
      LocationReporter.instance.stop();
    }
  }

  Future<void> setOnline(bool v) async {
    await _api.setAvailability(v);
    await refresh();
  }

  /// Hides a request locally — it stays available to other drivers.
  void decline(DeliveryRequest r) {
    requests = requests.where((x) => x.id != r.id).toList();
    notifyListeners();
  }

  Future<DriverDelivery> accept(String id) async {
    final d = await _api.accept(id);
    await refresh();
    return d;
  }

  /// Runs one step of the delivery flow, then refreshes home/active lists.
  Future<DriverDelivery> step(Future<DriverDelivery> Function(DriverApi api) call) async {
    final d = await call(_api);
    await refresh();
    return d;
  }

  Future<void> release(String id) async {
    await _api.release(id);
    await refresh();
  }

  void reset() {
    LocationReporter.instance.stop();
    _poll?.cancel();
    _poll = null;
    home = null;
    requests = [];
    active = [];
    notifyListeners();
  }
}
