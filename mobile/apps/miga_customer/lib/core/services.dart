import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

/// App-wide singletons: the API client and the root navigator (used to return to login when the session expires).
class AppServices {
  AppServices._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final api = MigaApi(ApiClient());
}
