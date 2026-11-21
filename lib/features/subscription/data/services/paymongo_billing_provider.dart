import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/payment_method.dart';
import '../models/checkout_session_model.dart';

class PayMongoBillingProvider {
  PayMongoBillingProvider({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PaymentMethodEntity>> getAvailableMethods() async {
    final FunctionResponse response = await _client.functions.invoke(
      'get_billing_availability',
    );
    if (response.status != 200) {
      throw Exception('Unable to load billing methods');
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      response.data as Map,
    );
    if (data['external_checkout_enabled'] != true) return const [];
    final List<dynamic> methods = data['methods'] as List<dynamic>? ?? const [];
    return methods.whereType<Map>().map((dynamic raw) {
      final Map<String, dynamic> method = Map<String, dynamic>.from(raw as Map);
      final String id = method['id']?.toString() ?? '';
      final RenewalMode renewalMode = method['renewal_mode'] ==
              'paymongo_recurring'
          ? RenewalMode.paymongoRecurring
          : RenewalMode.fixedTerm;
      if (method['enabled'] != true) return null;
      return switch (id) {
        'gcash' => PaymentMethodEntity(
          id: PaymentMethodId.gcash,
          label: 'GCash',
          description: 'One payment. Access continues until expiry; renew manually.',
          renewalMode: renewalMode,
        ),
        'qrph_gotyme' => PaymentMethodEntity(
          id: PaymentMethodId.qrphGotyme,
          label: 'QR Ph (scan with GoTyme)',
          description: 'Scan the QR Ph code. This payment does not auto-renew.',
          renewalMode: renewalMode,
        ),
        'card' => PaymentMethodEntity(
          id: PaymentMethodId.card,
          label: 'Credit / Debit Card',
          description: renewalMode == RenewalMode.paymongoRecurring
              ? 'Auto-renewing card subscription.'
              : 'One card payment. Renew manually before expiry.',
          renewalMode: renewalMode,
        ),
        _ => null,
      };
    }).whereType<PaymentMethodEntity>().toList();
  }

  Future<CheckoutSessionModel> createCheckout({
    required String planId,
    required PaymentMethodEntity method,
  }) async {
    final String idempotencyKey = '${DateTime.now().microsecondsSinceEpoch}'
        '-${method.apiValue}';
    final FunctionResponse response = await _client.functions.invoke(
      'create_billing_checkout',
      body: <String, dynamic>{
        'planId': planId,
        'paymentMethod': method.apiValue,
        'idempotencyKey': idempotencyKey,
      },
    );
    if (response.status != 200) {
      throw Exception('Unable to start checkout (${response.status})');
    }
    return CheckoutSessionModel.fromMap(
      Map<String, dynamic>.from(response.data as Map),
      method.renewalMode,
    );
  }

  Future<BillingOrderStatus> getOrder(String orderId) async {
    final FunctionResponse response = await _client.functions.invoke(
      'get_billing_order',
      body: <String, dynamic>{'orderId': orderId},
    );
    if (response.status != 200) {
      throw Exception('Unable to load order status (${response.status})');
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      response.data as Map,
    );
    return BillingOrderStatus.fromMap(
      Map<String, dynamic>.from(data['order'] as Map),
    );
  }
}
