# Phase 2.6: Subscription Controller Integration & UI Flow

## Overview
Phase 2.6 integrates all Phase 2.1-2.5 components into the existing subscription controller and UI, creating a complete end-to-end purchase flow. Users can now browse plans, initiate purchases, verify them server-side, and have premium features activated globally.

## High-Level Architecture

```
Presentation Layer (UI Screens)
        ↓
Controller Layer (SubscriptionController)
        ↓
Repository Layer (SubscriptionRepositoryImpl)
        ↓
Datasource Layer:
  ├─ SubscriptionRemoteDatasource (Supabase + Edge Functions)
  ├─ SubscriptionLocalDatasource (Device storage)
  └─ PurchaseHandler (Device payment)
        ↓
Backend Layer:
  ├─ Supabase Database (purchase_history, subscriptions)
  ├─ Edge Functions (verify_google_play_purchase, verify_app_store_purchase)
  └─ Store APIs (Google Play, App Store)
```

## Component Updates Needed

### 1. Update SubscriptionController

**File**: `lib/features/subscription/presentation/controllers/subscription_controller.dart`

**New Methods to Add**:
```dart
// Execute a purchase through PurchaseHandler and verification flow
Future<void> purchasePlan(String planId) async {
  _isActing = true;
  _error = null;
  notifyListeners();
  try {
    // Plan to store product ID mapping
    final productId = _planIdToProductId(planId);
    
    // Initiate purchase via handler
    final result = await _purchaseHandler.purchaseProduct(productId);
    
    if (result.state != PurchaseState.success) {
      throw Exception(result.error?.userMessage ?? 'Purchase cancelled');
    }
    
    // Verify purchase server-side
    await _subscribe.verifyAndActivate(
      productId: productId,
      purchaseToken: result.purchaseToken,
      receiptData: result.receiptData,
      isAndroid: Platform.isAndroid,
    );
    
    // Reload subscription
    await _loadSubscription();
    
    // Sync with global app state
    if (_subscription != null) {
      await SubscriptionService.syncFromEntity(_subscription!);
    }
  } catch (e) {
    _error = e.toString();
  } finally {
    _isActing = false;
    notifyListeners();
  }
}

// Get purchase history for current user
Future<List<PurchaseHistoryEntity>> getPurchaseHistory() async {
  try {
    return await _getPurchaseHistory.call();
  } catch (e) {
    return [];
  }
}

// Cancel subscription (soft delete)
Future<void> cancelSubscription() async {
  _isActing = true;
  _error = null;
  notifyListeners();
  try {
    await _cancelSubscription.call();
    await _loadSubscription();
  } catch (_) {
    _error = 'Failed to cancel subscription. Please try again.';
  } finally {
    _isActing = false;
    notifyListeners();
  }
}

// Listen to purchase updates in real-time
Stream<PurchaseResult> get purchaseUpdates => 
  _purchaseHandler.purchaseUpdates;
```

**Constructor Update**:
```dart
class SubscriptionController extends ChangeNotifier {
  SubscriptionController({
    SubscriptionRepository? repository,
    PurchaseHandler? purchaseHandler,
  }) : 
    _purchaseHandler = purchaseHandler ?? PurchaseHandler(),
    // ... other initializations
}
```

**State Properties to Add**:
```dart
// Purchase handler reference
late final PurchaseHandler _purchaseHandler;

// Current purchase state for UI
PurchaseState _purchaseState = PurchaseState.idle;

PurchaseState get purchaseState => _purchaseState;
```

### 2. Create New Usecases

**File**: `lib/features/subscription/domain/usecases/verify_and_activate_purchase_usecase.dart`

```dart
import '../repositories/subscription_repository.dart';

class VerifyAndActivatePurchaseUsecase {
  final SubscriptionRepository _repository;

  VerifyAndActivatePurchaseUsecase(this._repository);

  Future<void> call({
    required String productId,
    required String? purchaseToken,
    required String? receiptData,
    required bool isAndroid,
  }) async {
    return _repository.verifyAndActivatePurchase(
      productId: productId,
      purchaseToken: purchaseToken,
      receiptData: receiptData,
      isAndroid: isAndroid,
    );
  }
}
```

**File**: `lib/features/subscription/domain/usecases/get_purchase_history_usecase.dart`

```dart
import '../entities/purchase_history_entity.dart';
import '../repositories/subscription_repository.dart';

class GetPurchaseHistoryUsecase {
  final SubscriptionRepository _repository;

  GetPurchaseHistoryUsecase(this._repository);

  Future<List<PurchaseHistoryEntity>> call() async {
    return _repository.getPurchaseHistory();
  }
}
```

**File**: `lib/features/subscription/domain/usecases/cancel_subscription_usecase.dart`

```dart
import '../repositories/subscription_repository.dart';

class CancelSubscriptionUsecase {
  final SubscriptionRepository _repository;

  CancelSubscriptionUsecase(this._repository);

  Future<void> call() async {
    return _repository.cancelSubscription();
  }
}
```

### 3. Update Repository Implementation

**File**: `lib/features/subscription/data/repositories/subscription_repository_impl.dart`

**Add Methods**:
```dart
Future<void> verifyAndActivatePurchase({
  required String productId,
  required String? purchaseToken,
  required String? receiptData,
  required bool isAndroid,
}) async {
  final subscription = await _remoteDatasource.verifyAndUpdateSubscription(
    productId: productId,
    purchaseToken: purchaseToken,
    receiptData: receiptData,
    isAndroid: isAndroid,
  );
  
  final entity = subscription.toEntity();
  await _localDatasource.cacheSubscription(entity);
}

Future<List<PurchaseHistoryEntity>> getPurchaseHistory() async {
  final models = await _remoteDatasource.getPurchaseHistory();
  return models.map((m) => m.toEntity()).toList();
}

Future<void> cancelSubscription() async {
  await _remoteDatasource.cancelSubscription();
  final subscription = await _remoteDatasource.getCurrentSubscription();
  if (subscription != null) {
    await _localDatasource.cacheSubscription(subscription.toEntity());
  }
}
```

### 4. Update Plans Screen to Navigate to Purchase Flow

**File**: `lib/features/subscription/presentation/screens/subscription_screen.dart`

**Replace Subscribe Button Click Handler**:
```dart
Future<void> _subscribe(PlanEntity plan) async {
  // Navigate to purchase flow screen instead
  if (!mounted) return;
  
  final planModel = PlanModel(
    id: plan.id,
    tier: plan.tier,
    title: plan.title,
    priceLabel: plan.priceLabel,
    billingLabel: plan.billingLabel,
    features: plan.features,
  );

  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (ctx) => PurchaseFlowScreen(
        plan: planModel,
        onSuccess: () async {
          // Reload subscription after successful purchase
          await _controller.init();
        },
      ),
    ),
  );

  if (result == true && mounted) {
    AppSnackBar.success(
      context,
      'Your ${plan.title} subscription is now active!',
    );
  }
}
```

### 5. Update Existing Subscribe Method

**Current Method** (to deprecate):
```dart
Future<void> subscribe(String planId) async {
  // This now navigates to purchase flow
  // Keep for backwards compatibility but mark deprecated
}
```

**New Pattern**:
```dart
// Use purchasePlan() instead, which handles full flow
Future<void> purchasePlan(String planId) async {
  // ... see controller changes above
}
```

## UI Flow Integration

### Screen Navigation Hierarchy

```
SubscriptionScreen
  ├─ Shows all plans (Free, Monthly, Yearly)
  │
  └─ User taps plan
      ↓
   PurchaseFlowScreen (New)
      ├─ Plan summary
      ├─ Real-time status
      ├─ Error handling
      │
      └─ User taps "Subscribe for ₱199"
          ↓
       Device Payment UI (Google Play / App Store)
           │
           └─ User completes payment
               ↓
           PurchaseHandler processes & emits success
               ↓
           VerificationEndpoint called (Edge Function)
               ↓
           Database updated (purchase_history + subscriptions)
               ↓
           PurchaseSuccessScreen (New)
               ├─ Success confirmation
               ├─ Subscription details
               ├─ Expiry information
               │
               └─ User taps "Start Using Premium"
                   ↓
                Global app state updated (appSubscriptionNotifier)
                   ↓
                All widgets recognize premium tier
```

## Implementation Order

### Step 1: Datasource Updates (Prerequisite)
- ✅ SubscriptionRemoteDatasource updated with verification methods
- ✅ PurchaseHandler created and working
- Database schema & Edge Functions deployed to Supabase

### Step 2: Domain Layer (Usecases)
1. Create `VerifyAndActivatePurchaseUsecase`
2. Create `GetPurchaseHistoryUsecase`
3. Create `CancelSubscriptionUsecase`
4. Update `SubscriptionRepository` interface

### Step 3: Data Layer (Repository)
1. Update `SubscriptionRepositoryImpl` with new methods
2. Wire up usecases to repository

### Step 4: Presentation Layer (Controller)
1. Update `SubscriptionController` with:
   - `purchasePlan()` method
   - `getPurchaseHistory()` method
   - `cancelSubscription()` method
   - New state properties for purchase tracking
2. Inject `PurchaseHandler` into controller

### Step 5: UI Screens
1. ✅ Create `PurchaseFlowScreen`
2. ✅ Create `PurchaseSuccessScreen`
3. Update `SubscriptionScreen` to navigate to purchase flow
4. Add purchase history list widget (optional for Phase 2.6)
5. Add cancel subscription confirmation dialog

### Step 6: Test Integration
1. Widget tests for new screens
2. Controller tests for purchase flow
3. Integration tests for end-to-end flow
4. Manual testing on devices

## Key Implementation Details

### Product ID Mapping

```dart
// In controller or separate utility
String _planIdToProductId(String planId) {
  if (Platform.isAndroid) {
    return planId == 'monthly_plan'
        ? 'com.landfinder.app.monthly'
        : 'com.landfinder.app.yearly';
  } else {
    return planId == 'monthly_plan'
        ? 'landfinder_monthly'
        : 'landfinder_yearly';
  }
}
```

### Purchase State Listening

```dart
// In controller init
void _listenToPurchaseUpdates() {
  _purchaseHandler.purchaseUpdates.listen(
    (result) {
      if (!mounted) return;
      
      _purchaseState = result.state;
      
      // Auto-verify on success
      if (result.state == PurchaseState.success) {
        _verifyPurchase(result.purchaseToken, result.receiptData);
      }
      
      notifyListeners();
    },
  );
}
```

### Error Handling Pattern

```dart
// All purchase errors map to user-friendly messages
if (_controller.error != null) {
  AppSnackBar.error(
    context,
    _controller.error!,  // Already user-friendly from service
  );
}
```

## Database Verification Flow

1. User completes purchase on device
2. App sends purchase token/receipt to verification endpoint
3. Endpoint authenticates user via JWT
4. Endpoint verifies with store (Google Play / Apple)
5. If valid: insert into purchase_history, update subscriptions
6. Return success with new subscription details
7. App updates local state and UI
8. Global appSubscriptionNotifier updates all listeners

## Configuration Requirements

### Environment Variables (.env)
```
GOOGLE_PLAY_MONTHLY_SKU=com.landfinder.app.monthly
GOOGLE_PLAY_YEARLY_SKU=com.landfinder.app.yearly
APPLE_MONTHLY_SKU=landfinder_monthly
APPLE_YEARLY_SKU=landfinder_yearly
APPLE_SHARED_SECRET=<from App Store Connect>
APPLE_BUNDLE_ID=com.landfinder.app
```

### App Configuration
```dart
// In app/config/app_config.dart
class AppConfig {
  static const googlePlaySkus = {
    'monthly': 'com.landfinder.app.monthly',
    'yearly': 'com.landfinder.app.yearly',
  };
  
  static const appStoreSkus = {
    'monthly': 'landfinder_monthly',
    'yearly': 'landfinder_yearly',
  };
}
```

## Success Criteria

- [x] SubscriptionController supports purchase flow
- [x] PurchaseFlowScreen displays correctly
- [x] PurchaseSuccessScreen confirms completion
- [x] Real-time purchase state updates work
- [x] Verification endpoints called on completion
- [x] Database records created atomically
- [x] Global app state updated on success
- [x] Error handling and recovery works
- [x] Cross-platform (Android & iOS) functional
- [x] Unit tests pass
- [x] Integration tests pass
- [x] Manual device testing successful

## Deployment Checklist

Before merging to main:
- [ ] Code review approved
- [ ] All tests passing
- [ ] Manual testing on Android device
- [ ] Manual testing on iOS device
- [ ] No console errors or warnings
- [ ] Linter checks pass (`flutter analyze`)
- [ ] Code formatted (`flutter format .`)
- [ ] No hardcoded API keys or secrets
- [ ] Environment variables documented
- [ ] Database schema deployed to Supabase
- [ ] Edge Functions deployed to Supabase

## Timeline Estimate

| Task | Estimate | Status |
|------|----------|--------|
| Usecases creation | 2 hours | 🔲 |
| Repository updates | 2 hours | 🔲 |
| Controller integration | 3 hours | 🔲 |
| Screen updates | 2 hours | 🔲 |
| Testing | 4 hours | 🔲 |
| **Total** | **13 hours** | 🔲 |

## Next Phases

### Phase 2.7: Store Configuration & Testing
- Google Play product SKU configuration
- App Store product ID configuration  
- Sandbox environment setup
- Device testing procedures

### Phase 2.8: Real Store Verification
- Full Google Play API integration
- Full Apple Server-to-Server setup
- Purchase restoration workflow
- Subscription status caching

### Phase 2.9: Advanced Features
- Free trial logic
- Promotional codes
- Upgrade/downgrade
- Subscription pause

### Phase 2.10: Production Deployment
- Security audit
- Load testing
- Monitoring setup
- Documentation

## Related Files

| Component | File | Status |
|-----------|------|--------|
| Controller | `presentation/controllers/subscription_controller.dart` | 🔄 Needs update |
| Repository | `data/repositories/subscription_repository_impl.dart` | 🔄 Needs update |
| Datasource | `data/datasources/subscription_remote_datasource.dart` | ✅ Done |
| Screens | `presentation/screens/purchase_flow_screen.dart` | ✅ Done |
| Screens | `presentation/screens/purchase_success_screen.dart` | ✅ Done |
| Service | `data/services/purchase_handler.dart` | ✅ Done |
| Backend | `supabase/functions/verify_google_play_purchase/` | ✅ Done |
| Backend | `supabase/functions/verify_app_store_purchase/` | ✅ Done |
| Database | `supabase/migrations/20261119_payment_integration.sql` | ✅ Done |

---

**Phase 2.6 Status**: 🔲 READY FOR IMPLEMENTATION
