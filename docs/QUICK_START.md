# 🚀 Quick Start: Backend/Supabase Authorization

**Completed:** Phase 1 of priority roadmap  
**Time to Deploy:** ~15 minutes  
**Difficulty:** Medium (follow the steps)

---

## ⚡ 5-Minute Overview

Your app now has:
1. **Secure Database** – 12 tables with RLS policies
2. **Real Auth** – Email/password signup & login
3. **Role System** – User, Agent, Admin with different permissions
4. **Flutter Integration** – Ready to test in app

---

## 🎯 Deploy in 15 Minutes

### Step 1: Push Migration (2 min)

**Option A: Using Supabase CLI (Recommended)**
```bash
cd "D:\Documents\Website Project\Flutter Projet\Andoid project\Land Finder app"
supabase db push
```

**Option B: Manual (No CLI)**
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **SQL Editor** → **New Query**
4. Copy contents of: `supabase/migrations/20261117_complete_rls_and_auth_policies.sql`
5. Paste into editor
6. Click **Execute**
7. Wait for success message

### Step 2: Verify Migration (2 min)

**Check tables exist:**
1. Go to **Database** → **Tables**
2. Look for these 12 tables:
   - profiles
   - properties
   - inquiries
   - favorites
   - subscriptions
   - messages
   - agent_teams
   - team_members
   - moderation_reports
   - reviews
   - notifications
   - audit_logs

**Check RLS policies:**
1. Go to **Database** → **Policies**
2. Should see 40+ policies

### Step 3: Update Flutter (1 min)

```bash
flutter pub get
```

**Already have everything you need:**
- ✅ `supabase_flutter` in pubspec.yaml
- ✅ AuthRemoteDatasource updated
- ✅ AuthRepositoryImpl updated

### Step 4: Test in App (5 min)

**Create test account:**
1. Run app: `flutter run`
2. Go to signup screen
3. Enter email: `test@example.com`
4. Password: `TempPass123!`
5. Full name: `Test User`
6. Select role: `user` (buyer)
7. Click signup

**Verify success:**
1. Check you're logged in
2. Go to home screen
3. Try viewing properties

**Test as Agent:**
1. Create new account with role `agent`
2. Try creating a property listing
3. Should succeed (agent permission)

### Step 5: Verify Security (3 min)

**Test RLS policies work:**

```dart
// In your app's test file or debug screen:

// 1. User can't see another profile
try {
  final otherProfile = await supabase
    .from('profiles')
    .select()
    .eq('id', someOtherUserId)
    .single();
  print('❌ FAILED: Should not see other profile');
} catch (e) {
  print('✅ PASSED: RLS blocked access');
}

// 2. User can see only own favorites
final favorites = await supabase
  .from('favorites')
  .select();
print('✅ See only my favorites: ${favorites.length}');
```

---

## 📚 Documentation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **AUTHORIZATION_AND_RLS.md** | Complete guide to auth system | 20 min |
| **DEPLOYMENT_AUTHORIZATION.md** | Deployment checklist & troubleshooting | 15 min |
| **PHASE_1_COMPLETE.md** | What was delivered | 10 min |
| This file | Quick start | 5 min |

---

## 🧪 Test Scenarios

### Test 1: User Registration & Auto-Subscription

```bash
# Create new user via app signup
# Email: alice@example.com
# Role: user

# Verify in Supabase SQL Editor:
SELECT * FROM profiles WHERE email = 'alice@example.com';
-- Should show role='user'

SELECT * FROM subscriptions WHERE user_id = '<alice-id>';
-- Should show tier='free' (auto-created by trigger)
```

### Test 2: Agent Can Create Listing

```bash
# Create agent via app signup
# Email: bob@example.com
# Role: agent

# Try creating property in app
# Should succeed ✅

# Verify in SQL:
SELECT * FROM properties WHERE agent_id = '<bob-id>';
-- Should show listing created
```

### Test 3: User Can't Edit Agent's Listing

```bash
# As user alice@example.com
# Try to edit bob's listing in app
# Should get "Not authorized" error ✅

# This is RLS policy working!
```

### Test 4: Admin Can See Everything

```bash
# In Supabase, make yourself admin:
UPDATE profiles SET role = 'admin' WHERE email = 'yourmail@example.com';

# Logout and login to app
# Admin dashboard should show all users, all properties, all inquiries
```

---

## 🔧 Configuration

### Your Supabase Project (Already Configured)

**URL:** `https://vludvvjkrrqzjahxjdjl.supabase.co`  
**Anon Key:** `sb_publishable_xrlYmyU6k2ItwhoSycq_iQ_4RxiPGdJ`

(From `lib/app/config/supabase_config.dart`)

### Environment Variables

Already set in `.env`:
```
NEXT_PUBLIC_SUPABASE_URL=https://vludvvjkrrqzjahxjdjl.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY=sb_publishable_xrlYmyU6k2ItwhoSycq_iQ_4RxiPGdJ
```

No changes needed! ✅

---

## ⚠️ Common Issues

### "Policy for SELECT does not exist"
**Means:** RLS policy missing for that operation.  
**Fix:** Re-run migration or check that it completed successfully.

### Users not in profiles table after signup
**Means:** Signup didn't create profile row.  
**Fix:** Restart app, re-run migration, check datasource code creates profile.

### "null" after sign-in
**Means:** Profile query returned no rows.  
**Fix:** 
1. Check profile exists: `SELECT * FROM profiles WHERE email = '<email>'`
2. If missing, manually create: `INSERT INTO profiles VALUES (...)`

### Admin can't see all data
**Means:** Admin user doesn't have role='admin' in profiles.  
**Fix:** Set role directly: `UPDATE profiles SET role = 'admin' WHERE id = '<uid>'`

---

## 🔐 Security Reminders

1. **Never check authorization in app code**
   - ❌ Bad: `if (user.role == 'agent') { showUI() }`
   - ✅ Good: `Try the operation; server rejects if not authorized`

2. **Supabase handles sessions**
   - You don't need to manage tokens
   - They auto-refresh
   - Sign out clears everything

3. **Role = Database Column**
   - User's role is stored in `profiles.role`
   - Database checks it in every RLS policy
   - Can't be faked from client

4. **Password Reset Works**
   - `AuthRemoteDatasource.resetPassword(email)`
   - Sends email via Supabase Auth
   - User clicks link, creates new password

---

## 🎓 Next: Phase 2 (Billing)

After this is deployed and stable:

1. **Phase 2: Real Billing Integration**
   - Connect to app store (Google Play, App Store)
   - Verify receipts
   - Update subscription tiers
   - Track entitlements

2. **Phase 3: Server Search**
   - Implement server-backed property search
   - Pagination & filtering
   - Full-text search

3. **Phase 4: Inquiries UI**
   - Build inquiry form
   - Display received inquiries
   - Respond & track status

**Roadmap:** See `docs/PHASE_1_COMPLETE.md` for full priority list

---

## 📞 Need Help?

1. **Check SQL:** Go to Supabase SQL Editor and run troubleshooting queries
2. **Read Docs:** See `AUTHORIZATION_AND_RLS.md` for detailed explanations
3. **Review Migration:** Open `supabase/migrations/20261117_complete_rls_and_auth_policies.sql` to understand policies
4. **Test Scenarios:** Follow examples in `DEPLOYMENT_AUTHORIZATION.md`

---

## ✅ Checklist Before Moving to Phase 2

- [ ] Migration deployed successfully
- [ ] All 12 tables visible in Supabase dashboard
- [ ] 40+ RLS policies exist
- [ ] Signup creates profile + subscription
- [ ] User can signin
- [ ] Agent can create listing
- [ ] User can't edit agent's listing
- [ ] Admin can view all data
- [ ] RLS policies properly blocking unauthorized access

**Once all checked, Phase 2 is ready! 🚀**

---

**Version:** 1.0.0  
**Last Updated:** 2026-11-17
