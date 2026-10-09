import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import '../../core/services.dart';
import '../../core/session.dart';
import '../../main.dart';
import '../categories/categories_page.dart';
import '../earnings/earnings_page.dart';
import '../stores/stores_page.dart';
import 'business_page.dart';
import 'reports_page.dart';

class MerchantAccountPage extends StatefulWidget {
  const MerchantAccountPage({super.key});

  @override
  State<MerchantAccountPage> createState() => _MerchantAccountPageState();
}

class _MerchantAccountPageState extends State<MerchantAccountPage> {
  MerchantEarnings? _earnings;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      final e = await AppServices.api.merchant.earnings();
      if (mounted) setState(() => _earnings = e);
    } catch (_) {
      // The balance line is a hint only; the wallet page shows the error with retry.
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل تريد تسجيل الخروج من حساب التاجر؟'),
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
    if (context.mounted) migaGoRoot(context, MigaMerchantApp.launchPage());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = MerchantData.instance;
    final account = Session.instance.account;
    final owner = account?.fullName ?? '';
    final phone = account?.phoneNumber.replaceFirst('+966', '0') ?? '';
    final e = _earnings;
    Widget group(List<Widget> children) => MigaCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[c, if (i < children.length - 1) const Divider(indent: 64)],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B3A5E), MigaColors.merchantAccent],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: MigaRadius.all(MigaRadius.xl),
              ),
              child: Row(
                children: [
                  MigaAvatar(name: owner.isEmpty ? 'م' : owner, size: 58, color: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(owner, style: t.titleMedium?.copyWith(color: Colors.white)),
                        Text(phone, textDirection: TextDirection.ltr, style: t.bodySmall?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF7CC4FF), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              Session.instance.isVerified ? 'تاجر موثّق' : 'قيد المراجعة',
                              style: t.labelSmall?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            group([
              MenuTile(
                icon: Icons.storefront_outlined,
                title: 'متاجري',
                subtitle: '${data.stores.length} متاجر',
                onTap: () => migaPush(context, const StoresPage()),
              ),
              MenuTile(icon: Icons.folder_open_rounded, title: 'تصنيفات المنتجات', onTap: () => migaPush(context, const CategoriesPage())),
              MenuTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'المحفظة والأرباح',
                subtitle: e == null ? null : 'الرصيد المتاح ${MigaFormat.money(e.available)}',
                onTap: () async {
                  await migaPush(context, const EarningsPage());
                  _loadEarnings();
                },
              ),
              MenuTile(icon: Icons.bar_chart_rounded, title: 'التقارير', onTap: () => migaPush(context, const ReportsPage())),
            ]),
            const SizedBox(height: 12),
            group([
              MenuTile(
                icon: Icons.business_center_outlined,
                title: 'بيانات النشاط التجاري',
                onTap: () => migaPush(context, const BusinessPage()),
              ),
              MenuTile(
                icon: Icons.account_balance_outlined,
                title: 'الحساب البنكي',
                subtitle: e?.ibanMasked ?? 'لم يُضف بعد',
                onTap: () async {
                  await migaPush(context, const EarningsPage());
                  _loadEarnings();
                },
              ),
              MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'الإشعارات',
                onTap:
                    () => migaPush(
                      context,
                      MigaNotificationsPage(
                        api: AppServices.api.notifications,
                        accent: MigaColors.merchantAccent,
                        emptyMessage: 'سنخبرك فور اكتمال حملاتك ووصول الطلبات المجمّعة',
                      ),
                    ),
              ),
            ]),
            const SizedBox(height: 12),
            group([
              MenuTile(
                icon: Icons.support_agent_rounded,
                title: 'دعم التجار',
                onTap:
                    () => migaPush(
                      context,
                      MigaSupportPage(
                        title: 'دعم التجار',
                        loadConfig: AppServices.api.catalog.config,
                        faqs: MigaContent.merchantFaqs,
                        accent: MigaColors.merchantAccent,
                      ),
                    ),
              ),
              MenuTile(
                icon: Icons.description_outlined,
                title: 'اتفاقية التاجر',
                onTap:
                    () => migaPush(
                      context,
                      const MigaInfoPage(
                        title: 'اتفاقية التاجر',
                        sections: MigaContent.merchantAgreement,
                        accent: MigaColors.merchantAccent,
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
                        accent: MigaColors.merchantAccent,
                        updated: MigaContent.updated,
                      ),
                    ),
              ),
            ]),
            const SizedBox(height: 12),
            group([MenuTile(icon: Icons.logout_rounded, title: 'تسجيل الخروج', danger: true, onTap: () => _logout(context))]),
            const SizedBox(height: 20),
            Center(child: Text('ميجا للتجار • الإصدار 1.0.0', style: t.labelSmall)),
          ],
        ),
      ),
    );
  }
}
