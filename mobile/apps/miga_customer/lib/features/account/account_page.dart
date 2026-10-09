import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/address_store.dart';
import '../../core/favorites_store.dart';
import '../../core/services.dart';
import '../../core/session.dart';
import '../../main.dart';
import '../addresses/addresses_page.dart';
import '../notifications/notifications_page.dart';
import 'favorites_page.dart';
import 'payment_methods_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  /// Current + past orders for the header stats.
  final Future<List<OrderSummary>> _orders = Future.wait([
    AppServices.api.customer.orders(),
    AppServices.api.customer.orders(past: true),
  ]).then((pages) => [...pages[0].items, ...pages[1].items]).catchError((Object _) => <OrderSummary>[]);

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('خروج', style: TextStyle(color: MigaColors.error))),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    try {
      await Session.instance.signOut();
    } catch (_) {
      // Tokens are cleared locally even if the server call fails.
    }
    if (mounted) migaGoRoot(context, MigaCustomerApp.launchPage());
  }

  Future<void> _editProfile(Account? account) async {
    final name = TextEditingController(text: account?.fullName);
    final email = TextEditingController(text: account?.email);
    var saving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, set) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('تعديل البيانات', style: Theme.of(c).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      MigaTextField(label: 'الاسم الكامل', hint: 'الاسم', controller: name, prefixIcon: Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                      MigaTextField(
                        label: 'البريد الإلكتروني (اختياري)',
                        hint: 'name@example.com',
                        controller: email,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      MigaButton(
                        label: 'حفظ',
                        loading: saving,
                        onPressed: () async {
                          set(() => saving = true);
                          try {
                            final a = await AppServices.api.auth.completeCustomerProfile(name.text.trim(), email: email.text.trim());
                            Session.instance.account = a;
                            if (c.mounted) Navigator.pop(c, true);
                          } catch (e) {
                            if (c.mounted) {
                              set(() => saving = false);
                              showMigaError(c, e);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
          ),
    );
    if (saved == true && mounted) {
      setState(() {});
      showMigaMessage(context, 'تم حفظ بياناتك');
    }
  }

  void _language(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder:
        (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text('اللغة', style: Theme.of(c).textTheme.titleLarge)),
              ListTile(
                leading: const Icon(Icons.check_circle_rounded, color: MigaColors.primary),
                title: const Text('العربية'),
                onTap: () => Navigator.pop(c),
              ),
              ListTile(
                enabled: false,
                leading: const Icon(Icons.radio_button_unchecked_rounded),
                title: const Text('English'),
                subtitle: const Text('قريبًا'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final account = Session.instance.account;
    final name = (account?.fullName.isNotEmpty ?? false) ? account!.fullName : 'عميل ميجا';
    final initials = name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p.characters.first).join(' ');
    final e164 = account?.phoneNumber ?? '';
    final phone = e164.startsWith('+966') ? '0${e164.substring(4)}' : e164;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: MigaColors.primaryGradient,
              borderRadius: MigaRadius.all(MigaRadius.xl),
              boxShadow: MigaShadows.glow(),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), shape: BoxShape.circle),
                      child: Text(initials, style: t.titleLarge?.copyWith(color: Colors.white)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: t.titleLarge?.copyWith(color: Colors.white)),
                          Text(phone, style: t.bodyMedium?.copyWith(color: Colors.white70), textDirection: TextDirection.ltr),
                        ],
                      ),
                    ),
                    MigaIconButton(
                      icon: Icons.edit_outlined,
                      background: Colors.white.withValues(alpha: .2),
                      color: Colors.white,
                      onTap: () => _editProfile(account),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<List<OrderSummary>>(
                        future: _orders,
                        builder: (context, snap) {
                          final orders = snap.data ?? const <OrderSummary>[];
                          final spent = orders
                              .where((o) => o.status != CampaignOrderStatus.refunded && o.status != CampaignOrderStatus.cancelled)
                              .fold<double>(0, (s, o) => s + o.totalAmount);
                          return Row(
                            children: [
                              _HeaderStat(value: '${orders.length}', label: 'طلبات'),
                              _HeaderStat(value: '${orders.map((o) => o.campaignId).toSet().length}', label: 'حملات شاركت فيها'),
                              _HeaderStat(value: MigaFormat.money(spent), label: 'مشترياتك'),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              ListenableBuilder(
                listenable: AddressStore.instance,

                builder:
                    (context, _) => MenuTile(
                      icon: Icons.location_on_outlined,

                      title: 'عناويني',

                      subtitle: '${AddressStore.instance.items.length} عنوان محفوظ',

                      onTap: () => migaPush(context, const AddressesPage()),
                    ),
              ),
              MenuTile(
                icon: Icons.credit_card_rounded,
                title: 'طرق الدفع',
                subtitle: 'مدى، Apple Pay، بطاقة ائتمانية، STC Pay',
                onTap: () => migaPush(context, const PaymentMethodsPage()),
              ),
              ListenableBuilder(
                listenable: FavoritesStore.instance,
                builder:
                    (context, _) => MenuTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'الحملات المفضلة',
                      subtitle: FavoritesStore.instance.items.isEmpty ? null : '${FavoritesStore.instance.items.length} حملة',
                      onTap: () => migaPush(context, const FavoritesPage()),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            children: [
              MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'الإشعارات',
                onTap: () => migaPush(context, const NotificationsPage()),
              ),
              MenuTile(icon: Icons.language_rounded, title: 'اللغة', subtitle: 'العربية', onTap: () => _language(context)),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            children: [
              MenuTile(
                icon: Icons.support_agent_rounded,
                title: 'المساعدة والدعم',
                onTap: () => migaPush(context, MigaSupportPage(loadConfig: AppServices.api.catalog.config, faqs: MigaContent.customerFaqs)),
              ),
              MenuTile(
                icon: Icons.help_outline_rounded,
                title: 'كيف تعمل ميجا؟',
                onTap:
                    () => migaPush(
                      context,
                      const MigaInfoPage(
                        title: 'كيف تعمل ميجا؟',
                        intro: 'ميجا منصة شراء جماعي: كلما زاد عدد المشتركين في الحملة حصلتم جميعًا على سعر الجملة.',
                        sections: MigaContent.howItWorks,
                      ),
                    ),
              ),
              MenuTile(
                icon: Icons.description_outlined,
                title: 'الشروط والأحكام',
                onTap:
                    () => migaPush(
                      context,
                      const MigaInfoPage(title: 'الشروط والأحكام', sections: MigaContent.customerTerms, updated: MigaContent.updated),
                    ),
              ),
              MenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'سياسة الخصوصية',
                onTap:
                    () => migaPush(
                      context,
                      const MigaInfoPage(title: 'سياسة الخصوصية', sections: MigaContent.privacyPolicy, updated: MigaContent.updated),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Group(children: [MenuTile(icon: Icons.logout_rounded, title: 'تسجيل الخروج', danger: true, onTap: _logout)]),
          const SizedBox(height: 20),
          Center(child: Text('ميجا • الإصدار 1.0.0', style: t.labelSmall)),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: MigaRadius.all(MigaRadius.md)),
        child: Column(
          children: [
            FittedBox(child: Text(value, style: t.titleMedium?.copyWith(color: Colors.white))),
            Text(label, style: t.labelSmall?.copyWith(color: Colors.white70), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MigaCard(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (final (i, c) in children.indexed) ...[c, if (i < children.length - 1) const Divider(indent: 64)],
      ],
    ),
  );
}
