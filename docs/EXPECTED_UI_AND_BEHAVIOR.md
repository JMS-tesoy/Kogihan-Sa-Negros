# 📱 Phase 1: Expected App UI & Behavior

## Overview

**What Changed:** Backend authentication & authorization is now LIVE  
**What's Visible:** User signup/signin flows now work with real Supabase  
**What's NOT Changed:** Visual UI design remains the same (for now)  
**What's NEW Internally:** Data is now saved to real database with security

---

## 🔄 Authentication Flow: Before vs. After

### BEFORE Phase 1
```
Signup Screen
    ↓ (Enter email, password, name)
    ↓ (Click signup)
    ↓ MOCK: Creates fake user
    ↓ No data saved to database
    ↓ User data lost on app restart
    ↓ No role assignment
    ↓ All users treated the same
    ↓
Home Screen (No real session)
```

### AFTER Phase 1 (What You'll See)
```
Splash Screen (NEW: Checks for existing session)
    ↓ If logged in before → Auto-login
    ↓ If not logged in → Go to Auth Screen
    ↓
Auth Screen (Email/Password options)
    ↓ 
Signup Screen (REAL: Supabase Auth)
    ├─ Email field (new user)
    ├─ Password field (8+ chars)
    ├─ Full Name field
    └─ Role Selection (User or Agent)
    ↓ (Click signup)
    ↓ REAL: 
    │  • Creates auth user in Supabase Auth
    │  • Creates profile record in database
    │  • Auto-creates free subscription
    │  • Session token generated
    ↓ 
Home Screen (LOGGED IN as that role)
```

---

## 🎯 User Journey: Day 1

### New User Signs Up

**What They See:**
1. **Splash Screen** (1-2 sec) - Shows while checking if logged in
2. **Login/Signup Screen** - Two tabs or buttons
3. **Signup Form** - Requests:
   - Email address
   - Password (must be strong)
   - Full name
   - Role selection (User / Agent)
4. **Success Message** - "Account created! Welcome to Land Finder"
5. **Home Screen** - Shows properties based on role

**What Happens Behind Scenes:**
```
✅ Supabase Auth: Creates user account
✅ Database: Inserts profile record
✅ Database: Auto-creates free subscription
✅ Session: Generates JWT token
✅ Local Storage: Saves session token
✅ App State: Updates currentUser
```

**Data Saved to Database:**
```sql
profiles table:
  id: uuid (from auth.users)
  email: entered email
  full_name: entered name
  role: 'user' or 'agent' (selected)
  created_at: now()

subscriptions table:
  user_id: same as profile id
  tier: 'free' (auto-created)
  status: 'active'
```

---

## 🔐 Role-Based Experience

### If User Selects "User" (Buyer)
**Home Screen Shows:**
- ✅ Browse all published properties
- ✅ Search & filter properties
- ✅ Save properties to favorites
- ✅ Send inquiries to agents
- ✅ View saved listings
- ✅ View messages from agents
- ❌ Cannot create property listings
- ❌ Cannot access agent dashboard

**Profile Shows:**
- Personal info (can edit)
- Saved properties count
- Subscription: Free (can't see premium features)
- Subscriptions tab (might be grayed out)

### If User Selects "Agent" (Seller)
**Home Screen Shows:**
- ✅ All home screen features PLUS:
- ✅ "Create Property" button (prominent)
- ✅ Agent Dashboard shortcut
- ✅ Received Inquiries count

**Agent Dashboard Shows:**
- Manage Listings (CRUD operations)
- Received Inquiries & Messages
- Property Analytics (views, inquiries)
- Team Management (create/join teams)
- Subscription options (upgrade to premium)

---

## 💾 Data Persistence

### BEFORE Phase 1
```
❌ User data lost on app close
❌ No sync between devices
❌ All data in-memory only
❌ Favorites lost on reinstall
```

### AFTER Phase 1
```
✅ User data persists on Supabase
✅ User can login from any device
✅ Session continues across restarts
✅ All data synced to backend
✅ Favorites saved to database
✅ Messages persist
✅ Listings persist
```

**Example Flow:**
1. User A signs up on iPhone
2. Creates a property listing
3. Closes app
4. Opens app 1 hour later → Still logged in ✅
5. Listing still there ✅
6. Opens same account on Android → Sees same profile + listing ✅

---

## 🔑 Session Management

### What Happens on Startup

```
App Starts
    ↓
Splash Screen Checks:
    ├─ Is there a saved session token?
    ├─ Is the token still valid?
    └─ Can we refresh if expired?
    ↓
IF Session Valid:
    ↓ Auto-login (no manual signin needed)
    ↓ Load user profile & role
    ↓ Show home screen
    ↓
IF Session Expired:
    ↓ Clear session
    ↓ Show login screen
    ↓
IF No Session:
    ↓ Show login/signup screen
```

### Logout Behavior

**Current (BEFORE Phase 1):**
```
User clicks Logout
    ↓ Just clears app state
    ↓ That's it
```

**New (AFTER Phase 1):**
```
User clicks Logout
    ↓ Clears session token locally
    ↓ Tells Supabase to logout
    ↓ Session revoked on server
    ↓ Shows login screen
    ↓ Can't access app without login
```

---

## ⚠️ Error Scenarios (New Behavior)

### Invalid Email on Signup
**Before:** No validation
**After:** 
```
User enters: "notanemail"
Clicks Signup
Error shows: "Please enter a valid email address"
(Can't proceed)
```

### Weak Password
**Before:** No validation
**After:**
```
User enters: "123"
Clicks Signup
Error shows: "Password must be at least 8 characters"
(Can't proceed)
```

### Email Already Registered
**Before:** No check
**After:**
```
User enters: existing@example.com
Clicks Signup
Error shows: "This email is already registered. Please sign in instead."
Offers link to sign in
```

### Network Error During Signup
**Before:** Probably crashes
**After:**
```
User clicks Signup
Network fails (no internet)
Error shows: "No internet connection. Please try again."
User can retry once connection returns
```

---

## 🔀 Role Enforcement in UI

### Agent Tries to Create Property

**What They See:**
1. Click "Create Property" button
2. Fill in form (title, location, price, description, images)
3. Click "Create"
4. ✅ Success message: "Property created!"
5. Property appears in their listings

**Behind Scenes:**
```
Flutter sends request:
    POST /properties
    {title: "...", location: "...", ...}
    
Supabase checks RLS policy:
    ├─ Is user authenticated? ✅
    ├─ Is user role = 'agent'? ✅
    ├─ Does agent_id match current user? ✅
    └─ ALLOW → Insert record
    
Database stores:
    id: new uuid
    agent_id: current user id
    title: "..."
    created_at: now()
```

### Regular User Tries to Create Property

**What They See:**
```
User opens app as regular "user" role
Browses home screen
❌ NO "Create Property" button
❌ Agent dashboard not visible
Sees: Browse, Search, Save, Inquire options only
```

**If They Try to Hack:**
```
(If user somehow calls create property API)
    ↓
Supabase checks RLS policy:
    ├─ Is user authenticated? ✅
    ├─ Is user role = 'agent'? ❌ (is 'user')
    └─ DENY → Permission denied
    
Error returned to app:
    "Only agents can create properties"
    
User can't proceed
```

---

## 📲 Specific Screen Changes

### Splash Screen (NEW)
**Visual:** Same logo animation as before  
**Behavior CHANGE:** 
- Now checks for existing session
- Shows loading indicator while checking
- Takes 1-2 seconds instead of instant

### Login Screen (UPDATED)
**Visual:** Same layout, same buttons  
**Behavior CHANGES:**
- Now actually authenticates with Supabase
- Shows real error messages (invalid email, wrong password)
- Email/password fields now required
- Password shows strength indicator (optional enhancement)

### Signup Screen (UPDATED)
**Visual:** 
- Email field (new)
- Password field (new)
- Full Name field (exists)
- Role selector (exists or new)

**Behavior CHANGES:**
- Real validation (email format, password strength)
- Real error messages
- Creates profile in database
- Auto-creates subscription

### Home Screen (MOSTLY SAME)
**Visual:** No changes expected  
**Behavior CHANGES:**
- Properties loaded from real database instead of mock data
- User can now save favorites (persists to database)
- User can now send inquiries (stored in database)
- Messages from agents (if they reply) will show up

### Property Details Screen (MOSTLY SAME)
**Visual:** No changes expected  
**Behavior CHANGES:**
- Save to Favorites now works
- Sends real inquiry to agent
- Shows who listed it (agent name)
- Shows agent contact (from database)

### Profile Screen (UPDATED)
**Visual:** 
- Shows email (from database)
- Shows subscription tier
- Shows number of saved properties

**Behavior CHANGES:**
- Edit profile now updates Supabase
- Changes persist across devices
- Avatar upload works (saves to Supabase Storage - Phase 2)
- Subscription section shows tier (Free by default)

### Settings Screen (UPDATED)
**Behavior CHANGES:**
- Logout now actually logs out from Supabase
- After logout: Can't access app without login
- Password change (if implemented) updates Supabase

### Agent-Specific Screens (UPDATED)
**Create Listing Screen:**
- Now saves to real database
- Listings persist
- Appear in "My Listings"
- Can be viewed by buyers

**Agent Dashboard:**
- Shows real listings (from database)
- Shows real inquiries received
- Shows real messages from buyers
- Can update listing status

---

## 🔄 Data Flow: What Actually Happens

### Scenario: User Saves a Property

**Step-by-Step:**

1. **User Opens Property Details**
   ```
   App loads: property data from database
   Shows: Title, location, price, images
   ```

2. **User Clicks "Save" Button**
   ```
   App checks: Is user logged in?
   App checks: Is user role = 'user' or 'agent'?
   (Both checks pass)
   ```

3. **App Sends to Supabase:**
   ```
   POST /favorites
   {
     user_id: current user id,
     property_id: this property id
   }
   ```

4. **Supabase Applies RLS Policy:**
   ```
   Policy checks:
     ├─ Is user_id = auth.uid()? ✅
     └─ ALLOW → Insert
   ```

5. **Database Stores:**
   ```
   favorites table:
   {
     id: new uuid,
     user_id: current user id,
     property_id: property id,
     created_at: now()
   }
   ```

6. **App Gets Success Response:**
   ```
   Shows: "✅ Property saved!"
   Button changes: "Unsave" or heart fills
   ```

7. **Data Persists:**
   ```
   Close app
   Open app tomorrow from different device
   Same favorites still there ✅
   ```

---

## 🚫 What Won't Work Yet (Phase 2+)

### Not Yet Implemented
- ❌ **Real Billing:** Can't purchase premium tiers (Phase 2)
- ❌ **Real Images:** Avatar upload not working (Phase 2)
- ❌ **Search Backend:** Still filters locally (Phase 3)
- ❌ **Inquiries UI:** Database ready but UI might need work (Phase 4)
- ❌ **Real Notifications:** No push notifications yet
- ❌ **Teams UI:** Schema ready but UI needs Phase 5

### What DOES Work Now
- ✅ **Signup/Login:** Real authentication
- ✅ **Profiles:** Real user accounts
- ✅ **Data Persistence:** Everything saves to database
- ✅ **Session Management:** Auto-login, proper logout
- ✅ **Role-Based UI:** Different screens for user/agent/admin
- ✅ **RLS Security:** Database enforces permissions
- ✅ **Multi-Device:** Login from any device

---

## 🎮 Test Scenarios: What to Try

### Test 1: Signup and Persist
```
1. Install app fresh
2. Signup with email, password, name, select "User"
3. Close app completely
4. Reopen app
   EXPECT: Auto-logged in, same user showing ✅
```

### Test 2: Create Property as Agent
```
1. Signup as "Agent"
2. Navigate to Create Property
3. Fill in form and submit
4. See property in My Listings
5. Close app and reopen
   EXPECT: Property still there ✅
```

### Test 3: Save Property as User
```
1. Signup as "User"
2. Browse properties
3. Find a property by an agent
4. Click "Save" button
5. Close app
6. Reopen from different device (same account)
   EXPECT: Saved property visible on new device ✅
```

### Test 4: RLS Enforcement
```
1. Signup as "User"
2. Try to edit/delete a property (not yours)
   EXPECT: "Not authorized" error ✅
3. Logout
4. Signup as the agent who created property
5. Try to edit your own property
   EXPECT: Edit works ✅
```

### Test 5: Session Persistence
```
1. Signup
2. Force-close app (swipe from recent)
3. Reopen app
   EXPECT: Still logged in ✅
4. Logout
5. Reopen app
   EXPECT: Shows login screen ✅
```

---

## 📊 Visible Indicators of Real Backend

### In Signup
- Real validation errors (email format, password strength)
- "Email already registered" if you try same email twice
- Takes 1-2 seconds instead of instant (network delay)

### In Login
- "User not found" vs "Wrong password" (specific errors)
- Takes 1-2 seconds (network call)

### In App
- Favorites sync across devices
- Listings persist after app close
- Messages from agents appear
- Inquiries track status

### In Settings/Profile
- Changes persist to database
- Logout actually logs out

---

## ⚡ Performance Notes

**What Might Feel Slower:**
- Signup/login (1-2 seconds for network)
- Creating properties (1-2 seconds for network)
- Loading favorites (slight delay)

**Why:**
- Real network calls to Supabase
- Database writes are slower than in-memory
- BUT: This is reliable and persistent

**How to Optimize (Phase 2+):**
- Offline caching
- Optimistic updates (show success immediately, sync later)
- Local database sync

---

## 🎯 Summary: What Changes for Users

| Aspect | Before Phase 1 | After Phase 1 |
|--------|----------------|---------------|
| **Signup** | Mock, instant | Real, 1-2 sec |
| **Login** | Optional | Required to access app |
| **Data** | Lost on close | Persists forever |
| **Multi-Device** | ❌ Not possible | ✅ Login from any device |
| **Role-Based UI** | No | Yes, different for user/agent |
| **Property Creation** | Mock | Real, stored in database |
| **Favorites** | Local only | Synced to database |
| **Inquiries** | Mock | Real, stored & tracked |
| **Sessions** | ❌ No concept | ✅ Auto-login if still valid |
| **Logout** | Clears local | Full server logout |

---

## 🔮 Next Phase Preview (Phase 2: Billing)

**What Users Will See in Phase 2:**
- "Upgrade to Premium" button on paywall
- In-app purchase flow (iOS/Android)
- After purchase: Premium features unlock
- Subscription status in settings
- Automatic renewal management

**UI Changes Expected:**
- Paywall sheet showing plans
- Price displays (in local currency)
- "Subscribe" buttons
- "Manage Subscription" in settings

---

## ❓ Common Questions

### "Will I lose my data if I uninstall?"
**Before Phase 1:** Yes, all lost  
**After Phase 1:** No, stays in database. Just login again on reinstall.

### "Can I use the same account on multiple devices?"
**Before Phase 1:** No, each device is separate  
**After Phase 1:** Yes! Login on iPhone and Android, see same profile.

### "What if I forget my password?"
**Before Phase 1:** You can't recover  
**After Phase 1:** Click "Forgot Password", get email recovery link (Phase 2: might need UI implementation)

### "Are my inquiries saved?"
**Before Phase 1:** Probably not  
**After Phase 1:** Yes, stored in database, can review anytime

### "What happens to my properties if I delete the app?"
**Before Phase 1:** They're gone  
**After Phase 1:** They stay on server. Login again and they're there.

---

**TL;DR:** App behaves the same visually, but now all data persists to a real database, users can login from any device, and role-based access control is enforced at the database level.

---

*Expected UI Changes: Minimal visual design changes*  
*Expected Behavior Changes: Everything now works with real data*  
*Expected Performance: Slight delay for network calls, but reliable persistence*

**Status:** Ready to test and deploy!
