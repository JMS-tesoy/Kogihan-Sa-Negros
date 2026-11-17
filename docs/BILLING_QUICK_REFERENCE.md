# ⚡ Quick Billing Navigation Guide

## 🚀 TL;DR - 3 Ways to Access Billing

### **1️⃣ EASIEST: Profile Tab**
```
Bottom Navigation
  ↓ Tap: Profile 👤
    ↓ Tap: Subscription Card 🏆
      → Subscription Screen
```

### **2️⃣ CONTEXTUAL: Upgrade Prompts**
```
Browsing Features (Low Limit Reached)
  ↓ Tap: "Upgrade to Premium" Card
    or "View Plans" Button
      → Subscription Screen
```

### **3️⃣ DIRECT: Route Navigation**
```
Navigator.pushNamed(context, RouteNames.subscription);
```

---

## 📲 User Flow (Step by Step)

```
1. User opens app
   ↓
2. Sees bottom navigation (5 tabs)
   ↓
3. Taps "Profile" tab (rightmost 👤)
   ↓
4. Scrolls to "Subscription" card (yellow/orange with 🏆 icon)
   ↓
5. Sees: "Current plan: Free"
   ↓
6. Taps card
   ↓
7. Opens SUBSCRIPTION SCREEN showing:
   - Current free plan details
   - "Browse Plans" button
   - Restore purchase option (if applicable)
   ↓
8. Taps "Browse Plans" button
   ↓
9. Opens PLANS SCREEN showing 3 options:
   - Free (₱0) - Current
   - Monthly (₱199)
   - Yearly (₱1,999)
   ↓
10. Taps "Subscribe Now" for chosen plan
    ↓
11. Opens PURCHASE FLOW SCREEN:
    - Shows plan summary
    - Shows processing status
    - Handles payment
    ↓
12. Payment succeeds/fails
    ↓
13. Shows PURCHASE SUCCESS or ERROR screen
    ↓
14. User can:
    - Tap "Start Browsing" (success) → Back to Home
    - Tap "Retry" (error) → Try payment again
    ↓
15. Premium features now available! 🎉
```

---

## 🎯 Where Users See Upgrade Prompts

| Location | Trigger | Message |
|----------|---------|---------|
| **Saved Properties Tab** | Save 4th property | "Upgrade to save unlimited properties" |
| **Property Details** | View full analytics | "🔒 Premium analytics unavailable" |
| **Agent Teams Page** | Try to join premium team | "🔒 Premium feature - Upgrade to join" |
| **Advanced Filters** | Use premium filters | "🔒 Available for premium members" |
| **Search Results** | Try advanced search | "🔒 More results with Premium" |
| **Map Screen** | Advanced map tools | "🔒 Premium map features" |
| **Home Subscription Card** | View home | "Upgrade to Premium" prompt |

---

## 💳 Subscription Status Display

### **Free User Sees:**
```
Subscription
Current plan: Free
```

### **Premium User Sees:**
```
Subscription
Monthly until Dec 15, 2026
```

---

## 🔄 Key Screens & Their Purpose

| Screen | Filename | Purpose |
|--------|----------|---------|
| **Subscription Page** | `subscription_screen.dart` | Show current plan + status |
| **Plans Page** | `plans_screen.dart` | Display pricing (Free/Monthly/Yearly) |
| **Purchase Flow** | `purchase_flow_screen.dart` | Handle payment + show status |
| **Success Page** | `purchase_success_screen.dart` | Confirm subscription active |

---

## 🔐 Premium Feature Gates

### **How They Work:**
1. Feature checks if user is premium
2. If NOT premium, shows gate overlay
3. Gate shows benefits + "Upgrade Now" button
4. Tapping button opens Subscription Screen

### **Example Code:**
```dart
if (!SubscriptionService.isPremium) {
  // Show gate
  showDialog(context, PremiumGateDialog(
    onUpgrade: () => openSubscriptionPage(context),
  ));
  return;
}

// Show premium feature
showPremiumFeature();
```

---

## ✅ Current Status

| Item | Status |
|------|--------|
| **UI Screens Built** | ✅ Complete |
| **Navigation Routes** | ✅ Connected |
| **Feature Gates** | ✅ In place |
| **UI Flow** | ✅ Working |
| **Purchase Handler** | ✅ Ready (Phase 2.5) |
| **Controller Integration** | ⏳ Phase 2.6 |
| **Real Payments** | ⏳ Phase 2.8+ |

---

## 📱 Testing on Device

1. Run: `flutter run`
2. Navigate to Profile tab (bottom right 👤)
3. Tap Subscription card (should say "Current plan: Free")
4. See Subscription Screen
5. Tap "Browse Plans"
6. See 3 pricing options
7. ⚠️ **Can't complete purchase yet** (backend in progress)
8. See error/retry screen
9. Backend verification coming in Phase 2.6+

---

## 🛠️ For Developers

### **Add Billing Button to Your Feature:**
```dart
import 'features/subscription/presentation/navigation/subscription_navigation.dart';

// Simple upgrade trigger:
onPressed: () => openSubscriptionPage(context),
```

### **Check if User is Premium:**
```dart
import 'features/subscription/data/services/subscription_service.dart';

if (SubscriptionService.isPremium) {
  // Show premium feature
} else {
  // Show gate or prompt
}
```

### **Listen to Subscription Changes:**
```dart
import 'features/subscription/data/services/subscription_service.dart';

appSubscriptionNotifier.addListener(() {
  // Subscription changed
  final subscription = appSubscriptionNotifier.value;
  print('Plan: ${subscription.tier}');
});
```

---

## 📚 More Info

- **Full Navigation Guide**: See `USER_BILLING_NAVIGATION_GUIDE.md`
- **Visual Screens**: See `USER_BILLING_SCREENS_VISUAL.md`
- **Phase 2.6 Integration**: Incoming (next phase)
- **Real Payments**: Coming Phase 2.8+

---

## ❓ Common Questions

**Q: Can I actually make a purchase right now?**  
A: No. UI is complete but backend payment integration is Phase 2.6+.

**Q: Will my test payment work?**  
A: Not yet. Real receipts need backend verification (Phase 2.8).

**Q: Where does payment info go?**  
A: Through Google Play (Android) or App Store (iOS) - not stored in app.

**Q: Can I see premium features without paying?**  
A: No. All premium gates check real Supabase subscription status.

**Q: What happens if payment fails?**  
A: User sees error message with "Retry" option. No money charged.

---

**🎉 Summary:** Users can navigate to billing in 3 ways. UI is fully functional and beautiful. Backend payment processing coming next phase!
