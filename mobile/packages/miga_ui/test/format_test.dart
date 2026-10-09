import 'package:flutter_test/flutter_test.dart';
import 'package:miga_ui/miga_ui.dart';

void main() {
  test('money groups thousands and keeps decimals only when needed', () {
    expect(MigaFormat.money(2999), '2,999 ر.س');
    expect(MigaFormat.money(14012.5), '14,012.50 ر.س');
    expect(MigaFormat.money(55, symbol: false), '55');
  });

  test('countdown', () {
    expect(MigaFormat.countdown(const Duration(days: 2, hours: 5)), '2 يوم 5 س');
    expect(MigaFormat.countdown(const Duration(hours: 3, minutes: 4)), '3 س 4 د');
    expect(MigaFormat.countdown(const Duration(minutes: -1)), 'انتهت');
  });
}
