import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      MigaNotificationsPage(api: AppServices.api.notifications, emptyMessage: 'سنخبرك فور اكتمال حملاتك أو تحديث طلباتك');
}
