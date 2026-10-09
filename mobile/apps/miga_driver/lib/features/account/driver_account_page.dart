import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/driver_data.dart';
import '../../core/services.dart';
import '../../core/session.dart';
import '../../main.dart';
import '../auth/driver_auth.dart';
import 'driver_profile_sheets.dart';

class DriverAccountPage extends StatelessWidget {
  const DriverAccountPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('لن تصلك طلبات جديدة بعد تسجيل الخروج.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('خروج', style: TextStyle(color: MigaColors.error))),
            ],
          ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await Session.instance.signOut();
    } catch (_) {
      // Tokens are cleared locally even when the server is unreachable.
    }
    if (context.mounted) migaGoRoot(context, MigaDriverApp.launchPage());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: DriverData.instance, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget group(List<Widget> children) => MigaCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[c, if (i < children.length - 1) const Divider(indent: 64)],
        ],
      ),
    );
    final account = Session.instance.account;
    final name = account?.fullName ?? '';
    final phone = account?.phoneNumber.replaceFirst('+966', '0') ?? '';
    final home = DriverData.instance.home;
    final verified = Session.instance.isVerified;
    final vehicle = [home?.vehicleModel, home?.plateNumber].where((x) => x != null && x.isNotEmpty).join(' • ');
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: RefreshIndicator(
        onRefresh: DriverData.instance.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            MigaCard(
              child: Column(
                children: [
                  MigaAvatar(name: name.isEmpty ? 'ك' : name, size: 76, color: MigaColors.driverAccent),
                  const SizedBox(height: 10),
                  Text(name, style: t.titleLarge),
                  Text(phone, style: t.bodySmall, textDirection: TextDirection.ltr),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusChip('${(home?.rating ?? 5).toStringAsFixed(1)} تقييم', tone: StatusTone.warning, icon: Icons.star_rounded),
                      const SizedBox(width: 8),
                      verified
                          ? const StatusChip('حساب موثّق', tone: StatusTone.success, icon: Icons.verified_rounded)
                          : const StatusChip('قيد المراجعة', tone: StatusTone.warning, icon: Icons.hourglass_top_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MigaCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MigaColors.driverAccent.withValues(alpha: .1),
                      borderRadius: MigaRadius.all(MigaRadius.md),
                    ),
                    child: Icon(vehicleIcon(home?.vehicleType), color: MigaColors.driverAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المركبة • ${vehicleLabel(home?.vehicleType)}', style: t.labelSmall),
                        Text(vehicle.isEmpty ? '—' : vehicle, style: t.titleSmall),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => editVehicle(context), child: const Text('تعديل')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            group([
              MenuTile(
                icon: Icons.location_city_outlined,
                title: 'مدينة العمل',
                subtitle: home?.cityName ?? '—',
                onTap: () => changeWorkCity(context),
              ),
              MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'الإشعارات',
                onTap:
                    () => migaPush(
                      context,
                      MigaNotificationsPage(
                        api: AppServices.api.notifications,
                        accent: MigaColors.driverAccent,
                        emptyMessage: 'سنخبرك فور وصول طلبات توصيل جديدة',
                      ),
                    ),
              ),
            ]),
            const SizedBox(height: 12),
            group([
              MenuTile(
                icon: Icons.support_agent_rounded,
                title: 'دعم الكباتن',
                onTap:
                    () => migaPush(
                      context,
                      MigaSupportPage(
                        title: 'دعم الكباتن',
                        loadConfig: AppServices.api.catalog.config,
                        faqs: MigaContent.driverFaqs,
                        accent: MigaColors.driverAccent,
                      ),
                    ),
              ),
              MenuTile(
                icon: Icons.description_outlined,
                title: 'شروط العمل',
                onTap:
                    () => migaPush(
                      context,
                      const MigaInfoPage(
                        title: 'شروط العمل',
                        sections: MigaContent.driverTerms,
                        accent: MigaColors.driverAccent,
                        updated: MigaContent.updated,
                      ),
                    ),
              ),
              MenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'سياسة الخصوصية',
                onTap:
                    () => migaPush(
                      context,
                      const MigaInfoPage(
                        title: 'سياسة الخصوصية',
                        sections: MigaContent.privacyPolicy,
                        accent: MigaColors.driverAccent,
                        updated: MigaContent.updated,
                      ),
                    ),
              ),
            ]),
            const SizedBox(height: 12),
            group([MenuTile(icon: Icons.logout_rounded, title: 'تسجيل الخروج', danger: true, onTap: () => _logout(context))]),
            const SizedBox(height: 20),
            Center(child: Text('ميجا كابتن • الإصدار 1.0.0', style: t.labelSmall)),
          ],
        ),
      ),
    );
  }
}
