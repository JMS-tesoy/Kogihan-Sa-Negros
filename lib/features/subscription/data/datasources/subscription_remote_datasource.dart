import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/enums/subscription_tier.dart';
import '../models/plan_model.dart';
import '../models/subscription_model.dart';

class SubscriptionRemoteDatasource {
  SubscriptionRemoteDatasource();

  Future<SubscriptionModel?> getCurrentSubscription() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await Supabase.instance.client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return SubscriptionModel.fromMap(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PlanModel>> getAvailablePlans() async {
    // These match the ones in the old SubscriptionService
    return [
      const PlanModel(
        id: 'free_plan',
        tier: SubscriptionTier.free,
        title: 'Free',
        priceLabel: '₱0',
        billingLabel: 'Current starter access',
        features: [
          'Browse lot listings',
          'Message agents',
          'Save up to 3 lots',
        ],
      ),
      const PlanModel(
        id: 'monthly_plan',
        tier: SubscriptionTier.monthly,
        title: 'Monthly Premium',
        priceLabel: '₱199',
        billingLabel: 'Per month',
        features: [
          'Unlimited saved lots',
          'Premium-only feature gates',
          'Premium analytics',
        ],
      ),
      const PlanModel(
        id: 'yearly_plan',
        tier: SubscriptionTier.yearly,
        title: 'Yearly Premium',
        priceLabel: '₱1,999',
        billingLabel: 'Per year',
        features: [
          'Everything in Monthly Premium',
          'Save up to 2 years',
          'Best value',
        ],
      ),
    ];
  }

  /// Verify purchase with backend and update subscription
  /// Call this after user completes purchase on the device
  Future<SubscriptionModel> verifyAndUpdateSubscription({
    required String productId,
    required String? purchaseToken,
    required String? receiptData,
    required bool isAndroid,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Determine which verification endpoint to call
      final functionName = isAndroid
          ? 'verify_google_play_purchase'
          : 'verify_app_store_purchase';

      final requestBody = isAndroid
          ? {
              'userId': userId,
              'productId': productId,
              'purchaseToken': purchaseToken,
            }
          : {
              'userId': userId,
              'productId': productId,
              'receiptData': receiptData,
              'environment': 'production',
            };

      // Call the appropriate verification function
      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: requestBody,
      );

      // Edge function returned a non-2xx status
      if (response.status != 200) {
        throw Exception('Purchase verification failed (${response.status})');
      }

      final data = response.data;
      if (data is! Map<String, dynamic> || data['verified'] != true) {
        throw Exception(
          (data is Map ? data['error'] : null) ?? 'Purchase verification failed',
        );
      }

      // Fetch updated subscription after verification
      return await getCurrentSubscription() ??
          (throw Exception('Failed to load updated subscription'));
    } catch (e) {
      rethrow;
    }
  }

  /// Restore purchases from store
  /// Call this to sync purchases from device storage to backend
  Future<SubscriptionModel?> restorePurchases({
    required String? purchaseToken,
    required String? receiptData,
    required bool isAndroid,
  }) async {
    try {
      if (isAndroid && purchaseToken == null) {
        throw Exception('Purchase token required for Android');
      }
      if (!isAndroid && receiptData == null) {
        throw Exception('Receipt data required for iOS');
      }

      // If we have a purchase to restore, verify it
      if ((isAndroid && purchaseToken != null) || (!isAndroid && receiptData != null)) {
        return await verifyAndUpdateSubscription(
          productId: '', // Extract from receipt/token server-side
          purchaseToken: purchaseToken,
          receiptData: receiptData,
          isAndroid: isAndroid,
        );
      }

      return await getCurrentSubscription();
    } catch (e) {
      rethrow;
    }
  }

  /// Get subscription status for current user
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        return {'tier': 'free', 'status': 'inactive'};
      }

      final response = await Supabase.instance.client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return {'tier': 'free', 'status': 'inactive'};
      }

      return {
        'tier': response['tier'] ?? 'free',
        'status': response['status'] ?? 'inactive',
        'renewalAt': response['renewal_at'],
        'verifiedAt': response['last_verification_at'],
      };
    } catch (e) {
      return {'tier': 'free', 'status': 'inactive'};
    }
  }

  /// Cancel subscription (soft delete - mark as inactive)
  Future<void> cancelSubscription() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await Supabase.instance.client
          .from('subscriptions')
          .update({
            'status': 'inactive',
            'tier': 'free',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get purchase history for current user
  Future<List<Map<String, dynamic>>> getPurchaseHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await Supabase.instance.client
          .from('purchase_history')
          .select()
          .eq('user_id', userId)
          .order('purchase_date', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }
}
