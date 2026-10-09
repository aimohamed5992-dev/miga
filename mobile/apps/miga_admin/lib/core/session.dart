import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import 'services.dart';

/// Signed-in admin: restore on load, dev auto sign-in, sign-out / expiry.
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  Account? account;

  /// Development only: `--dart-define=MIGA_DEV_PHONE=0500000000` signs in with the server's dev code.
  static const _devPhone = String.fromEnvironment('MIGA_DEV_PHONE');

  Future<bool> restore() async {
    if (!await AppServices.api.client.hasSession && !await _devSignIn()) return false;
    try {
      final a = await AppServices.api.auth.me();
      if (a.userType != UserType.admin) {
        await signOut();
        return false;
      }
      account = a;
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<bool> _devSignIn() async {
    if (_devPhone.isEmpty) return false;
    try {
      final sent = await AppServices.api.auth.sendOtp(_devPhone);
      if (sent.devCode == null) return false;
      await AppServices.api.auth.verifyOtp(sent.phone, sent.devCode!, UserType.admin);
      return true;
    } on ApiException {
      return false;
    }
  }

  void signedIn(Account a) {
    account = a;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await AppServices.api.auth.logout();
    } catch (_) {
      // Tokens are cleared locally even when the server is unreachable.
    }
    account = null;
    notifyListeners();
  }

  void expired(Widget Function() loginPage) {
    account = null;
    notifyListeners();
    AppServices.navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => loginPage()), (_) => false);
  }
}
