import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import 'driver_data.dart';
import 'services.dart';

/// Signed-in driver: restore on launch, dev auto sign-in, sign-out / expiry.
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  Account? account;

  bool get isVerified => account?.verificationStatus == 'verified';

  /// Development only: `--dart-define=MIGA_DEV_PHONE=0522222222` (the demo driver) signs in with the dev code.
  static const _devPhone = String.fromEnvironment('MIGA_DEV_PHONE');

  Future<bool> restore() async {
    if (!await AppServices.api.client.hasSession && !await _devSignIn()) return false;
    try {
      account = await AppServices.api.auth.me();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      return e.isNetwork;
    }
  }

  /// Set on the first explicit logout so the dev auto sign-in never undoes it.
  static const _devSignInOffKey = 'miga.devSignInOff';

  Future<bool> _devSignIn() async {
    if (_devPhone.isEmpty || await AppServices.api.client.tokens.read(_devSignInOffKey) != null) return false;
    try {
      final sent = await AppServices.api.auth.sendOtp(_devPhone);
      if (sent.devCode == null) return false;
      await AppServices.api.auth.verifyOtp(sent.phone, sent.devCode!, UserType.driver);
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> refresh() async {
    account = await AppServices.api.auth.me();
    notifyListeners();
  }

  void signedIn(Account a) {
    account = a;
    notifyListeners();
    if (a.verificationStatus == 'verified') DriverData.instance.load();
  }

  Future<void> signOut() async {
    await AppServices.api.client.tokens.write(_devSignInOffKey, '1');
    // Going offline first so no new requests are routed to a signed-out driver.
    try {
      if (DriverData.instance.online) await AppServices.api.driver.setAvailability(false);
    } catch (_) {}
    await AppServices.api.auth.logout();
    _reset();
  }

  void expired(Widget Function() loginPage) {
    _reset();
    AppServices.navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => loginPage()), (_) => false);
  }

  void _reset() {
    account = null;
    DriverData.instance.reset();
    notifyListeners();
  }
}
