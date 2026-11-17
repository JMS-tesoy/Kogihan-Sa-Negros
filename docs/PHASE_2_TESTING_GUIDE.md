# Phase 2 Testing Guide: Real Billing Integration

## Overview
This guide provides step-by-step instructions for testing all Phase 2 components: database schema, Edge Functions, purchase handler, verification endpoints, and UI flows.

## Prerequisites

### Local Development Setup
- Flutter SDK with Android/iOS support
- Supabase CLI installed: `npm install -g supabase`
- Postman or curl for API testing
- Android Studio or Xcode
- Google Play Console test account
- App Store Connect test sandbox

### Project Configuration
```bash
# Install Dart/Flutter dependencies
flutter pub get

# Ensure Supabase is configured
supabase status
```

## Phase 1: Database Schema Testing

### 1.1 Verify Database Tables Exist

```bash
# Connect to Supabase
supabase db pull

# Or use psql directly
psql "postgresql://[user]:[password]@[host]/postgres"

# Check tables
\dt purchase_history
\dt subscriptions
```

**Expected Schema**:
```
Table "public.purchase_history"
  Columns:
  - id (uuid, primary key)
  - user_id (uuid, foreign key)
  - product_id (text)
  - store (text) - 'google_play' or 'app_store'
  - store_transaction_id (text, unique with user_id)
  - purchase_token (text)
  - purchase_date (timestamp)
  - expiry_date (timestamp)
  - status (text) - 'pending', 'verified', 'failed'
  - verification_response (jsonb)

Table "public.subscriptions"
  Columns:
  - id (uuid)
  - user_id (uuid, unique)
  - tier (text) - 'free', 'monthly', 'yearly'
  - status (text) - 'active', 'inactive'
  - renewal_at (timestamp)
  - verified_purchase_id (uuid)
  - last_verification_at (timestamp)
```

### 1.2 Verify RLS Policies

```bash
# Check RLS is enabled on purchase_history
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'purchase_history';

SELECT * FROM pg_policies 
WHERE tablename = 'purchase_history';
```

**Expected Policies**:
- Users can SELECT own purchases only
- Admins can SELECT all purchases
- No users can UPDATE/DELETE (immutable)

### 1.3 Test Database Functions

```sql
-- Test verify_google_play_purchase function
SELECT verify_google_play_purchase(
  'test-user-id'::uuid,
  'com.landfinder.app.monthly',
  'test-purchase-token',
  jsonb_build_object(
    'orderId', 'test-order-123',
    'purchaseState', 0
  )
);

-- Test get_active_entitlement function
SELECT get_active_entitlement('test-user-id'::uuid);

-- Expected: Returns tier ('free', 'monthly', 'yearly')
```

## Phase 2: Edge Functions Testing

### 2.1 Deploy Functions to Supabase

```bash
cd supabase/functions

# Verify function directories exist
ls -la verify_google_play_purchase/
ls -la verify_app_store_purchase/

# Deploy to Supabase
supabase functions deploy verify_google_play_purchase
supabase functions deploy verify_app_store_purchase
```

**Expected Output**:
```
✓ Function verify_google_play_purchase deployed
✓ Function verify_app_store_purchase deployed
```

### 2.2 Test Google Play Verification Endpoint

#### Using curl

```bash
# Get auth token
AUTH_TOKEN=$(supabase auth --project-id YOUR_PROJECT_ID generate-access-token)

# Test successful verification
curl -X POST \
  https://[PROJECT_ID].supabase.co/functions/v1/verify_google_play_purchase \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "'$USER_ID'",
    "productId": "com.landfinder.app.monthly",
    "purchaseToken": "test-purchase-token-12345"
  }'

# Expected Response (success):
# {
#   "verified": true,
#   "purchaseId": "550e8400-e29b-41d4-a716-446655440000",
#   "subscriptionTier": "monthly",
#   "expiryDate": "2025-02-19T10:30:00.000Z",
#   "message": "Purchase successfully verified and recorded"
# }
```

#### Using Postman

1. Create new POST request
2. URL: `https://[PROJECT_ID].supabase.co/functions/v1/verify_google_play_purchase`
3. Headers:
   - `Authorization: Bearer [AUTH_TOKEN]`
   - `Content-Type: application/json`
4. Body (raw JSON):
   ```json
   {
     "userId": "user-uuid",
     "productId": "com.landfinder.app.monthly",
     "purchaseToken": "mock-purchase-token"
   }
   ```
5. Send and verify response

**Test Cases**:

| Case | Input | Expected Response | Status |
|------|-------|-------------------|--------|
| Valid purchase | Valid token + product | verified: true | 200 |
| Missing userId | No userId field | error message | 400 |
| Missing productId | No productId field | error message | 400 |
| Missing token | No purchaseToken | error message | 400 |
| Invalid token format | Token < 10 chars | verification failed | 400 |
| Cross-user attempt | Different auth user | Unauthorized | 403 |
| No auth header | Missing Bearer token | Unauthorized | 401 |

### 2.3 Test App Store Verification Endpoint

```bash
# Get mock receipt (from iOS Sandbox test)
# See Phase 3: iOS Testing for real receipt generation

# Test endpoint
curl -X POST \
  https://[PROJECT_ID].supabase.co/functions/v1/verify_app_store_purchase \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "'$USER_ID'",
    "productId": "landfinder_monthly",
    "receiptData": "base64-encoded-receipt-data",
    "environment": "sandbox"
  }'

# Expected: Same response structure as Google Play
```

### 2.4 Verify Purchase Stored in Database

After successful verification, check database:

```sql
-- Query purchase_history
SELECT * FROM purchase_history 
WHERE user_id = 'test-user-id'
ORDER BY created_at DESC 
LIMIT 1;

-- Expected: One row with verified status and filled verification_response

-- Query subscriptions
SELECT * FROM subscriptions 
WHERE user_id = 'test-user-id';

-- Expected: tier='monthly', status='active', renewal_at set
```

## Phase 3: Purchase Handler Service Testing

### 3.1 Unit Tests (Dart)

Create `test/features/subscription/data/services/purchase_handler_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:land_finder/features/subscription/data/services/purchase_handler.dart';

void main() {
  group('PurchaseHandler', () {
    late PurchaseHandler handler;

    setUp(() {
      handler = PurchaseHandler();
    });

    tearDown(() {
      handler.dispose();
    });

    test('initializes successfully', () {
      expect(handler, isNotNull);
    });

    test('purchaseUpdates stream emits states', (tester) async {
      final states = <PurchaseState>[];
      handler.purchaseUpdates.listen((result) {
        states.add(result.state);
      });

      // Simulate purchase flow
      // (Requires mock/stub of in_app_purchase)
      
      await tester.pumpAndSettle();
      
      expect(states, containsAll([
        PurchaseState.processing,
        // success or error
      ]));
    });

    test('error enum provides user messages', () {
      expect(
        PurchaseError.networkError.userMessage,
        contains('Network'),
      );
      expect(
        PurchaseError.userCancelled.userMessage,
        contains('cancelled'),
      );
    });

    test('disposes cleanly', () {
      handler.dispose();
      // Should not throw
    });
  });
}
```

**Run tests**:
```bash
flutter test test/features/subscription/data/services/purchase_handler_test.dart
```

### 3.2 Manual Android Testing (Real Device)

#### Setup
1. Install app on Android device
2. Add test Google account to device
3. Enable Google Play sandbox purchases

#### Test Flow
1. Navigate to subscription plans screen
2. Tap monthly plan → PurchaseFlowScreen opens
3. Tap "Subscribe for ₱199"
4. Google Play payment sheet appears
5. Tap "Buy" with test method (uses sandbox)
6. Wait for verification
7. Verify success screen appears
8. Check purchase_history table: new record should exist

**Expected Behavior**:
- Plan summary displays correctly
- Real-time status updates during purchase
- Success screen shows plan details
- Database has verified purchase record

**Failure Scenarios** (test error handling):
1. Cancel at payment UI → "You cancelled" error
2. Disconnect network → "Network error" message
3. Invalid product ID → "Product not found" error

### 3.3 Manual iOS Testing (Simulator)

#### Setup
1. Xcode with iOS 15+ simulator
2. StoreKit configuration file in project
3. Sandbox account setup (if needed)

#### Test Flow
1. Run app on iOS simulator
2. Navigate to subscription plans
3. Tap yearly plan → PurchaseFlowScreen opens
4. Tap "Subscribe for ₱1,999"
5. StoreKit payment UI appears (simulator only)
6. Confirm purchase
7. Wait for verification
8. Verify success screen

**Note**: StoreKit 2 simulator testing differs from real App Store. See Xcode StoreKit docs.

## Phase 4: Remote Datasource Testing

### 4.1 Unit Tests

Create `test/features/subscription/data/datasources/subscription_remote_datasource_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:land_finder/features/subscription/data/datasources/subscription_remote_datasource.dart';

class MockSupabase extends Mock implements Supabase {}

void main() {
  group('SubscriptionRemoteDatasource', () {
    late MockSupabase mockSupabase;
    late SubscriptionRemoteDatasource datasource;

    setUp(() {
      mockSupabase = MockSupabase();
      datasource = SubscriptionRemoteDatasource(mockSupabase);
    });

    test('getCurrentSubscription returns subscription', () async {
      // Mock Supabase response
      when(mockSupabase.auth.currentUser?.id)
          .thenReturn('test-user-id');
      when(mockSupabase.from('subscriptions')
          .select()
          .eq('user_id', any)
          .single())
          .thenAnswer((_) async => {
            'user_id': 'test-user-id',
            'tier': 'monthly',
            'status': 'active',
          });

      final result = await datasource.getCurrentSubscription();
      
      expect(result, isNotNull);
      expect(result?.tier, 'monthly');
    });

    test('verifyAndUpdateSubscription calls verification endpoint', () async {
      when(mockSupabase.auth.currentUser?.id)
          .thenReturn('test-user-id');
      when(mockSupabase.functions.invoke(any, body: anyNamed('body')))
          .thenAnswer((_) async => {
            'verified': true,
            'subscriptionTier': 'monthly',
          });

      await datasource.verifyAndUpdateSubscription(
        productId: 'com.landfinder.app.monthly',
        purchaseToken: 'token-123',
        receiptData: null,
        isAndroid: true,
      );

      verify(mockSupabase.functions.invoke(
        'verify_google_play_purchase',
        body: anyNamed('body'),
      )).called(1);
    });

    test('restorePurchases returns current subscription', () async {
      final result = await datasource.restorePurchases(
        purchaseToken: null,
        receiptData: null,
        isAndroid: true,
      );

      // Should fetch current subscription if no purchase to restore
      expect(result, isNotNull);
    });
  });
}
```

**Run tests**:
```bash
flutter test test/features/subscription/data/datasources/
```

## Phase 5: UI Screens Testing

### 5.1 Widget Tests

Create `test/features/subscription/presentation/screens/purchase_flow_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:land_finder/features/subscription/data/models/plan_model.dart';
import 'package:land_finder/features/subscription/presentation/screens/purchase_flow_screen.dart';
import 'package:land_finder/core/enums/subscription_tier.dart';

void main() {
  group('PurchaseFlowScreen', () {
    final testPlan = PlanModel(
      id: 'monthly_plan',
      tier: SubscriptionTier.monthly,
      title: 'Monthly Premium',
      priceLabel: '₱199',
      billingLabel: 'Per month',
      features: ['Feature 1', 'Feature 2'],
    );

    testWidgets('displays plan summary', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PurchaseFlowScreen(
          plan: testPlan,
          onSuccess: () {},
        ),
      ));

      expect(find.text('Monthly Premium'), findsOneWidget);
      expect(find.text('₱199'), findsOneWidget);
      expect(find.text('Feature 1'), findsOneWidget);
    });

    testWidgets('shows subscribe button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PurchaseFlowScreen(
          plan: testPlan,
          onSuccess: () {},
        ),
      ));

      expect(
        find.byWidgetPredicate(
          (widget) => widget is ElevatedButton &&
              widget.child is Text &&
              (widget.child as Text).data?.contains('Subscribe') ?? false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays error when purchase fails', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PurchaseFlowScreen(
          plan: testPlan,
          onSuccess: () {},
        ),
      ));

      // Simulate error state (requires PurchaseHandler mock)
      // Verify error message appears
    });
  });
}
```

**Run tests**:
```bash
flutter test test/features/subscription/presentation/screens/
```

### 5.2 Integration Tests

Create `integration_test/subscription_purchase_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:land_finder/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Purchase Flow Integration', () {
    testWidgets('complete purchase flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to subscription screen
      await tester.tap(find.byIcon(Icons.card_membership));
      await tester.pumpAndSettle();

      // Tap on plan
      await tester.tap(find.text('Monthly Premium'));
      await tester.pumpAndSettle();

      // Verify PurchaseFlowScreen opened
      expect(find.text('Complete Purchase'), findsOneWidget);

      // Tap subscribe button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // On real device: Google Play payment UI would appear
      // On emulator: Would show mock payment
    });
  });
}
```

**Run integration tests**:
```bash
# On Android device
flutter drive --target=integration_test/subscription_purchase_flow_test.dart

# Or use integration_test driver
flutter test integration_test/subscription_purchase_flow_test.dart
```

## Phase 6: End-to-End Testing

### 6.1 Test Scenario: Complete Purchase Flow

**Setup**:
1. Fresh user account (or logged out)
2. Device with payment method configured
3. App in debug mode

**Steps**:
1. ✓ Launch app
2. ✓ Sign in with test account
3. ✓ Navigate to subscription plans
4. ✓ Tap monthly plan
5. ✓ See purchase flow screen
6. ✓ Tap "Subscribe for ₱199"
7. ✓ Payment UI appears (Google Play / App Store)
8. ✓ Complete purchase (may use test payment method)
9. ✓ See loading state
10. ✓ See success screen
11. ✓ Tap "Start Using Premium"
12. ✓ App recognizes premium tier
13. ✓ Premium features available

**Verification**:
```sql
-- Check database
SELECT * FROM purchase_history 
WHERE user_id = '<test-user-id>'
ORDER BY created_at DESC LIMIT 1;

-- Should show: verified status, store_transaction_id populated

SELECT * FROM subscriptions 
WHERE user_id = '<test-user-id>';

-- Should show: tier='monthly', status='active'
```

### 6.2 Test Scenario: Restore Purchase

**Setup**:
1. Already purchased user
2. Fresh app install

**Steps**:
1. ✓ Launch app
2. ✓ Sign in (may auto-restore)
3. ✓ Check subscription screen
4. ✓ See "Restore Purchases" button
5. ✓ Tap restore
6. ✓ See loading state
7. ✓ See success message (or "no purchases found")

**Verification**:
- If purchase exists in store: Restored and showing
- If no purchase: "No active purchase found" message

### 6.3 Test Scenario: Error Recovery

**Test Network Error**:
1. Turn off internet
2. Try to purchase
3. See "Network error" message
4. Turn internet back on
5. Tap "Try Again"
6. Purchase succeeds

**Test Cross-User Protection**:
1. User A purchases
2. User A logs out
3. User B logs in
4. Try to verify User A's purchase
5. See "Unauthorized" error

## Phase 7: Performance Testing

### 7.1 Verification Endpoint Performance

```bash
# Install ab (Apache Bench)
ab -n 100 -c 10 \
  -H "Authorization: Bearer $TOKEN" \
  -p request.json \
  https://[PROJECT_ID].supabase.co/functions/v1/verify_google_play_purchase

# Expected: < 200ms median response time
# Max: < 1000ms 99th percentile
```

### 7.2 Database Query Performance

```sql
-- Check index on store_transaction_id
EXPLAIN ANALYZE 
SELECT * FROM purchase_history 
WHERE store_transaction_id = 'test-id';

-- Should use index scan, not sequential scan
```

## Phase 8: Deployment Checklist

Before deploying to production:

- [ ] All database schema applied
- [ ] RLS policies enabled and tested
- [ ] Edge Functions deployed to production
- [ ] Environment variables configured:
  - `GOOGLE_PLAY_MONTHLY_SKU`
  - `GOOGLE_PLAY_YEARLY_SKU`
  - `APPLE_MONTHLY_SKU`
  - `APPLE_YEARLY_SKU`
  - `APPLE_SHARED_SECRET`
  - `GOOGLE_PLAY_CREDENTIALS`
- [ ] Products created in Google Play Console
- [ ] Products created in App Store Connect
- [ ] Purchase history API endpoint rate limited
- [ ] Error logging configured
- [ ] Monitoring/alerts set up
- [ ] Rollback procedure documented
- [ ] User communication prepared (terms, billing info)
- [ ] Support team trained

## Troubleshooting Guide

### "Product not found" Error
- Verify product ID matches Google Play Console / App Store Connect
- Confirm products are published (not in draft)
- Check product IDs in app match configuration

### "Verification failed" on Sandbox
- Ensure using sandbox test account (not production)
- Check receipt format is base64 encoded (iOS)
- Verify APPLE_SHARED_SECRET is correct

### Database Records Not Creating
- Check RLS policies aren't blocking inserts
- Verify user is authenticated
- Check purchase_history constraints (unique, not null)
- Review Supabase function logs

### Edge Function Returns 401
- Verify auth token is valid and not expired
- Check "Authorization: Bearer" header format
- Confirm JWT includes `sub` claim (user ID)

## Support & Next Steps

For issues or questions:
1. Check function logs: `supabase functions logs verify_google_play_purchase`
2. Review database migrations: `supabase db pull`
3. Test with curl before troubleshooting app
4. Check Supabase status page for outages

**Next Phase**: Phase 2.6 (Controller Integration)
