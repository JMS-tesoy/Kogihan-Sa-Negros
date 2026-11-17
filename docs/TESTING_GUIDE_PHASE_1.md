# 🧪 Testing Guide: Phase 1 App Behavior

## What to Test After Deployment

After running `supabase db push` and `flutter run`, here's exactly what you should test:

---

## 🔐 Test 1: Signup & Profile Creation (5 min)

### What to Do
1. **Fresh install:** Delete app from device or use new simulator
2. **Tap Signup**
3. **Fill in form:**
   - Email: `testuser@example.com`
   - Password: `TempPassword123!`
   - Full Name: `Test User`
   - Role: Select `user`
4. **Tap Submit**

### What to Expect
- ✅ 1-2 second loading spinner
- ✅ Success message: "Account created!"
- ✅ Redirects to Home Screen
- ✅ Shows user name in profile
- ✅ No "Create Property" button visible (user role)

### What's Happening Behind Scenes
```
Your Device                    Supabase
│                             │
├─→ POST /auth/signup  ─────→ │
│                             ├─→ Create auth.users row
│                             ├─→ Create profiles row
│                             ├─→ Trigger creates subscriptions row
│                             │
├─← Session token ←────────── │
│                             │
└─ Save token locally
└─ Show Home Screen
```

### Verify in Supabase Dashboard
1. Go to **SQL Editor**
2. Run: `SELECT * FROM profiles WHERE email = 'testuser@example.com';`
3. Should show:
   ```
   id: (uuid)
   email: testuser@example.com
   full_name: Test User
   role: user
   created_at: (current timestamp)
   ```

---

## 🔄 Test 2: Persistence & Auto-Login (3 min)

### What to Do
1. **Force quit app** (swipe from recent apps or close)
2. **Reopen app**

### What to Expect
- ✅ Splash screen shows briefly
- ✅ App loads Home Screen immediately
- ✅ User still logged in (no login screen)
- ✅ See same profile data

### Verify It Works
- If you see Home Screen without signing in again → ✅ Persistence works
- If you see Login Screen → ❌ Session not saved

---

## 🎭 Test 3: Different Roles UI (10 min)

### Part A: User Role (What You Just Created)
1. **Look for:**
   - ✅ Home screen with property browsing
   - ✅ [Browse] button
   - ✅ [Search] button
   - ✅ [Saved] tab
   - ✅ [Messages] tab
   - ✅ [Profile] tab
   - ❌ NO "Create Property" button
   - ❌ NO "Agent Dashboard" option

2. **Go to Profile**
   - See: Subscription = "Free"
   - See: "[Upgrade]" button (might be grayed out)

### Part B: Agent Role
1. **Logout** (Settings → Logout)
2. **Signup as Agent:**
   - Email: `testagent@example.com`
   - Password: `TempPassword123!`
   - Full Name: `Test Agent`
   - Role: Select `agent`

3. **Look for new buttons:**
   - ✅ [+ Create Property] button
   - ✅ Agent Dashboard option
   - ✅ "My Listings" section

4. **Go to Profile**
   - See: Can access agent features
   - See: Subscription = "Free"

### Verify in DB
```sql
SELECT email, role FROM profiles 
WHERE email IN ('testuser@example.com', 'testagent@example.com');
```

Should show both roles correctly.

---

## 💾 Test 4: Save Property (Persistence) (5 min)

### What to Do
1. **Login as User** (testuser@example.com)
2. **Find a property** (browse home screen)
3. **Tap on property**
4. **Tap [❤️ Save] button**
5. **Verify:** 
   - Heart fills ❤️
   - Toast shows "Saved"
6. **Close app completely**
7. **Reopen app**
8. **Go to [Saved] tab**

### What to Expect
- ✅ Saved property still there
- ✅ It survived app close
- ✅ Persisted to database

### Verify in DB
```sql
SELECT * FROM favorites 
WHERE user_id = (SELECT id FROM profiles WHERE email = 'testuser@example.com');
```

Should show your saved property.

---

## 🏢 Test 5: Agent Creates Property (5 min)

### What to Do
1. **Login as Agent** (testagent@example.com)
2. **Tap [+ Create Property] button**
3. **Fill in form:**
   - Title: "Test Property"
   - Location: "Negros Island"
   - Price: "1000000"
   - Description: "Test property description"
   - Size: "1000"
4. **Tap Submit**

### What to Expect
- ✅ 2-3 second loading spinner
- ✅ Success message
- ✅ Property appears in "My Listings"
- ✅ Property now searchable by users

### Verify in DB
```sql
SELECT * FROM properties 
WHERE agent_id = (SELECT id FROM profiles WHERE email = 'testagent@example.com');
```

Should show the created property with:
- agent_id = agent's user id
- title = "Test Property"
- status = "active"

---

## 🚫 Test 6: RLS Security (User Can't Edit Agent's Property) (5 min)

### What to Do
1. **Login as User** (testuser@example.com)
2. **Go to Agent's property**
3. **Try to:**
   - Edit property (might not see edit option, good!)
   - If edit option exists, try to change title
   - Try to delete property

### What to Expect
- ✅ User can VIEW agent's property
- ✅ User CANNOT EDIT agent's property
- ✅ Error message shows: "Only agent can edit"

### Why This Matters
This proves RLS security is working. Even if a hacker tries to edit the property directly via API, Supabase will block them.

---

## 🔒 Test 7: Logout Security (3 min)

### What to Do
1. **In Profile → Settings → Logout**
2. **Tap Logout**
3. **Reopen app**

### What to Expect
- ✅ Taken to Login Screen
- ✅ Session completely cleared
- ✅ Can't access app without logging in again

### Verify It Worked
- If you see Login Screen → ✅ Logout worked
- If you still see Home Screen → ❌ Session not cleared

---

## 📱 Test 8: Cross-Device Sync (10 min)

### Setup
- Device A: iPhone or primary phone
- Device B: iPad, Android, or emulator

### What to Do
1. **On Device A:**
   - Login as agent (testagent@example.com)
   - Create a property "Test on Device A"
   
2. **On Device B:**
   - Install app
   - Login as same agent (testagent@example.com)

### What to Expect
- ✅ Device B shows the property created on Device A
- ✅ Same profile data on both devices
- ✅ Saved properties sync

### Why This Works
All data is in Supabase, not on device. Same user = same data everywhere.

---

## ⚠️ Test 9: Error Handling (5 min)

### Test 9A: Invalid Email
1. **Signup form**
2. **Email:** `notanemail`
3. **Submit**
4. **Expect:** ❌ Error message "Invalid email format"

### Test 9B: Weak Password
1. **Signup form**
2. **Password:** `123`
3. **Submit**
4. **Expect:** ❌ Error message "Password must be at least 8 characters"

### Test 9C: Email Already Exists
1. **Signup form**
2. **Email:** `testuser@example.com` (already used)
3. **Submit**
4. **Expect:** ❌ Error message "Email already registered"

### Test 9D: Wrong Password on Login
1. **Login form**
2. **Email:** `testuser@example.com`
3. **Password:** `WrongPassword`
4. **Submit**
5. **Expect:** ❌ Error message "Invalid password" or "User not found"

### Test 9E: No Internet Connection
1. **Turn off WiFi/Mobile data**
2. **Try to login**
3. **Expect:** ❌ Error message "No internet connection"
4. **Turn internet back on**
5. **Retry**
6. **Expect:** ✅ Now works

---

## 📊 Test 10: Data in Supabase Dashboard (5 min)

### What to Check

**1. Tables Exist:**
1. Go to Supabase Dashboard
2. Click your project
3. Go to **Database** → **Tables**
4. Verify these exist:
   - ✅ profiles
   - ✅ properties
   - ✅ inquiries
   - ✅ favorites
   - ✅ subscriptions
   - ✅ messages
   - ✅ agent_teams
   - ✅ team_members
   - ✅ moderation_reports
   - ✅ reviews
   - ✅ notifications
   - ✅ audit_logs

**2. RLS Policies Exist:**
1. Go to **Database** → **Policies**
2. For each table, should see policies like:
   - `users_view_own_profile`
   - `users_update_own_profile`
   - `admins_view_all_profiles`
   - etc.

**3. Data in Tables:**
1. Go to **SQL Editor**
2. Run queries to verify:
   ```sql
   -- Should show 2+ profiles
   SELECT email, role FROM profiles;
   
   -- Should show 1+ properties
   SELECT title, agent_id FROM properties;
   
   -- Should show 1+ favorites
   SELECT * FROM favorites;
   
   -- Should show 2+ subscriptions
   SELECT * FROM subscriptions;
   ```

---

## ✅ Full Testing Checklist

After all tests, verify:

| Test | Status | Notes |
|------|--------|-------|
| Signup creates account | ✅ |  |
| Auto-login on reopen | ✅ |  |
| User sees user UI | ✅ |  |
| Agent sees agent UI | ✅ |  |
| Save property persists | ✅ |  |
| Agent create property works | ✅ |  |
| User can't edit agent property | ✅ |  |
| Logout clears session | ✅ |  |
| Cross-device sync | ✅ |  |
| Error messages show | ✅ |  |
| All 12 tables exist in DB | ✅ |  |
| RLS policies working | ✅ |  |
| No crashes or errors | ✅ |  |

---

## 🎯 If Something Breaks

### "Signup instant crash"
**Check:**
1. `flutter pub get` ran successfully?
2. Supabase migration applied? (`supabase db push`)
3. Check console for errors

**Fix:**
```bash
flutter clean
flutter pub get
flutter run
```

### "Can't see created properties"
**Check:**
1. Are properties stored in database?
   ```sql
   SELECT * FROM properties;
   ```
2. Is the property status = 'active'?
3. Are properties loading on Home Screen?

**Fix:**
Check if properties datasource is querying the right table.

### "Session not persisting"
**Check:**
1. Is session token being saved locally?
2. Check SharedPreferences in app
3. Check Supabase Auth settings

**Fix:**
May need to initialize Supabase in main.dart if not done.

### "RLS policy blocking everything"
**Check:**
1. Run test query in SQL Editor:
   ```sql
   SELECT * FROM profiles WHERE id = auth.uid();
   ```
2. If returns nothing → auth.uid() not set properly
3. If returns rows → RLS working ✅

---

## 🚀 When All Tests Pass

Congratulations! Phase 1 is working. Ready for:
- Phase 2: Real billing integration
- Phase 3: Server-backed search
- Phase 4: Inquiries feature
- etc.

---

**Time to Complete All Tests:** ~1 hour  
**Expected Result:** All ✅ marks, no errors  
**Next Step:** Deploy Phase 2 when ready
