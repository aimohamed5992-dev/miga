import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import 'address_store.dart';
import 'cart_store.dart';
import 'favorites_store.dart';
import 'services.dart';

/// Signed-in customer. Decides the first screen on launch and handles sign-out / expired sessions.
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  Account? account;

  bool get isSignedIn => account != null;

  /// Restores a saved session. Returns false when the user must sign in.
  Future<bool> restore() async {
    if (!await AppServices.api.client.hasSession && !await _devSignIn()) return false;
    try {
      account = await AppServices.api.auth.me();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // Offline with a saved session: let the user in; screens show their own offline states.
      return e.isNetwork;
    }
  }

  /// Development only: `--dart-define=MIGA_DEV_PHONE=05XXXXXXXX` signs in with the code the dev server returns.
  /// Does nothing against production (the API never exposes codes there).
  static const _devPhone = String.fromEnvironment('MIGA_DEV_PHONE');

  /// Set on the first explicit logout so the dev auto sign-in never undoes it.
  static const _devSignInOffKey = 'miga.devSignInOff';

  Future<bool> _devSignIn() async {
    if (_devPhone.isEmpty || await AppServices.api.client.tokens.read(_devSignInOffKey) != null) return false;
    try {
      final sent = await AppServices.api.auth.sendOtp(_devPhone);
      if (sent.devCode == null) return false;
      await AppServices.api.auth.verifyOtp(sent.phone, sent.devCode!, UserType.customer);
      return true;
    } on ApiException {
      return false;
    }
  }

  void signedIn(Account a) {
    account = a;
    notifyListeners();
    CartStore.instance.refresh();
    AddressStore.instance.load();
    FavoritesStore.instance.load().ignore();
  }

  Future<void> signOut() async {
    await AppServices.api.client.tokens.write(_devSignInOffKey, '1');
    await AppServices.api.auth.logout();
    _reset();
  }

  /// Called by the API client when the refresh token is rejected.
  void expired(Widget Function() loginPage) {
    _reset();
    AppServices.navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => loginPage()), (_) => false);
  }

  void _reset() {
    FavoritesStore.instance.reset();
    account = null;
    CartStore.instance.reset();
    AddressStore.instance.reset();
    notifyListeners();
  }
}
