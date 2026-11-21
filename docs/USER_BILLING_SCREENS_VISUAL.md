# 🎨 Billing Navigation - Visual Screens Reference

## **Screen 1: Profile Tab (Entry Point)**

```
┌─────────────────────────────┐
│          PROFILE            │
├─────────────────────────────┤
│                             │
│      [👤 Avatar]            │
│    "John Doe"               │
│  Real Estate Buyer          │
│                             │
├─────────────────────────────┤
│ 👤 Account                  │
│    Personal contact details ➜ │
├─────────────────────────────┤
│ 🏆 Subscription             │
│    Current plan: Free   ➜   │  ← TAP HERE
├─────────────────────────────┤
│ 👥 Agent Teams              │
│    View and request     ➜   │
├─────────────────────────────┤
│ ⚙️  Settings                 │
│    App preferences      ➜   │
│                             │
│ 🚪 Sign Out                 │
└─────────────────────────────┘
```

**Key Component:**
- **Card**: ListTile with premium icon
- **Info**: Shows current plan + expiry (if premium)
- **Action**: Tap to open Subscription Screen

---

## **Screen 2: Subscription Page (Current Plan & Status)**

```
┌─────────────────────────────┐
│    SUBSCRIPTION PLAN        │  ← Back button in header
├─────────────────────────────┤
│                             │
│   ⭐ FREE PLAN ⭐            │
│    Current Plan             │
│                             │
│   📋 Your Features:         │
│   ✓ Browse lot listings     │
│   ✓ Message agents          │
│   ✓ Save up to 3 lots       │
│                             │
├─────────────────────────────┤
│                             │
│  [Browse Plans Button]      │  ← TAP TO VIEW PRICING
│                             │
│  [Restore Purchases] (if applicable)
│                             │
│                             │
│  💡 Upgrade to Premium for: │
│  • Unlimited saved lots     │
│  • Advanced filters         │
│  • Premium analytics        │
│                             │
└─────────────────────────────┘
```

**Key Features:**
- Current plan displayed prominently
- Features included listed
- Quick upgrade prompt
- Restore purchase option (verified through the store)

---

## **Screen 3: Plans Screen (Pricing & Selection)**

```
┌─────────────────────────────┐
│      CHOOSE YOUR PLAN       │
├─────────────────────────────┤
│                             │
│   📱 FREE PLAN              │
│   ₱0                        │
│   Current Plan ✓            │
│                             │
│   ✓ Browse lot listings     │
│   ✓ Message agents          │
│   ✓ Save up to 3 lots       │
│   _____________________     │
│        [Already Free]       │
│                             │
├─────────────────────────────┤
│                             │
│   📊 MONTHLY PLAN ⭐        │
│   ₱199/month                │
│                             │
│   ✓ Unlimited saved lots    │
│   ✓ Premium-only gates      │
│   ✓ Premium analytics       │
│   _____________________     │
│      [Subscribe Now] ✨     │  ← TAP TO PURCHASE
│                             │
├─────────────────────────────┤
│                             │
│   💎 YEARLY PLAN 🏆        │
│   ₱1,999/year               │
│   Save ₱379 vs monthly      │
│                             │
│   ✓ Everything in Monthly   │
│   ✓ Save up to 2 years      │
│   ✓ Best value              │
│   _____________________     │
│      [Subscribe Now] ✨     │  ← TAP TO PURCHASE
│                             │
│   📝 Continue with Free     │
│                             │
└─────────────────────────────┘
```

**Features:**
- Three clear pricing tiers
- Feature comparison
- Selected plan marked
- "Subscribe Now" buttons with visual emphasis

---

## **Screen 4: Purchase Flow (Checkout & Payment)**

```
┌─────────────────────────────┐
│     COMPLETE PURCHASE       │
├─────────────────────────────┤
│                             │
│   📋 Order Summary          │
│   ┌─────────────────────┐   │
│   │ MONTHLY PLAN        │   │
│   │ ₱199                │   │
│   │ Renews monthly      │   │
│   │                     │   │
│   │ ✓ Unlimited saves   │   │
│   │ ✓ Premium features  │   │
│   │ ✓ Analytics         │   │
│   └─────────────────────┘   │
│                             │
├─────────────────────────────┤
│                             │
│   PROCESSING... ⏳          │
│   [◯◯◯◯◯◯◯]  70%           │
│   Verifying with store...   │
│                             │
│                             │
│   [Cancel] [Retry]          │
│                             │
└─────────────────────────────┘
```

**States:**

### **Idle State (Ready to Purchase)**
```
├─────────────────────────────┤
│  [Complete Purchase] ✅     │  ← Tap to start
│  [Restore Purchase]         │
└─────────────────────────────┘
```

### **Processing State (In Progress)**
```
├─────────────────────────────┤
│  PROCESSING... ⏳            │
│  [◯◯◯◯◯◯◯]  70%            │
│  "Communicating with store" │
│  Please wait...             │
│  [Cancel]                   │
└─────────────────────────────┘
```

### **Success State (Completed ✅)**
```
├─────────────────────────────┤
│  ✅ PURCHASE SUCCESSFUL!    │
│                             │
│  Your subscription starts   │
│  immediately!               │
│                             │
│  [View Details]             │
│  [Start Browsing]           │
└─────────────────────────────┘
```

### **Error State (Failed ❌)**
```
├─────────────────────────────┤
│  ❌ PURCHASE FAILED         │
│                             │
│  Network error detected     │
│  Please check connection    │
│  and try again.             │
│                             │
│  [Retry Purchase]           │
│  [Cancel]                   │
│                             │
│  💬 Need help?              │
│  Contact support            │
└─────────────────────────────┘
```

---

## **Screen 5: Purchase Success (Confirmation)**

```
┌─────────────────────────────┐
│    PURCHASE COMPLETE        │
├─────────────────────────────┤
│                             │
│          ✅                 │
│    Thank you!               │
│                             │
│  Your Monthly Plan is       │
│  now active!                │
│                             │
│  ┌─────────────────────┐    │
│  │ Subscription Details │   │
│  │                     │    │
│  │ Plan: Monthly       │    │
│  │ Price: ₱199         │    │
│  │ Renews: 17 Dec 2026 │    │
│  │                     │    │
│  │ Enjoy premium       │    │
│  │ features!           │    │
│  └─────────────────────┘    │
│                             │
│  [Start Browsing] 🏠        │  ← Back to home
│                             │
│  Next payment: 17 Dec 2026  │
│  Auto-renewable             │
│  Can cancel anytime         │
│                             │
└─────────────────────────────┘
```

---

## **Premium Feature Gate Examples**

### **Saved Properties Tab (Limit Reached)**
```
┌─────────────────────────────┐
│   SAVED PROPERTIES          │
├─────────────────────────────┤
│                             │
│ Lot #1234 - Bacolod ✓       │
│ Lot #5678 - Silay  ✓        │
│ Lot #9012 - Cadiz  ✓        │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🔒 Limit Reached!      │ │
│ │                         │ │
│ │ You can only save 3     │ │
│ │ properties with Free.   │ │
│ │                         │ │
│ │ Upgrade to Premium for: │ │
│ │ • Unlimited saves      │ │
│ │ • Compare side-by-side │ │
│ │ • Price alerts         │ │
│ │                         │ │
│ │ [Upgrade Now] ✨       │ │  ← Opens subscription
│ │ [Continue Free]        │ │
│ └─────────────────────────┘ │
│                             │
└─────────────────────────────┘
```

### **Property Details (Premium Only Section)**
```
┌─────────────────────────────┐
│   PROPERTY DETAILS          │
├─────────────────────────────┤
│                             │
│ Lot #1234 - Bacolod         │
│ 500 m² | ₱150,000           │
│                             │
│ 🔓 Public Info:             │
│ • Location: Bacolod City    │
│ • Owner: Local Builder      │
│ • Contact: Show details     │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🔒 Premium Only         │ │
│ │                         │ │
│ │ Advanced Analytics:     │ │
│ │ 📊 Price trends        │ │
│ │ 📍 Neighborhood scores │ │
│ │ 💰 ROI Estimates       │ │
│ │ 🏘️  Demographic data    │ │
│ │                         │ │
│ │ [Unlock Premium] ✨    │ │
│ └─────────────────────────┘ │
│                             │
│ [Message Agent] [Save]      │
│                             │
└─────────────────────────────┘
```

---

## **Full User Journey Diagram**

```
START: Home Screen
  │
  ├─► User browses free properties
  │   └─► Hits premium feature limit
  │       └─► "Upgrade to Premium" sheet appears
  │           └─► Tap [View Plans]
  │               ↓
  │
  ├─► Profile Tab (Alternative entry)
  │   └─► Tap [Subscription] card
  │       ↓
  │
  SUBSCRIPTION SCREEN (Current Plan & Status)
  │
  ├─► If Premium:
  │   └─► Show renewal date
  │       └─► Option to cancel
  │
  ├─► If Free:
  │   └─► Show benefits comparison
  │       └─► Tap [Browse Plans]
  │           ↓
  │
  PLANS SCREEN (Pricing Tiers)
  │
  ├─► Select Free → Back to subscription (no change)
  │
  ├─► Select Monthly ₱199
  │   └─► Tap [Subscribe Now]
  │       ↓
  │
  PURCHASE FLOW SCREEN (Payment)
  │
  ├─► Processing... (Communicating with Google Play/App Store)
  │   │
  │   ├─► ✅ Success
  │   │   └─► PURCHASE SUCCESS SCREEN
  │   │       └─► Subscription activated
  │   │           └─► Tap [Start Browsing]
  │   │               └─► Return to Home (with premium active)
  │   │
  │   └─► ❌ Error
  │       └─► Show error message
  │           └─► Tap [Retry]
  │               └─► Try payment again
  │
  └─► Yearly ₱1,999 (Same as Monthly)

RESULT: User now Premium! 🎉
  • Can save unlimited properties
  • Access premium features
  • Use advanced filters
  • Auto-renews on set date
```

---

## **Key UI Components**

| Component | Location | Purpose |
|-----------|----------|---------|
| **Subscription Card** | Profile Tab | Entry point to manage subscription |
| **Browse Plans Button** | Subscription Screen | Navigate to pricing |
| **Plan Cards** | Plans Screen | Show pricing & features |
| **Subscribe Button** | Plans Screen | Initiate purchase |
| **Purchase Progress** | Purchase Flow | Show payment status |
| **Success Confirmation** | Success Screen | Confirm subscription active |
| **Premium Gate Sheets** | Various | Prompt upgrade from features |

---

## **Navigation State Machine**

```
┌──────────────────────┐
│   HOME SCREEN        │
│  (Any Tab)           │
└──────────────────────┘
         │
         ├─→ [View Plans] ──┐
         │                  │
         ├─→ Upgrade Prompt─┤
         │                  │
         └─→ Profile Tab ───┤
                            ↓
              ┌─────────────────────────┐
              │  SUBSCRIPTION SCREEN    │
              │  (Current plan + status)│
              └─────────────────────────┘
                            │
                            ↓
              ┌─────────────────────────┐
              │  PLANS SCREEN           │
              │  (Free/Monthly/Yearly)  │
              └─────────────────────────┘
                            │
                    ┌───────┴────────┐
                    ↓                ↓
            [Free - No Change]  [Premium]
                    │                │
                    └────┬───────────┘
                         ↓
        ┌──────────────────────────────┐
        │  PURCHASE FLOW SCREEN        │
        │  (Payment processing)        │
        └──────────────────────────────┘
              │
         ┌────┴───────┐
         ↓            ↓
      Success    Error/Cancel
         │            │
         ↓            ↓
      ┌──────┐    ┌────────┐
      │ ✅   │    │ ❌    │
      │ Conf │    │ Retry │
      └───┬──┘    └───┬────┘
          │           │
          └─────┬─────┘
                ↓
    ┌───────────────────────┐
    │ Return to Home/Browse │
    │ (Premium now active)  │
    └───────────────────────┘
```

---

## **Testing Checklist** ✅

- [ ] Can navigate to Profile → Subscription from any screen
- [ ] Subscription card shows current plan correctly
- [ ] Clicking card opens Subscription Screen
- [ ] "Browse Plans" shows three pricing tiers
- [ ] Can see plan details and features
- [ ] Clicking subscribe button shows Purchase Flow
- [ ] Purchase shows processing state during payment
- [ ] Success screen appears after completion
- [ ] Success screen shows subscription details
- [ ] Can return to home after purchase
- [ ] Premium features now available
- [ ] Profile shows updated subscription status
- [ ] Can view renewal date in subscription card

