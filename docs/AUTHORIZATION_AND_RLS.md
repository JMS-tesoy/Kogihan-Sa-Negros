# Land Finder App - Authorization & Row-Level Security (RLS) Guide

## Overview

This document describes the complete authorization model and Row-Level Security (RLS) policies implemented for the Land Finder app using Supabase PostgreSQL and Supabase Auth.

**Three-Tier Role System:**
- **User (Buyer)** – Browse and save properties, send inquiries
- **Agent** – Create/manage listings, respond to inquiries, access team features
- **Admin** – System-wide moderation, analytics, user management

---

## Table of Contents

1. [Authentication Flow](#authentication-flow)
2. [Database Schema](#database-schema)
3. [Row-Level Security (RLS) Policies](#row-level-security-rls-policies)
4. [Role Hierarchy & Permissions](#role-hierarchy--permissions)
5. [Best Practices](#best-practices)
6. [Testing Authorization](#testing-authorization)

---

## Authentication Flow

### Sign Up

```dart
Future<AuthUserModel> signUp({
  required String email,
  required String password,
  required String fullName,
  required String role,
}) async {
  // 1. Create auth user in Supabase Auth
  final response = await supabase.auth.signUpWithPassword(
    email: email,
    password: password,
  );

  // 2. Create profile record with role in `profiles` table
  await supabase.from('profiles').insert({
    'id': user.id,  // Links to auth.users(id)
    'email': email,
    'full_name': fullName,
    'role': role,   // 'user' or 'agent'
  });

  // 3. Auto-create free subscription tier
  // (Triggered by DB function on profile insert)
}
```

**Role Assignment:**
- New users register as `'user'` (buyer)
- Users can request to become `'agent'` (via role selection screen)
- Only admins can assign `'admin'` role

### Sign In

```dart
Future<AuthUserModel> signIn({
  required String email,
  required String password,
}) async {
  // 1. Authenticate with Supabase Auth
  final response = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );

  // 2. Load user profile (includes role)
  final profile = await supabase
    .from('profiles')
    .select()
    .eq('id', user.id)
    .single();

  return AuthUserModel(
    id: user.id,
    email: user.email,
    name: profile['full_name'],
  );
}
```

### Session Management

- Supabase automatically manages sessions with refresh tokens
- Sessions persist across app restarts
- Sign out clears local session and server token

```dart
Future<void> signOut() async {
  await supabase.auth.signOut();
}
```

---

## Database Schema

### Core Tables

#### `auth.users` (Supabase Built-in)
```sql
id: uuid PRIMARY KEY
email: text
encrypted_password: text
...
```

#### `profiles` (Custom)
```sql
id: uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
email: text
phone: text
full_name: text
role: text NOT NULL DEFAULT 'user'  -- 'user', 'agent', 'admin'
avatar_url: text
created_at: timestamptz
updated_at: timestamptz
fcm_token: text (Firebase Cloud Messaging)
```

#### `properties`
```sql
id: uuid PRIMARY KEY
agent_id: uuid REFERENCES profiles(id)  -- Who listed this
title: text
location: text
price: text
description: text
status: text  -- 'active', 'sold', 'archived', 'pending'
boundary_coordinates: text (GeoJSON)
created_at: timestamptz
updated_at: timestamptz
```

#### `inquiries`
```sql
id: uuid PRIMARY KEY
property_id: uuid REFERENCES properties(id) ON DELETE CASCADE
sender_id: uuid REFERENCES profiles(id)  -- Buyer asking
receiver_id: uuid REFERENCES profiles(id)  -- Agent/seller
message: text
status: text  -- 'pending', 'viewed', 'responded', 'closed'
created_at: timestamptz
```

#### `favorites`
```sql
id: uuid PRIMARY KEY
user_id: uuid REFERENCES profiles(id) ON DELETE CASCADE
property_id: uuid REFERENCES properties(id) ON DELETE CASCADE
created_at: timestamptz
UNIQUE(user_id, property_id)
```

#### `subscriptions`
```sql
id: uuid PRIMARY KEY
user_id: uuid UNIQUE REFERENCES profiles(id) ON DELETE CASCADE
tier: text  -- 'free', 'premium', 'professional'
status: text  -- 'active', 'cancelled', 'expired', 'paused'
started_at: timestamptz
expires_at: timestamptz
auto_renew: boolean
created_at: timestamptz
```

#### `agent_teams`
```sql
id: uuid PRIMARY KEY
name: text
leader_id: uuid REFERENCES profiles(id)
created_at: timestamptz
```

#### `team_members`
```sql
id: uuid PRIMARY KEY
team_id: uuid REFERENCES agent_teams(id) ON DELETE CASCADE
member_id: uuid REFERENCES profiles(id) ON DELETE CASCADE
role: text  -- 'member', 'lead', 'admin'
joined_at: timestamptz
UNIQUE(team_id, member_id)
```

#### `messages`
```sql
id: uuid PRIMARY KEY
sender_id: uuid REFERENCES profiles(id)
receiver_id: uuid REFERENCES profiles(id)
content: text
attachment_url: text
read_at: timestamptz
created_at: timestamptz
```

#### `moderation_reports`
```sql
id: uuid PRIMARY KEY
reporter_id: uuid REFERENCES profiles(id)
reported_user_id: uuid REFERENCES profiles(id)
reported_property_id: uuid REFERENCES properties(id)
reason: text
status: text  -- 'pending', 'reviewing', 'resolved', 'dismissed'
resolved_by: uuid REFERENCES profiles(id)
created_at: timestamptz
```

---

## Row-Level Security (RLS) Policies

### Philosophy

**RLS is the security layer.** Every row-level action is enforced at the database level, not in app logic.

Each table has policies that define:
- **WHO** can perform the action (which role/user)
- **WHAT** action they can perform (SELECT, INSERT, UPDATE, DELETE)
- **WHICH** rows they can access

### Profiles Table Policies

```sql
-- Users can only view their own profile
CREATE POLICY "users_view_own_profile" ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "users_update_own_profile" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Admins can view all profiles
CREATE POLICY "admins_view_all_profiles" ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

### Properties Table Policies

```sql
-- Anyone can view published properties
CREATE POLICY "anyone_view_published_properties" ON public.properties
  FOR SELECT
  USING (status IN ('active', 'sold'));  -- Published statuses

-- Only agents/admins can create properties
CREATE POLICY "agents_create_properties" ON public.properties
  FOR INSERT
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('agent', 'admin')
  );

-- Agents can update only their own properties
CREATE POLICY "agents_update_own_properties" ON public.properties
  FOR UPDATE
  USING (agent_id = auth.uid())
  WITH CHECK (agent_id = auth.uid());

-- Admins can update any property
CREATE POLICY "admins_update_all_properties" ON public.properties
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

### Inquiries Table Policies

```sql
-- Users can only view their own inquiries (sent or received)
CREATE POLICY "users_view_own_inquiries" ON public.inquiries
  FOR SELECT
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- Users can send inquiries
CREATE POLICY "users_insert_inquiries" ON public.inquiries
  FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- Only receivers can update inquiry status
CREATE POLICY "users_update_inquiries" ON public.inquiries
  FOR UPDATE
  USING (receiver_id = auth.uid())
  WITH CHECK (receiver_id = auth.uid());

-- Admins can view all inquiries
CREATE POLICY "admins_view_all_inquiries" ON public.inquiries
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

### Favorites Table Policies

```sql
-- Users can only view their own favorites
CREATE POLICY "users_view_own_favorites" ON public.favorites
  FOR SELECT
  USING (user_id = auth.uid());

-- Users can add/remove their own favorites
CREATE POLICY "users_manage_own_favorites" ON public.favorites
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_delete_own_favorites" ON public.favorites
  FOR DELETE
  USING (user_id = auth.uid());
```

### Subscriptions Table Policies

```sql
-- Users can view their own subscription
CREATE POLICY "users_view_own_subscription" ON public.subscriptions
  FOR SELECT
  USING (user_id = auth.uid());

-- Users can only update auto_renew, not tier
CREATE POLICY "users_update_own_subscription" ON public.subscriptions
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND tier = 'free');  -- Can't change tier

-- Admins/System can update subscriptions (via functions)
CREATE POLICY "admins_manage_subscriptions" ON public.subscriptions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

---

## Role Hierarchy & Permissions

### User (Buyer)
**Default role for new signups**

| Feature | Permission | Notes |
|---------|-----------|-------|
| Browse Properties | ✅ View all published | Public, no RLS filter |
| Search & Filter | ✅ All properties | Server-side filtering |
| Save to Favorites | ✅ Create, read, delete | Only own favorites |
| Send Inquiry | ✅ Send to agent/seller | Stored in inquiries table |
| View Messages | ✅ Own conversations | Sender or receiver only |
| Update Profile | ✅ Own profile only | name, phone, avatar |
| View Subscription | ✅ Own subscription | Free tier by default |
| Access Team Features | ❌ Not available | Requires agent role |
| Moderation Features | ❌ Limited | Can report content |

### Agent
**Requires approval or in-app role selection**

**All User permissions, plus:**

| Feature | Permission | Notes |
|---------|-----------|-------|
| Create Listings | ✅ Unlimited | Only own listings |
| Edit Listings | ✅ Own listings | Can't edit others' |
| Delete Listings | ✅ Own listings | Soft delete via status |
| Receive Inquiries | ✅ Incoming inquiries | From interested buyers |
| Respond to Inquiries | ✅ Update status | Mark viewed, responded |
| Agent Teams | ✅ Create/join teams | Lead or member roles |
| Premium Tiers | ✅ Available | Via subscriptions |
| Analytics | ✅ Own listing stats | Views, inquiries, conversions |
| Assign Properties | ✅ To team members | Lead role in team |

### Admin
**System-only, assigned by Supabase dashboard**

**All User & Agent permissions, plus:**

| Feature | Permission | Notes |
|---------|-----------|-------|
| View All Profiles | ✅ All users | Audit trail |
| Manage All Properties | ✅ Create, edit, delete | Any property |
| Manage All Inquiries | ✅ View, update status | Moderation |
| Manage Teams | ✅ Create, modify, delete | Governance |
| Moderation Tools | ✅ Full access | Ban users, remove listings |
| Audit Logs | ✅ Full access | Track all changes |
| System Config | ✅ Limited | Via Supabase dashboard |

---

## Best Practices

### 1. Never Trust Client-Side Role Checks

**❌ Bad:**
```dart
if (currentUserRole == 'agent') {
  // Show create listing button
}
```

**✅ Good:**
```dart
// Attempt the operation; server will reject if not authorized
try {
  await repository.createListing(listing);
} on AuthorizationException {
  showError('Only agents can create listings');
}
```

### 2. Always Use `auth.uid()` in Policies

The `auth.uid()` function returns the **authenticated user's ID** from the JWT token. It cannot be spoofed.

```sql
-- ✅ Secure: Uses auth.uid()
CREATE POLICY "users_view_own_profile" ON profiles
  FOR SELECT
  USING (auth.uid() = id);

-- ❌ Insecure: User could pass any ID
WHERE id = :userId  -- Client supplies this
```

### 3. Combine Role + User Checks

Always verify both the user AND their role:

```sql
-- ✅ Good: Checks both
CREATE POLICY "agents_update_own_properties" ON properties
  FOR UPDATE
  USING (
    agent_id = auth.uid()
    AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'agent'
  );

-- ⚠️ Risky: Only checks user
USING (agent_id = auth.uid());
```

### 4. Use Transactions for Multi-Table Operations

If creating a property requires updating an agent's stats, use a transaction:

```sql
BEGIN;
  INSERT INTO properties (...) VALUES (...);
  UPDATE profiles SET listing_count = listing_count + 1 WHERE id = auth.uid();
COMMIT;
```

### 5. Log Security Events

Use the `audit_logs` table to track sensitive actions:

```sql
-- Auto-log on moderation action
CREATE TRIGGER log_moderation_action
  AFTER UPDATE ON moderation_reports
  FOR EACH ROW
  EXECUTE FUNCTION log_audit_event('moderation_updated', NEW.id);
```

### 6. Implement Soft Deletes for Properties

Don't hard-delete properties; use status:

```sql
-- Mark as archived instead of deleting
UPDATE properties SET status = 'archived' WHERE id = $1;

-- Users won't see archived properties in queries
WHERE status IN ('active', 'sold')
```

---

## Testing Authorization

### Test Scenarios

#### Scenario 1: User Can't View Another User's Profile

```dart
// Login as User A
final userA = await auth.signIn(email: 'a@example.com', password: 'password');

// Try to query User B's profile
try {
  final userB = await supabase
    .from('profiles')
    .select()
    .eq('id', userBId)
    .single();
  print('ERROR: Should not be able to view other user profiles');
} on PostgrestException catch (e) {
  print('✅ Correctly blocked: ${e.message}');
}
```

#### Scenario 2: Agent Can Create Listing, User Cannot

```dart
// Login as User (not agent)
await auth.signIn(email: 'user@example.com', password: 'password');

// Try to create listing
try {
  await properties.createListing(listing);
  print('ERROR: User should not be able to create listings');
} on PostgrestException catch (e) {
  print('✅ Correctly blocked: ${e.message}');
}

// Now login as Agent
await auth.signOut();
await auth.signIn(email: 'agent@example.com', password: 'password');

// Should succeed
final listing = await properties.createListing(listing);
print('✅ Agent can create listing: ${listing.id}');
```

#### Scenario 3: Agent Can't Edit Another Agent's Listing

```dart
// Agent A's listing
final listingA = await properties.createListing(...);

// Logout and login as Agent B
await auth.signOut();
await auth.signIn(email: 'agentb@example.com', password: 'password');

// Try to edit Agent A's listing
try {
  await properties.updateListing(listingA.id, updatedData);
  print('ERROR: Should not edit another agent\'s listing');
} on PostgrestException catch (e) {
  print('✅ Correctly blocked: ${e.message}');
}
```

#### Scenario 4: Admin Can Manage Any Listing

```dart
// Admin user
await auth.signIn(email: 'admin@example.com', password: 'password');

// Can edit any listing (regardless of agent_id)
final updated = await properties.updateListing(anyListingId, updatedData);
print('✅ Admin updated listing: ${updated.id}');

// Can view audit logs
final logs = await supabase
  .from('audit_logs')
  .select()
  .order('created_at', ascending: false)
  .limit(10);
print('✅ Admin viewed audit logs: ${logs.length} records');
```

### Running Tests

```bash
# Run all tests (including auth/RLS)
flutter test

# Run specific test file
flutter test test/features/auth/

# Run with verbose output
flutter test -v

# Generate coverage report
flutter test --coverage
```

---

## Migration Deployment

### Local Testing

1. Apply migration locally:
   ```bash
   supabase migration up
   ```

2. Test RLS policies in Supabase SQL Editor:
   ```sql
   -- Set auth context (simulates logged-in user)
   SELECT auth.uid();
   
   -- Try queries
   SELECT * FROM profiles;  -- Should fail without RLS override
   ```

### Production Deployment

1. Push migration to Supabase:
   ```bash
   supabase db push
   ```

2. Verify no errors in Supabase dashboard > SQL Editor

3. Test with real users in staging

4. Monitor `audit_logs` table for any authorization issues

---

## Security Checklist

- ✅ All tables have RLS enabled
- ✅ All public operations have explicit allow policies
- ✅ All sensitive operations use `auth.uid()` checks
- ✅ Roles are enforced at DB level, not app level
- ✅ Subscriptions tied to tier-based features
- ✅ Audit logs track moderation & admin actions
- ✅ Tokens expire (Supabase default: 1 hour)
- ✅ Refresh tokens secure & HttpOnly
- ✅ No passwords logged or stored client-side
- ✅ Sensitive columns (passwords) never queried

---

## Troubleshooting

### "Policy for <operation> does not exist"
**Problem:** Trying to perform an action with no matching policy.
```
Error: new row violates row-level security policy "users_view_own_profile" for table "profiles"
```

**Solution:** 
1. Verify user is authenticated (`auth.uid()` returns a value)
2. Check policy logic matches your operation
3. Add a new policy if needed

### "null" Session After Login
**Problem:** `supabase.auth.currentSession` returns null after sign-in.

**Solution:**
1. Ensure profile was created in sign-up
2. Check auth flow completes before redirecting
3. Verify token storage works (SecureStorage on Android/iOS)

### Profile Not Created After Auth Signup
**Problem:** User authenticated but no profile row.

**Solution:**
1. Check sign-up logic creates profile in `profiles` table
2. Verify trigger `create_default_subscription` fired
3. Use Supabase SQL Editor to manually check: `SELECT * FROM profiles WHERE id = '<user-id>'`

### Admin Can't See Everything
**Problem:** Admin policies not working.

**Solution:**
1. Verify admin's profile has `role = 'admin'` in `profiles` table
2. Test admin policy directly in SQL Editor
3. Admin policies check `profiles` table; ensure it's queried correctly

---

## References

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Supabase RLS Docs](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [PostgreSQL RLS](https://www.postgresql.org/docs/current/sql-createpolicy.html)
- [Land Finder Architecture](../README.md)

---

**Last Updated:** 2026-11-17  
**Version:** 1.0.0  
**Status:** ✅ Production Ready
