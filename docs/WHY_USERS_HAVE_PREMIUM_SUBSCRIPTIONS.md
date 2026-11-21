# 💡 Why Some Users Have Premium Active Subscription

## **Quick Answer**

Users have premium active subscription for **3 reasons:**

1. **They Purchased It** ✅ (Most common)
   - User went through purchase flow
   - Made payment via Google Play or App Store
   - Store receipt is verified by an Edge Function
   - Verified subscription event recorded in `purchase_history`
   - `subscriptions.tier` set to `monthly` or `yearly`
   - Expiry date set in future

2. **Admin Manually Set It** 🔧 (Testing/Support)
   - Admin can directly update `subscriptions` table
   - Set `tier = 'monthly'` or `tier = 'yearly'`
   - Set `expires_at` to future date
   - User immediately shows as premium

3. **Test/Seed Data** 🧪 (Development)
   - Demo users created with premium tier
   - For testing premium features without payment
   - In Supabase studio for local testing

---

## **How Premium Status is Determined**

### **Code Logic (isPremium getter):**

```dart
// From SubscriptionEntity
bool get isPremium {
  if (status != SubscriptionStatus.active) return false; // Active only
  if (tier == SubscriptionTier.free) return false;      // Free = NOT premium
  if (expiresAt == null) return false;                  // Fail closed
  return expiresAt!.isAfter(DateTime.now());            // After now = premium
}
```

**In plain English:**
- If tier is `free` → NOT premium
- If status is not `active` → NOT premium
- If tier is `monthly` or `yearly` AND expiry is in future → Premium ✅
- If tier is `monthly` or `yearly` BUT expiry is in past → NOT premium (expired)
- A paid tier without a verified expiry is NOT premium

---

## **Data Flow: How Premium Gets Set**

### **Path 1: User Purchases a Verified Subscription**

```
User taps "Subscribe Now"
  ↓
Payment processes through store
  ↓
Receipt sent to backend Edge Function
  ↓
Edge Function authenticates user and verifies receipt with Google Play/App Store
  ↓
Backend atomically records the provider-verified event
  ↓
Backend updates subscriptions table:
  - tier = 'monthly' (or 'yearly')
  - expires_at = purchase_date + 30 days (or 365)
  - status = 'active'
  ↓
App receives subscription update
  ↓
appSubscriptionNotifier updates
  ↓
UI shows premium features unlocked! 🎉
```

### **Path 2: Admin Updates (Testing)**

```
Admin opens Supabase Studio
  ↓
Navigates to subscriptions table
  ↓
Finds user row
  ↓
Updates columns:
  - tier: 'free' → 'monthly'
  - expires_at: NULL → 2027-12-17
  - status: 'active'
  ↓
Save changes
  ↓
Next time app loads subscription:
  - Fetches from the database before trusting cached access
  - Sees tier='monthly' + future expiry
  - Sets isPremium = true
  ↓
User now appears premium ✅
```

---

## **Database Structure**

### **Subscriptions Table**

```
subscriptions
├─ id (UUID primary key)
├─ user_id (links to profiles)
├─ tier (TEXT)
│  ├─ 'free' (default for all new users)
│  ├─ 'monthly' (₱199/month after purchase)
│  └─ 'yearly' (₱1,999/year after purchase)
├─ status (TEXT)
│  ├─ 'active'
│  ├─ 'cancelled' (user cancelled)
│  ├─ 'expired' (subscription ended)
│  └─ 'paused'
├─ expires_at (TIMESTAMP)
│  ├─ NULL for free users (no paid entitlement)
│  ├─ Future date for active premium
│  └─ Past date for expired premium
├─ auto_renew (BOOLEAN - default true)
└─ verified_purchase_id (links to purchase_history)
```

### **Purchase History Table**

```
purchase_history (created Phase 2.5)
├─ id (UUID primary key)
├─ user_id
├─ product_id ('google_play_monthly', etc)
├─ store ('google_play' or 'app_store')
├─ store_transaction_id (unique receipt ID from store)
├─ purchase_date
├─ expiry_date
├─ status ('pending', 'verified', 'failed', etc)
├─ verification_status ('verified' = real purchase)
└─ verification_response (store's response)
```

---

## **Key Insight: Trigger Creates Free Subscriptions**

When a new user signs up:

```sql
-- This trigger runs automatically
CREATE TRIGGER trigger_create_default_subscription
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.create_default_subscription();

-- This function runs
CREATE FUNCTION public.create_default_subscription()
  RETURNS TRIGGER AS $$
  BEGIN
    INSERT INTO subscriptions (user_id, tier, status)
    VALUES (NEW.id, 'free', 'active');
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;
```

**What this means:**
- **Every new user automatically gets a row in `subscriptions` table**
- **Default tier is always `'free'`**
- **Default status is always `'active'`**
- **expires_at is NULL (no expiration for free)**

So **NO user starts with premium** - they must either:
1. Purchase it
2. Have admin set it for testing
3. Be a test/demo user in seed data

---

## **Checking User Premium Status in Code**

### **Method 1: Check the Entity**

```dart
// In controller or screen
final SubscriptionEntity? subscription = await repository.getCurrentSubscription();

if (subscription?.isPremium == true) {
  // User is premium
  print('Premium user! Tier: ${subscription.tier}');
} else {
  // User is free
  print('Free user');
}
```

### **Method 2: Check the Global Notifier**

```dart
// Anywhere in the app
import 'features/subscription/data/services/subscription_service.dart';

final isPremium = appSubscriptionNotifier.value.isPremium;
if (isPremium) {
  // Show premium features
} else {
  // Show premium gate
}
```

### **Method 3: Check Database Directly (SQL)**

```sql
-- Check specific user
SELECT tier, expires_at, status
FROM subscriptions
WHERE user_id = 'user-uuid';

-- Check all premium users
SELECT user_id, tier, expires_at
FROM subscriptions
WHERE tier != 'free'
  AND expires_at > NOW();

-- Count active premium subscriptions
SELECT COUNT(*)
FROM subscriptions
WHERE tier IN ('monthly', 'yearly')
  AND expires_at > NOW()
  AND status = 'active';
```

---

## **Example Scenarios**

### **Scenario 1: Brand New User**
```
User signs up with email
  ↓
Trigger creates subscriptions row:
  - tier: 'free'
  - expires_at: NULL
  - status: 'active'
  ↓
isPremium = false ❌
User sees all free limits
```

### **Scenario 2: User Makes Purchase**
```
User in app → Browse Plans → Select Monthly → Pay ₱199
  ↓
Payment processed by Google Play (Nov 17, 2026)
  ↓
Backend verifies receipt
  ↓
Backend inserts purchase_history row:
  - product_id: 'google_play_monthly'
  - purchase_date: 2026-11-17
  - expiry_date: 2026-12-17 (30 days)
  - status: 'verified'
  ↓
Backend updates subscriptions row:
  - tier: 'monthly'
  - expires_at: 2026-12-17
  - verified_purchase_id: (links to purchase_history)
  ↓
App checks isPremium:
  - status = 'active' ✓
  - tier = 'monthly' ✓
  - expires_at (Dec 17) > now ✓
  - isPremium = true ✅
  ↓
Premium features unlocked!
```

### **Scenario 3: Premium Subscription Expires**
```
User subscribed on Dec 1, 2026
Subscription expires Dec 31, 2026
  ↓
On Jan 1, 2027:
  ↓
App checks isPremium:
  - tier = 'monthly' ✓
  - expires_at (Dec 31) > now (Jan 1) ✗
  - isPremium = false ❌
  ↓
User sees: "Your subscription expired"
Revert to free features
```

### **Scenario 4: Admin Testing**
```
QA tester needs to test premium features
  ↓
Admin opens Supabase Studio
  ↓
Finds their user in subscriptions table
  ↓
Updates row:
  - tier: 'free' → 'monthly'
  - expires_at: NULL → 2030-01-01
  ↓
Tester signs in and boom! 💥
  - isPremium = true
  - All premium features visible
  ↓
Can test without paying
```

---

## **Current Implementation State**

| Item | Status | Details |
|------|--------|---------|
| **Database Schema** | ✅ Ready | `subscriptions` table created + RLS policies |
| **New Trigger** | ✅ Ready | Auto-creates free subscription for new users |
| **Purchase History** | ✅ Ready | Table ready to store verified purchases |
| **Backend Verification** | ✅ Implemented | Google Play and App Store responses are validated server-side |
| **Controller Integration** | ✅ Implemented | Purchase UI waits for backend verification before completion |
| **Schema Repair Migration** | ⏳ Deploy | Apply `20261120115021_subscription_billing_repair.sql` |
| **Provider Configuration** | ⏳ Required | Configure store credentials and exact SKU entries |
| **Provider Notifications** | ⏳ Required | Connect renewal, refund, and revocation notifications |
| **Production Validation** | ⏳ Required | Test sandbox purchase, restore, renewal, and refund flows |

Purchases are not production-ready until the repair migration, provider
credentials, product IDs, and store notifications are configured and tested.
The client fails closed when verified expiry data is unavailable.

### **PayMongo Payment Methods**

When an approved build enables external checkout, users can choose:

- **GCash** — one-time PayMongo payment for a fixed subscription term.
- **QR Ph (scan with GoTyme)** — one-time QR Ph payment for a fixed term.
- **Credit / Debit Card** — fixed-term unless the PayMongo merchant account has
  Subscriptions enabled; eligible recurring card subscriptions may auto-renew.
- **Google Play / App Store** — store-managed subscription path.

GCash and GoTyme QR Ph do not auto-renew. The browser return never grants
premium: only a signed PayMongo webhook updates the server entitlement. Store
builds hide PayMongo by default until Google/Apple external-payment eligibility
is approved for the platform and storefront.

---

## **Testing Premium Status**

### **Test 1: Check Your Current Status**
```
1. Open app
2. Go to Profile → Subscription
3. See current tier and expiry

You should see:
- If new user: "Current plan: Free"
- If purchased: "Monthly/Yearly until [DATE]"
```

### **Test 2: Check Database (Supabase Studio)**
```
1. Open Supabase Project
2. Go to Table Editor
3. Click "subscriptions" table
4. Find your user_id
5. Check tier, expires_at, status

You should see:
- tier: 'free' (unless you bought or admin set it)
- expires_at: null (for free) or future date (for premium)
- status: 'active'
```

### **Test 3: Manually Set Premium (Admin Testing)**
```
1. Supabase Studio → subscriptions table
2. Click your user row
3. Edit:
   - tier: 'monthly'
   - expires_at: 2030-01-01
4. Save
5. Refresh app → Now shows premium! 🎉
6. All premium gates disappear
7. Can test premium features without payment
```

---

## **Why Some Tests Show Premium Users**

If you see premium users in your test data:

1. **They were manually set by an admin** 🔧
   - For testing/demo purposes
   - Easier than making real purchases

2. **They made real purchases** 💳
   - From earlier testing phases
   - In sandbox/test environment
   - Money wasn't charged (test cards)

3. **They're seed/demo accounts** 🌱
   - Created for QA
   - In database migrations
   - For showing premium features

4. **Admin granted for support** ⭐
   - Customer had issue
   - Admin restored subscription
   - Goodwill gesture

---

## **Key Takeaway**

```
Premium Status ≠ Automatic

Users must EARN premium by:
  ✅ Purchasing (through store payment)
  ✅ Admin setting it (testing/support)
  
They start as FREE by default via trigger
  ↓
Database tier='free' + expires_at=null
  ↓
isPremium = false
```

---

## **Related Files**

| File | Purpose |
|------|---------|
| `subscription_entity.dart` | Contains isPremium logic |
| `subscription_service.dart` | Manages UserSubscription |
| `20261117_complete_rls_and_auth_policies.sql` | Creates subscriptions table + trigger |
| `20261119_payment_integration.sql` | Creates purchase_history table |
| `20261120115021_subscription_billing_repair.sql` | Aligns entitlement schema and permissions |
| `subscription_remote_datasource.dart` | Fetches subscription from DB |
| `subscription_screen.dart` | Shows current status to user |

---

**Summary:** Premium subscriptions come from verified store purchases or an
authorized manual grant with a future expiry. All users start free. The client
does not directly modify premium state: it verifies a store receipt, refreshes
the server entitlement, and completes the store transaction only after the
backend confirms an active, unexpired subscription. Store-managed cancellation
turns off renewal; access remains until the verified expiry date.
