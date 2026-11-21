import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/subscription/data/models/checkout_session_model.dart';
import 'package:kogihan_sa_negros/features/subscription/domain/entities/payment_method.dart';

void main() {
  test('GoTyme is represented as QR Ph with fixed-term renewal', () {
    const method = PaymentMethodEntity(
      id: PaymentMethodId.qrphGotyme,
      label: 'QR Ph (scan with GoTyme)',
      description: 'Does not auto-renew.',
      renewalMode: RenewalMode.fixedTerm,
    );

    expect(method.apiValue, 'qrph_gotyme');
    expect(method.renewalMode, RenewalMode.fixedTerm);
  });

  test('browser checkout response is only pending until verified', () {
    final session = CheckoutSessionModel.fromMap(<String, dynamic>{
      'orderId': 'order-1',
      'checkoutUrl': 'https://checkout.example',
      'status': 'awaiting_payment',
    }, RenewalMode.fixedTerm);
    final order = BillingOrderStatus.fromMap(<String, dynamic>{
      'id': session.orderId,
      'status': 'awaiting_payment',
    });

    expect(order.isTerminal, isFalse);
    expect(order.status, 'awaiting_payment');
  });

  test('only webhook-derived paid status is terminal success', () {
    final paid = BillingOrderStatus.fromMap(<String, dynamic>{
      'id': 'order-1',
      'status': 'paid',
      'entitlement_until': '2030-01-01T00:00:00.000Z',
    });

    expect(paid.isTerminal, isTrue);
    expect(paid.status, 'paid');
    expect(paid.entitlementUntil, DateTime.utc(2030));
  });
}
