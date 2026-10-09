import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

const merchantOnboardingPages = [
  OnboardingPageData(
    image: 'merchant_onb_1.png',
    icon: Icons.campaign_rounded,
    title: 'أطلق حملتك\nفي دقائق',
    highlight: 'في دقائق',
    body: 'حدد المنتج وسعر الحملة والكمية المطلوبة ومدتها، ودع آلاف العملاء يتجمعون على منتجك.',
    bubbles: [
      OnboardingBubble(icon: Icons.inventory_2_rounded, text: 'الهدف: 500 قطعة', alignment: AlignmentDirectional(-1.05, -.72)),
      OnboardingBubble(
        icon: Icons.schedule_rounded,
        text: 'مدة 7 أيام',
        alignment: AlignmentDirectional(1.05, .72),
        color: MigaColors.primary,
      ),
    ],
  ),
  OnboardingPageData(
    image: 'merchant_onb_2.png',
    icon: Icons.all_inbox_rounded,
    title: 'طلب واحد مجمّع\nبدل مئات الطلبات',
    highlight: 'طلب واحد مجمّع',
    body: 'لما تكتمل الحملة يوصلك طلب مجمّع بالكمية الكاملة والمبلغ مدفوع مسبقًا. جهّزه وسلّمه للمندوب.',
    bubbles: [
      OnboardingBubble(
        icon: Icons.task_alt_rounded,
        text: 'اكتملت الحملة',
        alignment: AlignmentDirectional(-1.05, -.72),
        color: MigaColors.success,
      ),
      OnboardingBubble(
        icon: Icons.payments_rounded,
        text: 'مدفوع مسبقًا',
        alignment: AlignmentDirectional(1.05, .72),
        color: MigaColors.primary,
      ),
    ],
  ),
  OnboardingPageData(
    image: 'merchant_onb_3.png',
    icon: Icons.insights_rounded,
    title: 'تابع مبيعاتك\nوأرباحك',
    highlight: 'وأرباحك',
    body: 'لوحة تحكم كاملة لمتاجرك وحملاتك وطلباتك، مع تقارير واضحة للمبيعات والأرباح.',
    bubbles: [
      OnboardingBubble(
        icon: Icons.trending_up_rounded,
        text: '+24% هذا الشهر',
        alignment: AlignmentDirectional(-1.05, -.72),
        color: MigaColors.success,
      ),
      OnboardingBubble(
        icon: Icons.storefront_rounded,
        text: '3 متاجر',
        alignment: AlignmentDirectional(1.05, .72),
        color: MigaColors.primary,
      ),
    ],
  ),
];
