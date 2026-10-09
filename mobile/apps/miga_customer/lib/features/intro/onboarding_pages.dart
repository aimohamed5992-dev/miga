import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

const customerOnboardingPages = [
  OnboardingPageData(
    image: 'customer_onb_1.png',
    icon: Icons.groups_rounded,
    title: 'اشترِ مع الجماعة\nبسعر الجملة',
    highlight: 'بسعر الجملة',
    body: 'انضم لحملات تجار الجملة، وكل ما زاد عدد المشتركين وصلك المنتج بسعر أقل بكثير من السوق.',
    bubbles: [
      OnboardingBubble(icon: Icons.trending_down_rounded, text: 'وفّر حتى 60%', alignment: AlignmentDirectional(-1.05, -.75)),
      OnboardingBubble(
        icon: Icons.local_offer_rounded,
        text: '20 ر.س بدل 50',
        alignment: AlignmentDirectional(1.05, .7),
        color: MigaColors.success,
      ),
    ],
  ),
  OnboardingPageData(
    image: 'customer_onb_2.png',
    icon: Icons.donut_large_rounded,
    title: 'تابع الحملة\nحتى تكتمل',
    highlight: 'حتى تكتمل',
    body: 'ادفع بأمان واحجز كميتك، وتابع عدد المشاركين لحظة بلحظة. ولو ما اكتملت الحملة يرجع لك مبلغك كاملاً.',
    bubbles: [
      OnboardingBubble(icon: Icons.people_alt_rounded, text: '73 / 100 قطعة', alignment: AlignmentDirectional(-1.05, -.7)),
      OnboardingBubble(
        icon: Icons.verified_user_rounded,
        text: 'استرداد مضمون',
        alignment: AlignmentDirectional(1.05, .72),
        color: MigaColors.info,
      ),
    ],
  ),
  OnboardingPageData(
    image: 'customer_onb_3.png',
    icon: Icons.local_shipping_rounded,
    title: 'يوصلك طلبك\nلباب بيتك',
    highlight: 'لباب بيتك',
    body: 'بمجرد اكتمال الحملة يجهّز التاجر الطلب ويوصله المندوب لعنوانك، وتقدر تتابع حالته خطوة بخطوة.',
    bubbles: [
      OnboardingBubble(icon: Icons.location_on_rounded, text: 'الرياض، النرجس', alignment: AlignmentDirectional(-1.05, -.72)),
      OnboardingBubble(
        icon: Icons.check_circle_rounded,
        text: 'تم التسليم',
        alignment: AlignmentDirectional(1.05, .72),
        color: MigaColors.success,
      ),
    ],
  ),
];
