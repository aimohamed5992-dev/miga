import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

/// App-wide singletons: the API client and the root navigator.
class AppServices {
  AppServices._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final api = MigaApi(ApiClient());
}
