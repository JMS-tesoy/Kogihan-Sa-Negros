import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../app/config/env_config.dart';
import '../models/subscription_model.dart';
import '../datasources/subscription_remote_datasource.dart';
import 'subscription_service.dart';

/// Enum representing the state of a purchase operation
enum PurchaseState {
  idle,         // No operation in progress
  loading,      // Loading products from store
  processing,   // Purchase in progress
  pending,      // Purchase pending confirmation
  success,      // Purchase successful and verified
  error,        // Purchase failed
  cancelled,    // User cancelled purchase
  restoring,    // Restoring previous purchases
}

/// Enum representing specific purchase errors
enum PurchaseError {
  networkError,         // Network connectivity issue
  paymentFailed,        // Payment declined or failed
  userCancelled,        // User cancelled the purchase
  verificationFailed,   // Backend verification failed
  storeUnavailable,     // Store not available or not configured
  invalidProduct,       // Product not found or invalid
  pendingTransaction,   // Purchase pending, needs completion
  unknown,              // Unknown error
}

/// Result of a purchase operation
class PurchaseResult {
  final PurchaseState state;
  final SubscriptionModel? subscription;
  final PurchaseError? error;
  final String? errorMessage;
  final String? actionMessage; // User-friendly guidance

  PurchaseResult({
    required this.state,
    this.subscription,
    this.error,
    this.errorMessage,
    this.actionMessage,
  });

  /// Check if purchase was successful
  bool get isSuccess => state == PurchaseState.success;

  /// Check if there's an error
  bool get hasError => error != null;

  /// Get user-friendly error message
  String? get userMessage {
    if (!hasError) return null;

    switch (error) {
      case PurchaseError.networkError:
        return 'Network connection lost. Please check your internet and try again.';
      case PurchaseError.paymentFailed:
        return 'Payment failed. Please check your payment method and try again.';
      case PurchaseError.userCancelled:
        return 'Purchase cancelled. No charges were made.';
      case PurchaseError.verificationFailed:
        return 'Unable to verify your purchase. Please try again or contact support.';
      case PurchaseError.storeUnavailable:
        return 'Google Play/App Store is unavailable. Please try again later.';
      case PurchaseError.invalidProduct:
        return 'This subscription is no longer available.';
      case PurchaseError.pendingTransaction:
        return 'Your purchase is pending. Please complete it to activate your subscription.';
      case PurchaseError.unknown:
        return errorMessage ?? 'An unexpected error occurred. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  /// Get user-friendly error message
  String? getUserMessage() {
    if (!hasError) return null;

    switch (error) {
      case PurchaseError.networkError:
        return 'Network connection lost. Please check your internet and try again.';
      case PurchaseError.paymentFailed:
        return 'Payment failed. Please check your payment method and try again.';
      case PurchaseError.userCancelled:
        return 'Purchase cancelled. No charges were made.';
      case PurchaseError.verificationFailed:
        return 'Unable to verify your purchase. Please try again or contact support.';
      case PurchaseError.storeUnavailable:
        return 'Google Play/App Store is unavailable. Please try again later.';
      case PurchaseError.invalidProduct:
        return 'This subscription is no longer available.';
      case PurchaseError.pendingTransaction:
        return 'Your purchase is pending. Please complete it to activate your subscription.';
      case PurchaseError.unknown:
        return errorMessage ?? 'An unexpected error occurred. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  String toString() =>
      'PurchaseResult(state: $state, error: $error, message: $errorMessage)';
}

/// Exception thrown during purchase operations
class PurchaseException implements Exception {
  final PurchaseError error;
  final String message;

  PurchaseException(this.error, this.message);

  @override
  String toString() => 'PurchaseException: $message';
}

/// Handles in-app purchase operations across Android (Google Play) and iOS (App Store)
/// Provides abstraction layer over platform-specific implementations
class PurchaseHandler {
  late final InAppPurchase _iap;
  late final Stream<List<PurchaseDetails>> _purchaseStream;
  final SubscriptionRemoteDatasource _remoteDatasource;

  /// Map of product IDs to subscription tiers
  static const Map<String, SubscriptionTier> productTierMap = {
    // Will be populated from environment config
  };

  PurchaseHandler({
    InAppPurchase? iap,
    SubscriptionRemoteDatasource? remoteDatasource,
  }) : _remoteDatasource =
           remoteDatasource ?? SubscriptionRemoteDatasource() {
    _iap = iap ?? InAppPurchase.instance;
    _purchaseStream = _iap.purchaseStream;
  }

  /// Initialize purchase handler on app launch
  Future<void> initialize() async {
    try {
      // Check if In-App Purchase is available
      final available = await _iap.isAvailable();
      if (!available) {
        throw PurchaseException(
          PurchaseError.storeUnavailable,
          'In-App Purchase is not available on this device',
        );
      }

      // Load products from store
      await loadProducts();
    } catch (e) {
      throw PurchaseException(
        PurchaseError.storeUnavailable,
        'Failed to initialize purchase handler: $e',
      );
    }
  }

  /// Load available subscription products from store
  Future<List<ProductDetails>> loadProducts() async {
    try {
      final productIds = <String>{
        if (defaultTargetPlatform == TargetPlatform.android) ...{
          if (EnvConfig.googlePlayMonthlySku.isNotEmpty)
            EnvConfig.googlePlayMonthlySku,
          if (EnvConfig.googlePlayYearlySku.isNotEmpty)
            EnvConfig.googlePlayYearlySku,
        },
        if (defaultTargetPlatform == TargetPlatform.iOS) ...{
          if (EnvConfig.appStoreMonthlySku.isNotEmpty)
            EnvConfig.appStoreMonthlySku,
          if (EnvConfig.appStoreYearlySku.isNotEmpty)
            EnvConfig.appStoreYearlySku,
        },
      };

      if (productIds.isEmpty) {
        throw PurchaseException(
          PurchaseError.invalidProduct,
          'No subscription products configured',
        );
      }

      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        throw PurchaseException(
          PurchaseError.storeUnavailable,
          'Failed to load products: ${response.error}',
        );
      }

      return response.productDetails;
    } catch (e) {
      throw PurchaseException(
        PurchaseError.storeUnavailable,
        'Failed to load products from store: $e',
      );
    }
  }

  /// Initiate purchase for a specific product
  /// Returns immediately with processing state; actual result comes via purchaseUpdates stream
  Future<PurchaseResult> purchaseProduct({
    required ProductDetails product,
  }) async {
    try {
      // Validate product
      if (product.id.isEmpty) {
        return PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.invalidProduct,
          errorMessage: 'Invalid product configuration',
          actionMessage: 'Please contact support with this error code: INVALID_PRODUCT',
        );
      }

      // Initiate purchase through store
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

      // Result will come through purchaseStream
      return PurchaseResult(
        state: PurchaseState.processing,
        actionMessage: 'Processing your purchase...',
      );
    } on PlatformException catch (e) {
      // Handle platform-specific errors
      return _handlePlatformException(e);
    } catch (e) {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.paymentFailed,
        errorMessage: 'Failed to initiate purchase: $e',
        actionMessage: 'Please try again or contact support',
      );
    }
  }

  /// Stream of purchase updates from store
  /// Listens to both successful and failed purchase attempts
  Stream<PurchaseResult> get purchaseUpdates {
    return _purchaseStream.asyncExpand((purchases) {
      if (purchases.isEmpty) {
        return Stream<PurchaseResult>.value(
          PurchaseResult(state: PurchaseState.idle),
        );
      }
      return Stream<PurchaseDetails>.fromIterable(purchases).asyncMap(
        _handlePurchaseUpdate,
      );
    });
  }

  /// Handle individual purchase update from store
  Future<PurchaseResult> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    try {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Purchase is complete, verify with backend
        return await _verifyAndCompletePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.pending) {
        // Purchase is pending user confirmation
        return PurchaseResult(
          state: PurchaseState.pending,
          error: PurchaseError.pendingTransaction,
          errorMessage: 'Purchase pending confirmation',
          actionMessage: 'Please complete the payment in your store app',
        );
      } else if (purchase.status == PurchaseStatus.canceled) {
        // User cancelled the purchase
        return PurchaseResult(
          state: PurchaseState.cancelled,
          error: PurchaseError.userCancelled,
          errorMessage: 'Purchase cancelled by user',
          actionMessage: 'No charges were made. You can try again anytime.',
        );
      } else {
        // Unknown status
        return PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.unknown,
          errorMessage: 'Unknown purchase status: ${purchase.status}',
          actionMessage: 'Please contact support',
        );
      }
    } catch (e) {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.verificationFailed,
        errorMessage: 'Error processing purchase: $e',
        actionMessage: 'Please contact support with this error',
      );
    }
  }

  /// Verify purchase with backend and complete the transaction
  Future<PurchaseResult> _verifyAndCompletePurchase(
    PurchaseDetails purchase,
  ) async {
    try {
      // Get purchase details
      final purchaseToken =
          purchase.verificationData.serverVerificationData.isNotEmpty
          ? purchase.verificationData.serverVerificationData
          : purchase.verificationData.localVerificationData;

      if (purchaseToken.isEmpty) {
        return PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.verificationFailed,
          errorMessage: 'No verification data available',
          actionMessage: 'Please try the purchase again',
        );
      }

      final bool isAndroid =
          defaultTargetPlatform == TargetPlatform.android;
      final SubscriptionModel subscription = await _remoteDatasource
          .verifyAndUpdateSubscription(
            productId: purchase.productID,
            purchaseToken: isAndroid ? purchaseToken : null,
            receiptData: isAndroid ? null : purchaseToken,
            isAndroid: isAndroid,
          );

      if (!subscription.isPremium) {
        return PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.verificationFailed,
          errorMessage: 'Verified purchase did not create an active entitlement',
          actionMessage: 'Please try again or contact support',
        );
      }

      await SubscriptionService.syncFromEntity(subscription);
      await _iap.completePurchase(purchase);

      return PurchaseResult(
        state: PurchaseState.success,
        subscription: subscription,
        actionMessage: 'Your subscription has been activated!',
      );
    } catch (e) {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.verificationFailed,
        errorMessage: 'Failed to verify purchase: $e',
        actionMessage: 'Please try again or contact support',
      );
    }
  }

  /// Restore previous purchases for this user
  /// Useful when user switches devices or reinstalls app
  Future<List<PurchaseResult>> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      // Results come through purchaseStream
      return [
        PurchaseResult(
          state: PurchaseState.restoring,
          actionMessage: 'Restoring your previous purchases...',
        )
      ];
    } on PlatformException catch (e) {
      return [
        PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.networkError,
          errorMessage: 'Failed to restore purchases: ${e.message}',
          actionMessage: 'Please check your internet connection and try again',
        )
      ];
    } catch (e) {
      return [
        PurchaseResult(
          state: PurchaseState.error,
          error: PurchaseError.unknown,
          errorMessage: 'Failed to restore purchases: $e',
          actionMessage: 'Please contact support',
        )
      ];
    }
  }

  /// Handle platform-specific exceptions
  PurchaseResult _handlePlatformException(PlatformException e) {
    // Map platform error codes to PurchaseError
    final errorCode = e.code.toLowerCase();

    if (errorCode.contains('cancelled') || errorCode.contains('user')) {
      return PurchaseResult(
        state: PurchaseState.cancelled,
        error: PurchaseError.userCancelled,
        errorMessage: e.message ?? 'User cancelled the purchase',
        actionMessage: 'You can try again anytime.',
      );
    } else if (errorCode.contains('network') ||
        errorCode.contains('connection')) {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.networkError,
        errorMessage: e.message ?? 'Network error occurred',
        actionMessage: 'Please check your internet connection and try again',
      );
    } else if (errorCode.contains('unavailable') ||
        errorCode.contains('store')) {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.storeUnavailable,
        errorMessage: e.message ?? 'Store is unavailable',
        actionMessage: 'Please try again later',
      );
    } else {
      return PurchaseResult(
        state: PurchaseState.error,
        error: PurchaseError.paymentFailed,
        errorMessage: e.message ?? 'Payment failed',
        actionMessage: 'Please try again or use a different payment method',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}
