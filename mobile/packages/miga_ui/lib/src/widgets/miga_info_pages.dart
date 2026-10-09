import 'package:flutter/material.dart';
import 'package:miga_core/miga_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_common.dart';
import 'miga_feedback.dart';
import 'miga_states.dart';

/// Long-form information page (terms, privacy, agreements, how it works): titled sections in cards.
class MigaInfoPage extends StatelessWidget {
  const MigaInfoPage({super.key, required this.title, required this.sections, this.intro, this.accent = MigaColors.primary, this.updated});
  final String title;
  final String? intro;
  final List<(String heading, String body)> sections;
  final Color accent;
  final String? updated;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (intro != null) ...[
            Text(intro!, style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary, height: 1.7)),
            const SizedBox(height: 16),
          ],
          for (final (i, (heading, body)) in sections.indexed) ...[
            MigaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: accent.withValues(alpha: .1), shape: BoxShape.circle),
                        child: Text('${i + 1}', style: t.labelLarge?.copyWith(color: accent)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(heading, style: t.titleMedium)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(body, style: t.bodyMedium?.copyWith(height: 1.8, color: MigaColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (updated != null) Center(child: Text('آخر تحديث: $updated', style: t.labelSmall)),
        ],
      ),
    );
  }
}

/// Help & support: contact buttons (phone · WhatsApp · email from the server's settings) and role-specific FAQs.
class MigaSupportPage extends StatelessWidget {
  const MigaSupportPage({
    super.key,
    required this.loadConfig,
    required this.faqs,
    this.accent = MigaColors.primary,
    this.title = 'المساعدة والدعم',
  });
  final Future<AppConfig> Function() loadConfig;
  final List<(String q, String a)> faqs;
  final Color accent;
  final String title;

  Future<void> _open(BuildContext context, Uri uri, String fallback) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) showMigaMessage(context, fallback, icon: Icons.info_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MigaAsync<AppConfig>(
        load: loadConfig,
        builder:
            (context, c) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                Text('تواصل معنا', style: t.titleMedium),
                const SizedBox(height: 10),
                if (!c.hasSupportContact)
                  MigaCard(child: Text('قنوات التواصل غير متاحة حاليًا، راجع الأسئلة الشائعة بالأسفل.', style: t.bodySmall))
                else
                  MigaCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        if (c.supportWhatsApp != null)
                          MenuTile(
                            icon: Icons.chat_rounded,
                            title: 'واتساب',
                            subtitle: 'رد خلال دقائق في أوقات العمل',
                            onTap: () => _open(context, Uri.parse('https://wa.me/${c.supportWhatsApp}'), 'واتساب: ${c.supportWhatsApp}'),
                          ),
                        if (c.supportPhone != null)
                          MenuTile(
                            icon: Icons.phone_rounded,
                            title: 'اتصل بنا',
                            subtitle: c.supportPhone,
                            onTap: () => migaCall(context, c.supportPhone),
                          ),
                        if (c.supportEmail != null)
                          MenuTile(
                            icon: Icons.email_outlined,
                            title: 'البريد الإلكتروني',
                            subtitle: c.supportEmail,
                            onTap: () => _open(context, Uri(scheme: 'mailto', path: c.supportEmail), 'البريد: ${c.supportEmail}'),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text('الأسئلة الشائعة', style: t.titleMedium),
                const SizedBox(height: 10),
                MigaCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Column(
                      children: [
                        for (final (q, a) in faqs)
                          ExpansionTile(
                            iconColor: accent,
                            title: Text(q, style: t.titleSmall),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(a, style: t.bodyMedium?.copyWith(height: 1.7, color: MigaColors.textSecondary))],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: accent.withValues(alpha: .06), borderRadius: MigaRadius.all(MigaRadius.md)),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: accent),
                      const SizedBox(width: 10),
                      Expanded(child: Text('أوقات الدعم: يوميًا من 9 صباحًا حتى 11 مساءً', style: t.bodySmall)),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
