enum PaymentMethodId { store, gcash, qrphGotyme, card }

enum RenewalMode { storeRecurring, fixedTerm, paymongoRecurring }

class PaymentMethodEntity {
  const PaymentMethodEntity({
    required this.id,
    required this.label,
    required this.description,
    required this.renewalMode,
  });

  final PaymentMethodId id;
  final String label;
  final String description;
  final RenewalMode renewalMode;

  String get apiValue => switch (id) {
    PaymentMethodId.gcash => 'gcash',
    PaymentMethodId.qrphGotyme => 'qrph_gotyme',
    PaymentMethodId.card => 'card',
    PaymentMethodId.store => 'store',
  };
}
