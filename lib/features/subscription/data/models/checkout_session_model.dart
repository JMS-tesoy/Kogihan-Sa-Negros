import '../../domain/entities/payment_method.dart';

class CheckoutSessionModel {
  const CheckoutSessionModel({
    required this.orderId,
    required this.checkoutUrl,
    required this.status,
    required this.renewalMode,
  });

  factory CheckoutSessionModel.fromMap(
    Map<String, dynamic> map,
    RenewalMode renewalMode,
  ) {
    return CheckoutSessionModel(
      orderId: map['orderId']?.toString() ?? '',
      checkoutUrl: map['checkoutUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      renewalMode: renewalMode,
    );
  }

  final String orderId;
  final String checkoutUrl;
  final String status;
  final RenewalMode renewalMode;
}

class BillingOrderStatus {
  const BillingOrderStatus({
    required this.id,
    required this.status,
    this.entitlementUntil,
  });

  factory BillingOrderStatus.fromMap(Map<String, dynamic> map) {
    return BillingOrderStatus(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      entitlementUntil: map['entitlement_until'] == null
          ? null
          : DateTime.tryParse(map['entitlement_until'].toString()),
    );
  }

  final String id;
  final String status;
  final DateTime? entitlementUntil;

  bool get isTerminal =>
      status == 'paid' || status == 'failed' || status == 'cancelled' ||
      status == 'expired' || status == 'refunded';
}
