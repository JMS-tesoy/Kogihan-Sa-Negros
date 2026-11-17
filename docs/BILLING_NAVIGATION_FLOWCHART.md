# 🎯 Billing Navigation - Visual Flowchart

## **Shortest Answer 🏃‍♂️**

```
Profile Tab 👤 → Subscription Card 🏆 → Browse Plans → Select → Purchase ✅
```

---

## **Complete User Flow Diagram**

```
                        ╔════════════════════════╗
                        ║   LAND FINDER HOME     ║
                        ║   (Any Screen)         ║
                        ╚════════════════════════╝
                                  │
                    ┌─────────────┼──────────────┐
                    │             │              │
                    ↓             ↓              ↓
            ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
            │ PROFILE TAB  │ │ UPGRADE GATE │ │ FEATURE GATE │
            │ (Entry #1) ✅│ │ (Entry #2)   │ │ (Entry #3)   │
            └──────────────┘ └──────────────┘ └──────────────┘
                    │             │              │
                    │ Tap on:      │ Tap:         │ Tap:
                    │ [🏆 Subscr.] │ [Upgrade] or │ [Unlock]
                    │ Card         │ [View Plans] │
                    └─────────────┬┴──────────────┴─────────────┘
                                  │
                        ╔════════════════════════╗
                        ║ SUBSCRIPTION SCREEN ✅ ║
                        ║                        ║
                        ║ Shows:                 ║
                        ║ • Current plan (Free)  ║
                        ║ • Plan details         ║
                        ║ • Benefits list        ║
                        ║                        ║
                        ║ [Browse Plans]         ║
                        ║ [Restore Purchases]    ║
                        ╚════════════════════════╝
                                  │
                        Tap: [Browse Plans]
                                  │
                        ╔════════════════════════╗
                        ║ PLANS SCREEN ✅        ║
                        ║                        ║
                        ║ ┌──────────────────┐   ║
                        ║ │ FREE ₱0 ✓ Current│   ║
                        ║ │ 3 saves, basic   │   ║
                        ║ ├──────────────────┤   ║
                        ║ │ MONTHLY ₱199 🌟  │   ║
                        ║ │ Unlimited saves  │   ║
                        ║ │ [Subscribe Now]◀─┼───╫─→ Select Monthly
                        ║ ├──────────────────┤   ║
                        ║ │ YEARLY ₱1,999 🏆 │   ║
                        ║ │ Best value       │   ║
                        ║ │ [Subscribe Now]◀─┼───╫─→ Select Yearly
                        ║ └──────────────────┘   ║
                        ╚════════════════════════╝
                                  │
                    ┌─────────────┴──────────────┐
                    │                            │
            Tap [Subscribe Now]      Tap [Subscribe Now]
                    │                            │
                    ↓                            ↓
        ╔═════════════════════╗    ╔═════════════════════╗
        ║ MONTHLY PLAN        ║    ║ YEARLY PLAN         ║
        ║ ₱199/month          ║    ║ ₱1,999/year         ║
        ║ Renews monthly      ║    ║ Renews yearly       ║
        ╚═════════════════════╝    ╚═════════════════════╝
                    │                            │
                    └─────────────┬──────────────┘
                                  │
                        ╔════════════════════════╗
                        ║ PURCHASE FLOW ✅       ║
                        ║                        ║
                        ║ 📋 Order Summary       ║
                        ║ ┌─────────────────┐   ║
                        ║ │ Selected Plan   │   ║
                        ║ │ ₱199 (Monthly)  │   ║
                        ║ │ or              │   ║
                        ║ │ ₱1,999 (Yearly) │   ║
                        ║ └─────────────────┘   ║
                        ║                        ║
                        ║ [Complete Purchase]    ║
                        ║ [Cancel]               ║
                        ╚════════════════════════╝
                                  │
                        Tap: [Complete Purchase]
                                  │
                        ╔════════════════════════╗
                        ║ PROCESSING PAYMENT ⏳  ║
                        ║                        ║
                        ║ Connecting to:         ║
                        ║ • Google Play (Android)║
                        ║ • App Store (iOS)      ║
                        ║                        ║
                        ║ [◯◯◯◯◯◯◯]  70%        ║
                        ║ Please wait...         ║
                        ║                        ║
                        ║ [Cancel] [Retry]       ║
                        ╚════════════════════════╝
                                  │
                    ┌─────────────┴──────────────┐
                    │                            │
                ✅ Success                   ❌ Error
                    │                            │
                    ↓                            ↓
        ╔═════════════════════╗    ╔═════════════════════╗
        ║ PURCHASE SUCCESS ✅  ║    ║ PAYMENT ERROR ❌    ║
        ║                     ║    ║                     ║
        ║ ✅ Confirmed!       ║    ║ ❌ Payment Failed   ║
        ║                     ║    ║                     ║
        ║ Subscription:       ║    ║ Reason:             ║
        ║ • Plan: Monthly     ║    ║ • Network error     ║
        ║ • Price: ₱199       ║    ║ • Invalid card      ║
        ║ • Renews: Dec 15    ║    ║ • Cancelled         ║
        ║                     ║    ║                     ║
        ║ [Start Browsing]    ║    ║ [Retry Payment]     ║
        ║ [View Details]      ║    ║ [Cancel]            ║
        ╚═════════════════════╝    ╚═════════════════════╝
                    │                            │
                    │ Tap:                       │ Tap:
                    │ [Start Browsing]           │ [Retry Payment]
                    │                            └─────────────┐
                    │                                          │
                    └──────────────────┬───────────────────────┘
                                       │
                        ╔════════════════════════╗
                        ║ HOME SCREEN 🏠         ║
                        ║                        ║
                        ║ 🎉 Premium Active!    ║
                        ║                        ║
                        ║ Now you can:           ║
                        ║ ✅ Save unlimited lots ║
                        ║ ✅ Use premium filters ║
                        ║ ✅ View analytics      ║
                        ║ ✅ Join teams          ║
                        ║                        ║
                        ║ Subscription:          ║
                        ║ Renews: Dec 15, 2026   ║
                        ║ Can cancel anytime     ║
                        ╚════════════════════════╝
```

---

## **Decision Tree: Where to Access Billing**

```
                    Want to check/buy subscription?
                                  │
                    ┌─────────────┴──────────────┐
                    │                            │
            Easy access?            Context-dependent?
                    │                            │
                    ↓                            ↓
            ┌──────────────┐    ┌────────────────────┐
            │ Go to Profile│    │ Encounter limit:    │
            │ Tab (👤)     │    │ • Save 4th property │
            │ Tap on       │    │ • Join team         │
            │ Subscription │    │ • Use premium filter│
            │ Card         │    │ • View analytics    │
            └──────────────┘    └────────────────────┘
                    │                            │
                    └─────────────┬──────────────┘
                                  │
                        Tap [Upgrade] or
                        [Browse Plans]
                                  │
                        ╔════════════════════════╗
                        ║ SUBSCRIPTION SCREEN    ║
                        ╚════════════════════════╝
```

---

## **Status at Each Screen**

```
┌─────────────────────────────────────────────────────────────┐
│ Screen              │ Status              │ Action          │
├─────────────────────────────────────────────────────────────┤
│ Profile Tab         │ Show current plan   │ Tap to open     │
│ Subscription Screen │ Display benefits    │ Browse Plans    │
│ Plans Screen        │ Show all options    │ Select & Buy    │
│ Purchase Flow       │ Processing...       │ Wait/Retry      │
│ Success/Error       │ Payment result      │ Continue/Retry  │
│ Home Screen         │ Premium activated   │ Enjoy features  │
└─────────────────────────────────────────────────────────────┘
```

---

## **User Types & Their Paths**

### **👤 Free User (Just Curious)**
```
Profile → Subscription → Browse Plans → Browse Only → Back
(No purchase)
```

### **💳 Free User (Wants to Buy)**
```
Profile → Subscription → Browse Plans → Select Plan → Purchase Flow 
→ Success ✅ → Start Using Premium
```

### **🔄 Existing Premium (Check Status)**
```
Profile → Subscription → View Renewal Date → Cancel/Keep
```

### **💰 Premium User (Upgrade Plan)**
```
Profile → Subscription → Browse Plans → Upgrade Plan → Purchase Flow
→ Success ✅ → New Plan Active
```

### **⚡ Feature-Triggered (Hits Premium Gate)**
```
Browsing → Hit Limit → "Upgrade" Prompt → Subscription Screen
→ Browse Plans → Purchase Flow → Success ✅ → Continue Feature
```

---

## **Touch Points in App**

```
HOME SCREEN
├─ Home Tab
│  └─ "Upgrade to Premium" Card
│     └─ [View Plans] → Subscription Screen
│
├─ Profile Tab ✅ MAIN ENTRY
│  └─ Subscription Card (with status)
│     └─ [Tap Card] → Subscription Screen
│
└─ Saved Properties Tab
   └─ Save 4th property
      └─ "Upgrade" Gate
         └─ [Upgrade Now] → Subscription Screen

PROPERTY DETAILS SCREEN
└─ View Premium Analytics
   └─ "🔒 Premium Only" gate
      └─ [Unlock] → Subscription Screen

AGENT TEAMS SCREEN
└─ Join Premium Team
   └─ "🔒 Premium Required" gate
      └─ [Join Premium] → Subscription Screen

SEARCH RESULTS SCREEN
└─ Advanced Filters
   └─ "🔒 Premium Features" badge
      └─ [Upgrade] → Subscription Screen
```

---

## **Information Flow**

```
User Actions → UI Updates → Database Updates → Premium Features Unlock
│              │            │                 │
│              ├─ Tap Subscription
│              ├─ Tap Plans
│              ├─ Tap Subscribe
│              ├─ Tap Purchase
│              │
│              └─ Payment Processing
│                 ├─ Connecting to store
│                 ├─ Verifying receipt
│                 ├─ Updating DB
│                 └─ Showing result
│
└─ Success
   ├─ DB records purchase
   ├─ Sets premium status
   ├─ Enables all features
   └─ Recalculates limits
```

---

## **Quick Stats**

| Metric | Value |
|--------|-------|
| **Total Screens** | 5 (Profile → Plans → Purchase → Success + Subscription) |
| **Entry Points** | 3 (Profile, Upgrade Gates, Feature Links) |
| **Navigation Depth** | 4 steps (Profile → Subscription → Plans → Purchase) |
| **Plan Options** | 3 (Free, Monthly, Yearly) |
| **Back Button Support** | ✅ All screens |
| **Time to Purchase** | ~1 minute |
| **UI Status** | ✅ 100% Complete |
| **Payment Status** | ⏳ Coming Phase 2.6+ |

---

## **Technical Routes**

```
RouteNames.subscription  → SubscriptionScreen
                           └─→ [Browse Plans]
                               └─→ PlansScreen
                                   └─→ [Subscribe]
                                       └─→ PurchaseFlowScreen
                                           └─→ [Process]
                                               └─→ SuccessScreen
                                                   └─→ Home
```

---

**📊 Summary:** 
- **Most direct:** Profile → Subscription → Plans → Buy ✅
- **Most intuitive:** Via upgrade prompts when hitting limits
- **All paths converge:** At Subscription Screen
- **UI complete:** ✅ Ready to use
- **Backend pending:** ⏳ Phase 2.6+ for real payments
