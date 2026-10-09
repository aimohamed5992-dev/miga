/// Formatting helpers for prices, counts and countdowns (Arabic UI).
class MigaFormat {
  MigaFormat._();

  static String money(num v, {bool symbol = true}) {
    final fixed = v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final out = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    return symbol ? '$out ر.س' : out;
  }

  static String countdown(Duration d) {
    if (d.isNegative) return 'انتهت';
    if (d.inDays >= 1) return '${d.inDays} يوم ${d.inHours % 24} س';
    if (d.inHours >= 1) return '${d.inHours} س ${d.inMinutes % 60} د';
    return '${d.inMinutes} دقيقة';
  }

  static String timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} د';
    if (d.inHours < 24) return 'منذ ${d.inHours} س';
    return 'منذ ${d.inDays} يوم';
  }

  static String date(DateTime t) => '${t.day}/${t.month}/${t.year}';
}
