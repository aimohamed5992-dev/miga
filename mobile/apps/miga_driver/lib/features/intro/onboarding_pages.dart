import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

const driverOnboardingPages = [
  OnboardingPageData(
    image: 'driver_onb_1.png',
    icon: Icons.notifications_active_rounded,
    title: 'استقبل طلبات\nالتوصيل القريبة',
    highlight: 'القريبة',
    body: 'فعّل حالتك وابدأ باستقبال طلبات التوصيل من تجار ميجا القريبين منك.',
    bubbles: [
      OnboardingBubble(icon: Icons.inventory_2_rounded, text: '6 طلبات جديدة', alignment: AlignmentDirectional(-1.05, -.72)),
      OnboardingBubble(
        icon: Icons.near_me_rounded,
        text: 'على بعد 3.2 كم',
        alignment: AlignmentDirectional(1.05, .72),
        color: MigaColors.primary,
      ),
    ],
  ),
  OnboardingPageData(
    image: 'driver_onb_2.png',
    icon: Icons.route_rounded,
    title: 'استلم من التاجر\nوسلّم للعميل',
    highlight: 'وسلّم للعميل',
    body: 'عنوان العميل واضح بالمنطقة والمدينة والحي، وحدّث الحالة: تم الاستلام ← في الطريق ← تم التسليم.',
    bubbles: [
      OnboardingBubble(
        icon: Icons.storefront_rounded,
        text: 'تم الاستلام',
        alignment: AlignmentDirectional(-1.05, -.72),
        color: MigaColors.info,
      ),
      OnboardingBubble(
        icon: Icons.phone_in_talk_rounded,
        text: 'تواصل مع العميل',
        alignment: AlignmentDirectional(1.05, .72),
        color: MigaColors.primary,
      ),
    ],
  ),
  OnboardingPageData(
    image: 'driver_onb_3.png',
    icon: Icons.account_balance_wallet_rounded,
    title: 'اكسب أكثر\nمع كل توصيلة',
    highlight: 'مع كل توصيلة',
    body: 'تابع دخلك اليومي وسجل توصيلاتك كاملًا، واسحب أرباحك بسهولة.',
    bubbles: [
      OnboardingBubble(
        icon: Icons.payments_rounded,
        text: '+ 320 ر.س اليوم',
        alignment: AlignmentDirectional(-1.05, -.72),
        color: MigaColors.success,
      ),
      OnboardingBubble(icon: Icons.star_rounded, text: 'تقييم 4.9', alignment: AlignmentDirectional(1.05, .72), color: MigaColors.gold),
    ],
  ),
];
