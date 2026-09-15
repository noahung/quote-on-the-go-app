import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/services/notification_service.dart';

void main() {
  test('notification links support both relative and legacy full URLs', () {
    expect(notificationRoute('/quotations/Q123'), '/quotations/Q123');
    expect(notificationRoute('https://app.quoteonthego.co.uk/invoices/I123'), '/invoices/I123');
    expect(notificationRoute('qotg:///schedule/job'), '/schedule/job');
    expect(notificationRoute('javascript:alert(1)'), isNull);
    expect(notificationRoute('/auth/signup'), isNull);
    expect(notificationRoute('/expenses'), '/expenses');
    expect(notificationRoute('https://evil.test/invoices/I123'), isNull);
  });
}
