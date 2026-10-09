import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_core/miga_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/miga_colors.dart';

/// Arabic, user-facing text for any error (API messages are already Arabic).
String migaErrorText(Object error) => error is ApiException ? error.message : 'حدث خطأ غير متوقع، حاول مرة أخرى';

void showMigaError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: MigaColors.error,
        content: Row(
          children: [
            Icon(error is ApiException && error.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(migaErrorText(error))),
          ],
        ),
      ),
    );
}

void showMigaMessage(BuildContext context, String message, {IconData icon = Icons.check_circle_rounded}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Row(children: [Icon(icon, color: MigaColors.success), const SizedBox(width: 10), Expanded(child: Text(message))])),
    );
}

/// Opens the phone dialer. Where calling isn't possible (simulator, tablet) the number is copied instead.
Future<void> migaCall(BuildContext context, String? phone) async {
  if (phone == null || phone.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
  try {
    if (await launchUrl(uri)) return;
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: phone));
  if (context.mounted) showMigaMessage(context, 'تم نسخ الرقم $phone', icon: Icons.phone_rounded);
}
