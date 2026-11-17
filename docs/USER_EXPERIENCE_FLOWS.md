# 📱 App User Flow & UI/UX Journey

## Complete User Experience Map (Post Phase 1)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      APP STARTUP                                    │
│                   (Splash Screen)                                   │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
           Check: Does Session Exist?
                       │
        ┌──────────────┴──────────────┐
        │                             │
   YES (Session Valid)           NO (No Session)
        │                             │
        ▼                             ▼
   ┌─────────────┐          ┌──────────────────┐
   │ AUTO-LOGIN  │          │  LOGIN/SIGNUP    │
   │  (1-2 sec)  │          │  SCREEN (Choice) │
   │             │          │                  │
   │ Load User   │          │ [Sign In]        │
   │ Load Role   │          │ [Sign Up]        │
   └──────┬──────┘          └────┬────┬────────┘
          │                      │    │
          │                 SIGN IN  SIGN UP
          │                      │    │
          ▼                      ▼    ▼
    ┌──────────────┐      ┌──────────────┐
    │  HOME SCREEN │      │  SIGNUP FORM │
    │              │      │              │
    │ Based on     │      │ • Email      │
    │ Role:        │      │ • Password   │
    │              │      │ • Full Name  │
    │ USER:        │      │ • Role Pick  │
    │ • Browse     │      │   (User/     │
    │   Properties │      │    Agent)    │
    │ • Search     │      └──────┬───────┘
    │ • Save       │             │
    │ • Inquire    │       Create Account
    │              │             │
    │ AGENT:       │  ┌─────────┴──────────┐
    │ • Browse     │  │                    │
    │ • Create     │  ▼                    ▼
    │   Property   │ Success         Error Shown
    │ • Dashboard  │  │                │
    │ • Messages   │  │  Validation    │
    │              │  │  Errors:       │
    │ ADMIN:       │  │  • Invalid     │
    │ • All        │  │    email       │
    │   above +    │  │  • Weak pass   │
    │ • Moderation │  │  • Already     │
    │ • Users      │  │    exists      │
    └──────────────┘  │
          │           │
          └───────────┴─────────────┐
                                    │
                            Retry or Cancel
                                    │
                            ┌───────▼─────────┐
                            │  AUTO-LOGIN     │
                            │  New User       │
                            │                 │
                            │  Load Profile   │
                            │  Load Role      │
                            │  Create Session │
                            └────────┬────────┘
                                     │
                                     ▼
                            ┌──────────────────┐
                            │  HOME SCREEN     │
                            │  Welcome!        │
                            │  User is now in  │
                            │  their role-     │
                            │  based view      │
                            └──────────────────┘
```

---

## 🧑‍💼 User Role: "USER" (Buyer) - Experience Flow

```
┌──────────────────────────────────────────────────────────┐
│                   USER (BUYER) FLOW                      │
└──────────────────────────────────────────────────────────┘

┌─ HOME SCREEN
│  ├─ Hero: "Find Your Perfect Land"
│  ├─ Quick Filter Bar
│  ├─ Featured Properties (from DB)
│  ├─ Nearby Properties (from DB)
│  ├─ Recommended (algorithm - Phase 2)
│  │
│  └─ Bottom Navigation:
│     ├─ [🏠 HOME] ◄─ You are here
│     ├─ [🗺️  MAP]
│     ├─ [🔍 SEARCH]
│     ├─ [❤️  SAVED]
│     ├─ [💬 MESSAGES]
│     └─ [👤 PROFILE]
│
├─ Tap Property Card
│  │
│  ├─ PROPERTY DETAILS SCREEN
│  │  ├─ Photos Gallery
│  │  ├─ Title, Location, Price
│  │  ├─ Description
│  │  ├─ Boundary on Map
│  │  ├─ Agent Info
│  │  │
│  │  ├─ Action Buttons:
│  │  │  ├─ [❤️ Save] ← REAL: Saves to DB
│  │  │  │   (Heart fills, shows "Saved")
│  │  │  │   (Syncs to Supabase favorites table)
│  │  │  │
│  │  │  └─ [💬 Message Agent] ← REAL: Creates inquiry
│  │  │      (Opens inquiry form)
│  │  │      (Stored in inquiries table)
│  │  │
│  │  └─ Back Button → HOME
│  │
│  └─ Tap [❤️ SAVED]
│     │
│     └─ SAVED PROPERTIES SCREEN
│        ├─ Shows all saved properties (from DB)
│        ├─ Can unsave (deletes from DB)
│        ├─ Can tap to view details
│        └─ Empty state: "No saved properties"
│
├─ Tap [💬 MESSAGES]
│  │
│  └─ MESSAGES SCREEN
│     ├─ Conversations list (from DB)
│     ├─ Agent name, last message, timestamp
│     ├─ Tap to open chat
│     │
│     └─ CHAT SCREEN
│        ├─ Message history (from DB)
│        ├─ Type message box
│        ├─ Send button
│        └─ Messages sync in real-time
│
├─ Tap [👤 PROFILE]
│  │
│  └─ PROFILE SCREEN
│     ├─ Avatar (default or uploaded)
│     ├─ Name (from DB)
│     ├─ Email (from DB)
│     ├─ Phone (from DB)
│     ├─ Subscription Status: "Free" (from DB)
│     │  └─ Upgrade Button → PAYWALL (Phase 2)
│     │
│     ├─ Actions:
│     │  ├─ [Edit Profile] ← Updates DB
│     │  ├─ [Change Password] ← New Phase 1 feature
│     │  ├─ [Settings]
│     │  └─ [Log Out] ← Clears session, back to login
│     │
│     └─ App version, support links
│
└─ Logout
   │
   └─ Back to Login Screen
      (Can't access app without login)
```

---

## 🏢 Agent Role: "AGENT" (Seller) - Experience Flow

```
┌──────────────────────────────────────────────────────────┐
│                   AGENT (SELLER) FLOW                    │
└──────────────────────────────────────────────────────────┘

┌─ HOME SCREEN (Enhanced for agents)
│  ├─ Hero: "Manage Your Properties"
│  ├─ Quick Stats: "3 Active Listings | 5 Inquiries"
│  ├─ All user features PLUS:
│  ├─ [+ Create Property] Button (prominent)
│  ├─ Agent-specific recommendations
│  │
│  └─ Bottom Navigation:
│     ├─ [🏠 HOME]
│     ├─ [🏢 DASHBOARD] ◄─ AGENT ONLY
│     ├─ [🔍 SEARCH]
│     ├─ [❤️  SAVED]
│     ├─ [💬 MESSAGES]
│     └─ [👤 PROFILE]
│
├─ Tap [+ Create Property]
│  │
│  └─ CREATE PROPERTY SCREEN
│     ├─ BASIC INFO SECTION
│     │  ├─ Title (required)
│     │  ├─ Description (required)
│     │  ├─ Location/Address (required)
│     │  └─ Category Dropdown
│     │
│     ├─ PRICING SECTION
│     │  ├─ Price (required)
│     │  ├─ Price Unit (PHP, USD, etc.)
│     │  └─ Payment Terms (Cash, Installment)
│     │
│     ├─ PROPERTY DETAILS
│     │  ├─ Size/Area (required)
│     │  ├─ Lot Size
│     │  ├─ Number of Rooms
│     │  └─ Amenities (checkboxes)
│     │
│     ├─ LOCATION
│     │  ├─ Map Preview
│     │  ├─ Draw Boundary (new Phase 1 feature)
│     │  └─ Set exact coordinates
│     │
│     ├─ MEDIA SECTION
│     │  ├─ [+ Add Photos]
│     │  │  └─ Upload images (Phase 2 storage)
│     │  └─ Set featured photo
│     │
│     ├─ PREVIEW (how it looks to buyers)
│     │
│     └─ [Submit] Button
│        │
│        ├─ Processing... (1-2 seconds)
│        │
│        └─ Success! ✅
│           ├─ Property created in DB
│           ├─ Shows in your listings
│           ├─ Becomes searchable by users
│           └─ Buyers can find & save it
│
├─ Tap [🏢 DASHBOARD]
│  │
│  └─ AGENT DASHBOARD SCREEN
│     ├─ STATS SECTION (Real-time from DB)
│     │  ├─ 3 Active Listings
│     │  ├─ 12 Total Views (Phase 2 analytics)
│     │  ├─ 5 New Inquiries
│     │  └─ 2 Messages Waiting
│     │
│     ├─ MY LISTINGS SECTION (from DB)
│     │  ├─ Property 1
│     │  │  ├─ Thumbnail
│     │  │  ├─ Title
│     │  │  ├─ Price
│     │  │  ├─ Status: "Active" (from DB)
│     │  │  │  └─ Tap to change status
│     │  │  │  └─ Options: Active, Sold, Archived
│     │  │  │
│     │  │  ├─ Actions:
│     │  │  │  ├─ [View]
│     │  │  │  ├─ [Edit] ← Updates DB
│     │  │  │  ├─ [Analytics]
│     │  │  │  └─ [Delete] ← Soft delete
│     │  │  │
│     │  │  └─ Swipe to delete
│     │  │
│     │  └─ Property 2, Property 3...
│     │
│     ├─ INQUIRIES SECTION (from DB)
│     │  ├─ Inquiry from "John Doe"
│     │  │  ├─ Message: "Is this property still available?"
│     │  │  ├─ Date: 2 hours ago
│     │  │  ├─ Status: "Pending" (from DB)
│     │  │  │  └─ [Mark as Viewed] → Status: "Viewed"
│     │  │  │  └─ [Respond] → Open chat
│     │  │  │
│     │  │  └─ [Contact John]
│     │  │
│     │  └─ More inquiries...
│     │
│     └─ Teams Section
│        ├─ Current Teams
│        ├─ Create/Join Team (Phase 5)
│        └─ Manage Team Members
│
├─ Tap [💬 MESSAGES]
│  │
│  └─ AGENT INBOX
│     ├─ Shows all conversations
│     ├─ Marked: "Responded" or "Pending"
│     ├─ Can view & reply
│     └─ Updates DB with responses
│
├─ Tap [👤 PROFILE]
│  │
│  └─ AGENT PROFILE
│     ├─ All user profile features PLUS:
│     ├─ Agent Badge/Verification
│     ├─ Agent Rating (from reviews table)
│     │  └─ Shows average star rating
│     │  └─ Shows number of reviews
│     ├─ Subscription: "Free" (can upgrade)
│     │  └─ [Upgrade to Premium]
│     │     └─ Unlock: Unlimited listings, etc.
│     ├─ Listings Count
│     ├─ Total Inquiries Received
│     └─ Agent Settings
│        ├─ Commission Settings
│        ├─ Team Management
│        └─ Notification Preferences
│
└─ Logout → Back to Login
```

---

## 👨‍⚖️ Admin Role: "ADMIN" - Experience Flow

```
┌──────────────────────────────────────────────────────────┐
│                   ADMIN - EXPERIENCE                     │
│                 (Full System Access)                     │
└──────────────────────────────────────────────────────────┘

┌─ HOME SCREEN (Admin dashboard)
│  ├─ All user/agent features visible
│  ├─ System Stats
│  │  ├─ Total Users: 1,234
│  │  ├─ Total Properties: 5,678
│  │  ├─ Total Inquiries: 3,456
│  │  └─ Revenue (Phase 2)
│  │
│  └─ Bottom Navigation:
│     ├─ [🏠 HOME]
│     ├─ [👥 USERS] ◄─ ADMIN ONLY
│     ├─ [📋 MODERATION] ◄─ ADMIN ONLY
│     ├─ [📊 ANALYTICS] ◄─ ADMIN ONLY
│     └─ [⚙️ SETTINGS] ◄─ ADMIN ONLY
│
├─ Tap [👥 USERS]
│  │
│  └─ USER MANAGEMENT
│     ├─ List all users (from profiles table)
│     ├─ User Info:
│     │  ├─ Email
│     │  ├─ Role
│     │  ├─ Subscription
│     │  ├─ Created Date
│     │  │
│     │  └─ Actions:
│     │     ├─ [View Profile]
│     │     ├─ [Edit Role]
│     │     ├─ [View Activity]
│     │     ├─ [Suspend]
│     │     └─ [Delete]
│     │
│     └─ Search & Filter by role
│
├─ Tap [📋 MODERATION]
│  │
│  └─ MODERATION DASHBOARD
│     ├─ Reports List (from moderation_reports table)
│     │  ├─ Report from "User123"
│     │  │  ├─ Type: "Inappropriate Content"
│     │  │  ├─ About: Property ID or User
│     │  │  ├─ Description: "This listing has offensive language"
│     │  │  ├─ Date: 1 day ago
│     │  │  ├─ Status: "Pending" → "Reviewing" → "Resolved"
│     │  │  │
│     │  │  └─ Actions:
│     │  │     ├─ [View Content]
│     │  │     ├─ [View Reporter]
│     │  │     ├─ [Dismiss]
│     │  │     ├─ [Flag Content]
│     │  │     ├─ [Suspend User]
│     │  │     └─ [Add Note]
│     │  │
│     │  └─ More reports...
│     │
│     └─ Filter by: Status, Type, Date
│
├─ Tap [📊 ANALYTICS]
│  │
│  └─ ADMIN ANALYTICS
│     ├─ User Growth Chart
│     ├─ Properties by Category
│     ├─ Revenue (Phase 2)
│     ├─ Subscription Stats
│     ├─ Inquiry Trends
│     └─ Export Reports
│
├─ Tap [⚙️ SETTINGS]
│  │
│  └─ ADMIN SETTINGS
│     ├─ System Configuration
│     ├─ Feature Flags
│     ├─ Notification Rules
│     ├─ Pricing Configuration (Phase 2)
│     ├─ Maintenance Mode
│     ├─ Audit Logs (all actions recorded)
│     └─ Database Backups
│
└─ Logout
```

---

## 🔄 Data Flow: What Actually Happens

### Scenario: User Saves a Property

**Visible Steps:**
```
1. User: Taps on property card
   App: "Loading..." spinner
   Network: Fetches property details from Supabase
   
2. User: Sees property details page
   
3. User: Taps [❤️ Save] button
   App: Sends to Supabase
   Network: 1-2 second delay
   
4. User: Sees success
   App: Heart icon fills ❤️
   App: Toast message "Property saved!"
   
5. Data persists to:
   - Supabase favorites table ✅
   - User's favorites list ✅
   - Syncs to any other device ✅
```

### Scenario: Agent Creates Property

**Visible Steps:**
```
1. Agent: Taps [+ Create Property]
   App: Opens form
   
2. Agent: Fills out all fields
   - Title, description, price, location
   - Upload images (Phase 2)
   - Draw boundary on map
   
3. Agent: Taps [Submit]
   App: Shows "Creating..."
   Network: Sends to Supabase
   Supabase: RLS checks role = 'agent' ✅
   Database: Inserts into properties table
   
4. Agent: Sees success
   App: Toast "Property created!"
   App: Navigates to My Listings
   
5. Within seconds:
   - Property searchable by users ✅
   - Property can be saved ✅
   - Inquiries can be sent ✅
```

---

## ⚡ Performance: What to Expect

### Speed Comparison

| Action | Before Phase 1 | After Phase 1 |
|--------|----------------|---------------|
| Signup | Instant | 1-2 seconds (network) |
| Login | Instant | 1-2 seconds (network) |
| Logout | Instant | <1 second |
| Load Properties | Instant (mock) | 1-2 seconds (real data) |
| Save Property | Instant (local) | 1-2 seconds (synced) |
| Create Property | Instant (mock) | 2-3 seconds (uploaded) |
| Data Persistence | None | Permanent ✅ |
| Multi-Device Sync | ❌ Not possible | ✅ Automatic |

---

## 🎯 Key Behavioral Changes Users Will Notice

### 1. Network Delays
```
Before: Everything instant (all local)
After: 1-2 second delays for network calls
Reason: Real network, real security checks
```

### 2. Persistent Data
```
Before: Close app → data gone
After: Close app → data persists
How: Stored in Supabase database
Benefit: Safe, can access from any device
```

### 3. Required Login
```
Before: Optional, could browse without account
After: Must login to access app
Why: Secure, role-based access
Benefit: Real user accounts, real data ownership
```

### 4. Cross-Device Access
```
Before: Can't use same account on 2 devices
After: Login on iPhone → open on Android → see same data
How: Supabase session tokens
Benefit: Seamless experience
```

### 5. Role-Based UI
```
Before: Everyone sees same interface
After: Different UI based on role
Example: User doesn't see "Create Property" button
Benefit: Cleaner, more relevant UI
```

---

## ✅ Quick Checklist: What to Verify After Deploy

After deploying Phase 1, test these:

- [ ] **Signup** – Creates account, shows success message
- [ ] **Auto-Login** – Close app, reopen, still logged in
- [ ] **Different Roles** – Sign up as User vs Agent, see different UIs
- [ ] **Persistence** – Save property, close app, property still saved
- [ ] **Multi-Device** – Login on Android, see same profile
- [ ] **RLS** – User can't edit another user's data
- [ ] **Logout** – Logs out from Supabase, can't access app without login
- [ ] **Errors** – Email validation, password validation works
- [ ] **Network** – Slight delays for network calls (normal)
- [ ] **Profile** – Changes save to database

---

**Status: Ready to deploy and test!**
