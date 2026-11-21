// Generated from docs/app_user_flow.md. Do not edit directly.
window.APP_FLOW_DATA = 
{
  "nodes": [
    {
      "id": "splash",
      "title": "Splash / Bootstrap",
      "x": 28,
      "y": 92,
      "role": "entry",
      "lane": "entry",
      "status": "complete",
      "icon": "KB",
      "route": "/",
      "description": "Initializes app state, restores the session, and selects the correct entry route.",
      "actions": [
        "Resolve role and auth state",
        "Route to onboarding or a workspace",
        "Fallback unknown routes here"
      ],
      "note": "Verify cold start, deep link, stale-session, and offline behavior.",
      "source": "lib/app/bootstrap and route redirect"
    },
    {
      "id": "onboarding",
      "title": "Guest onboarding",
      "x": 28,
      "y": 204,
      "role": "entry",
      "lane": "entry",
      "status": "complete",
      "icon": "GO",
      "route": "/onboarding",
      "description": "Introduces the marketplace and lets a guest begin without an account.",
      "actions": [
        "Continue to guest buyer view",
        "Open login or registration"
      ],
      "note": "Confirm copy, permissions, skip behavior, and returning-user state.",
      "source": "lib/features/onboarding/presentation"
    },
    {
      "id": "auth",
      "title": "Login / Register",
      "x": 28,
      "y": 316,
      "role": "entry",
      "lane": "entry",
      "status": "complete",
      "icon": "ID",
      "route": "/login /register",
      "description": "Email authentication branch for buyer, agent, and administrator accounts.",
      "actions": [
        "Choose login or create account",
        "Recover a password",
        "Resolve role-aware destination"
      ],
      "note": "Test invalid credentials, duplicate accounts, confirmation, and expired sessions.",
      "source": "lib/features/auth/presentation"
    },
    {
      "id": "recovery",
      "title": "Password recovery",
      "x": 28,
      "y": 428,
      "role": "entry",
      "lane": "entry",
      "status": "integration",
      "icon": "PW",
      "route": "/forgot-password",
      "description": "Requests an account recovery email and guides the user back to sign-in.",
      "actions": [
        "Submit account email",
        "Open reset link",
        "Return to login"
      ],
      "note": "Verify email delivery, callback/deep-link setup, and reset expiration.",
      "source": "lib/features/auth/presentation"
    },
    {
      "id": "home",
      "title": "Buyer Home",
      "x": 302,
      "y": 92,
      "role": "buyer",
      "lane": "shell",
      "status": "complete",
      "icon": "H",
      "route": "/home (Home tab)",
      "description": "Primary buyer-shell tab with featured properties, recent discovery, and entry points into search.",
      "actions": [
        "Search and filter properties",
        "Switch to Map, Saved, Inbox, or Profile"
      ],
      "note": "Check startup data, empty feed, pagination, and navigation-bar persistence.",
      "source": "lib/features/home/presentation"
    },
    {
      "id": "map",
      "title": "Map",
      "x": 302,
      "y": 204,
      "role": "buyer",
      "lane": "shell",
      "status": "integration",
      "icon": "M",
      "route": "/home Map tab /map",
      "description": "Map-led property discovery shown as a buyer-shell tab. /map is also a direct route.",
      "actions": [
        "Pan and inspect markers",
        "Open property details"
      ],
      "note": "Test Mapbox token, network loss, permissions, marker density, and camera restoration.",
      "source": "lib/features/map/presentation"
    },
    {
      "id": "saved",
      "title": "Saved",
      "x": 302,
      "y": 316,
      "role": "buyer",
      "lane": "shell",
      "status": "integration",
      "icon": "♥",
      "route": "/home Saved tab /favorites",
      "description": "Favorite-property screen shown as a buyer-shell tab. /favorites is also a direct route.",
      "actions": [
        "Open a saved property",
        "Remove favorite",
        "Upgrade at limit"
      ],
      "note": "Validate backend sync, optimistic updates, guest restrictions, and limit messaging.",
      "source": "lib/features/favorites/presentation"
    },
    {
      "id": "inbox",
      "title": "Inbox",
      "x": 302,
      "y": 428,
      "role": "buyer",
      "lane": "shell",
      "status": "integration",
      "icon": "IN",
      "route": "/home Inbox tab /inbox",
      "description": "Buyer conversation index shown as a tab. /inbox is also a direct named route.",
      "actions": [
        "Open a conversation",
        "Message the listing agent"
      ],
      "note": "Verify real-time delivery, unread counts, push notifications, and reconnect behavior.",
      "source": "lib/features/messaging/presentation"
    },
    {
      "id": "profile",
      "title": "Profile",
      "x": 302,
      "y": 540,
      "role": "buyer",
      "lane": "shell",
      "status": "integration",
      "icon": "P",
      "route": "/home Profile tab /profile",
      "description": "Account screen shown as a tab. /profile and /edit-profile are direct routes.",
      "actions": [
        "Edit profile information",
        "Manage subscription",
        "Sign out"
      ],
      "note": "Check profile persistence, avatar upload, and authenticated account state.",
      "source": "lib/features/profile/presentation"
    },
    {
      "id": "search",
      "title": "Search & Filter",
      "x": 636,
      "y": 92,
      "role": "buyer",
      "lane": "journey",
      "status": "complete",
      "icon": "⌕",
      "route": "/search /property-search /property-filter",
      "description": "Searchable property inventory with registered search and filter screens.",
      "actions": [
        "Apply filters",
        "Open matching property",
        "Reset search criteria"
      ],
      "note": "Exercise keyboard, empty results, clear/reset, and filter restoration.",
      "source": "lib/features/search and lib/features/properties/presentation"
    },
    {
      "id": "details",
      "title": "Property Details",
      "x": 636,
      "y": 204,
      "role": "buyer",
      "lane": "journey",
      "status": "complete",
      "icon": "PD",
      "route": "/property-details + args",
      "description": "Focused listing view with land facts, media, asking price, location, and agent identity.",
      "actions": [
        "View gallery",
        "Save property",
        "Contact the agent"
      ],
      "note": "Verify required PropertyDetailsArgs, stale inventory, long copy, and unavailable media.",
      "source": "lib/features/properties/presentation"
    },
    {
      "id": "gallery",
      "title": "Gallery",
      "x": 636,
      "y": 316,
      "role": "buyer",
      "lane": "journey",
      "status": "complete",
      "icon": "▧",
      "route": "/property-gallery + args",
      "description": "Full-screen media viewer opened with required PropertyGalleryArgs.",
      "actions": [
        "Swipe through images",
        "Return to details"
      ],
      "note": "Confirm caching, zoom, image failures, and swipe direction on actual devices.",
      "source": "lib/features/properties/presentation"
    },
    {
      "id": "contact",
      "title": "Contact Agent",
      "x": 636,
      "y": 428,
      "role": "buyer",
      "lane": "journey",
      "status": "integration",
      "icon": "CA",
      "route": "/inquiries (internal inquiry action)",
      "description": "Inquiry screen plus inquiry creation from the property flow.",
      "actions": [
        "Compose inquiry",
        "Open buyer chat"
      ],
      "note": "Validate guest-to-login redirect, message creation, ownership, and offline submission.",
      "source": "lib/features/inquiries/presentation"
    },
    {
      "id": "chat",
      "title": "Buyer Chat",
      "x": 636,
      "y": 540,
      "role": "buyer",
      "lane": "journey",
      "status": "integration",
      "icon": "CH",
      "route": "/chat + ChatScreenArgs",
      "description": "One-to-one buyer and agent conversation with conversation context passed as arguments.",
      "actions": [
        "Send and receive messages",
        "Return to buyer inbox"
      ],
      "note": "Check delivery state, timestamps, long threads, attachment scope, and push deep links.",
      "source": "lib/features/messaging/presentation"
    },
    {
      "id": "limit",
      "title": "Saved Limit",
      "x": 970,
      "y": 92,
      "role": "buyer",
      "lane": "upgrade",
      "status": "integration",
      "icon": "!",
      "route": "Internal entitlement gate (no route)",
      "description": "A conceptual gate within the saved-property and subscription experience.",
      "actions": [
        "Review limit",
        "View plans",
        "Restore purchases"
      ],
      "note": "Verify entitlements, guest behavior, server truth, and no-billing bypass paths.",
      "source": "lib/features/subscription/presentation"
    },
    {
      "id": "plans",
      "title": "Subscription Plans",
      "x": 970,
      "y": 204,
      "role": "buyer",
      "lane": "upgrade",
      "status": "integration",
      "icon": "$",
      "route": "/subscription /plans",
      "description": "Registered subscription and plans screens for store-managed purchase options.",
      "actions": [
        "Select plan",
        "Start purchase",
        "Restore prior purchase"
      ],
      "note": "Test store availability, localized pricing, rejected products, and slow network responses.",
      "source": "lib/features/subscription/presentation"
    },
    {
      "id": "purchase",
      "title": "Purchase / Verify",
      "x": 970,
      "y": 428,
      "role": "buyer",
      "lane": "upgrade",
      "status": "integration",
      "icon": "$✓",
      "route": "In-screen step (native store)",
      "description": "Purchase controls and verification inside the subscription flow.",
      "actions": [
        "Complete native purchase",
        "Verify receipt",
        "Unlock saved capacity"
      ],
      "note": "Use sandbox products and verify cancellation, duplicate receipts, refunds, and retry.",
      "source": "lib/features/subscription/data/services"
    },
    {
      "id": "restore",
      "title": "Restore / Manage",
      "x": 970,
      "y": 540,
      "role": "buyer",
      "lane": "upgrade",
      "status": "integration",
      "icon": "↺",
      "route": "In-screen actions (no route)",
      "description": "Restore and store-management actions belonging to the subscription UI.",
      "actions": [
        "Restore purchases",
        "Open store management",
        "Re-check entitlement"
      ],
      "note": "Confirm same-account restoration and behavior when the store has no transactions.",
      "source": "lib/features/subscription/presentation"
    },
    {
      "id": "paymongoMethods",
      "title": "PayMongo Methods",
      "x": 970,
      "y": 652,
      "role": "buyer",
      "lane": "upgrade",
      "status": "blocked",
      "icon": "PM",
      "route": "Internal provider (Supabase function)",
      "description": "Loads available PayMongo methods through the get_billing_availability edge function. This branch is implemented but not verified as connected or deployed.",
      "actions": [
        "Load enabled methods",
        "Handle unavailable or disabled checkout"
      ],
      "note": "Verify the deployed function, authentication, secret configuration, and enabled-method flags.",
      "source": "lib/features/subscription/data/services/paymongo_billing_provider.dart"
    },
    {
      "id": "paymongoCheckout",
      "title": "PayMongo Checkout",
      "x": 970,
      "y": 764,
      "role": "buyer",
      "lane": "upgrade",
      "status": "blocked",
      "icon": "P$",
      "route": "External PayMongo checkout (no app route)",
      "description": "Creates a billing checkout through Supabase and opens the PayMongo URL outside the app.",
      "actions": [
        "Create checkout session",
        "Open external browser",
        "Return to app"
      ],
      "note": "Verify create_billing_checkout deployment, amount mapping, deep return, cancellations, and real sandbox payment.",
      "source": "lib/features/subscription/presentation/screens/purchase_flow_screen.dart"
    },
    {
      "id": "paymongoVerify",
      "title": "Order / Webhook Verify",
      "x": 970,
      "y": 876,
      "role": "buyer",
      "lane": "upgrade",
      "status": "blocked",
      "icon": "✓?",
      "route": "Edge functions / webhook (no app route)",
      "description": "Polls billing order state and relies on webhook verification to update entitlement. End-to-end connection is not yet verified.",
      "actions": [
        "Poll billing order",
        "Receive webhook",
        "Confirm entitlement"
      ],
      "note": "Verify get_billing_order, paymongo_webhook, signature validation, idempotency, and entitlement update.",
      "source": "supabase/functions and lib/features/subscription/data/services/paymongo_billing_provider.dart"
    },
    {
      "id": "agent",
      "title": "Agent Dashboard",
      "x": 1304,
      "y": 92,
      "role": "agent",
      "lane": "agent",
      "status": "guarded",
      "icon": "AD",
      "route": "/agent-dashboard",
      "description": "Agent-role-protected overview with listing, message, and team shortcuts.",
      "actions": [
        "Create or manage listing",
        "Open buyer inbox",
        "Open teams"
      ],
      "note": "Test role guard, account switching, suspended agent state, and session expiry.",
      "source": "lib/features/agent/presentation"
    },
    {
      "id": "create",
      "title": "Create Listing",
      "x": 1304,
      "y": 204,
      "role": "agent",
      "lane": "agent",
      "status": "guarded",
      "icon": "+L",
      "route": "/create-listing",
      "description": "Role-protected listing authoring flow for land details, pricing, and media.",
      "actions": [
        "Draft listing",
        "Upload media",
        "Submit for moderation"
      ],
      "note": "Validate draft recovery, upload limits, required fields, and permission errors.",
      "source": "lib/features/agent/presentation"
    },
    {
      "id": "manage",
      "title": "Manage Listings",
      "x": 1304,
      "y": 316,
      "role": "agent",
      "lane": "agent",
      "status": "guarded",
      "icon": "ML",
      "route": "/manage-listings /edit-listing",
      "description": "Role-protected screens for owned listings and editing an existing property.",
      "actions": [
        "Edit listing",
        "Review moderation status",
        "Pause or publish"
      ],
      "note": "Check ownership isolation, stale records, empty state, and destructive confirmations.",
      "source": "lib/features/agent/presentation"
    },
    {
      "id": "agentInbox",
      "title": "Buyer Inbox",
      "x": 1304,
      "y": 428,
      "role": "agent",
      "lane": "agent",
      "status": "guarded",
      "icon": "BI",
      "route": "/inbox /chat + args",
      "description": "Registered inbox and chat routes opened from the role-protected agent workspace.",
      "actions": [
        "Open buyer conversation",
        "Reply and mark read"
      ],
      "note": "Verify real-time updates, unread counts, role authorization, and push deep links.",
      "source": "lib/features/messaging/presentation"
    },
    {
      "id": "teams",
      "title": "Teams",
      "x": 1304,
      "y": 540,
      "role": "agent",
      "lane": "agent",
      "status": "guarded",
      "icon": "TM",
      "route": "/agent-teams",
      "description": "Authenticated agent-team workspace.",
      "actions": [
        "Review team access",
        "Open team-specific tools"
      ],
      "note": "Validate membership changes, invitation state, and cross-team data boundaries.",
      "source": "lib/features/agent_teams/presentation"
    },
    {
      "id": "guestGate",
      "title": "Login Required Gate",
      "x": 28,
      "y": 540,
      "role": "buyer",
      "lane": "entry",
      "status": "planned",
      "icon": "LG",
      "route": "Internal gate (no route)",
      "description": "Stops a guest who tries a protected action (save, inquire, subscribe), sends them to login, then resumes the original action.",
      "actions": [
        "Explain why login is needed",
        "Open login or registration",
        "Resume the interrupted action"
      ],
      "note": "Verify the intended action survives login, registration, and password recovery.",
      "source": "lib/features/auth/presentation (to be added)"
    },
    {
      "id": "signout",
      "title": "Sign Out",
      "x": 302,
      "y": 652,
      "role": "buyer",
      "lane": "shell",
      "status": "planned",
      "icon": "SO",
      "route": "Profile action (no route)",
      "description": "Ends the session, clears cached account state, and returns the user to onboarding.",
      "actions": [
        "Confirm sign out",
        "Clear local session and push token",
        "Return to onboarding"
      ],
      "note": "Check agent and admin sign-out, token cleanup, and back-button behavior after logout.",
      "source": "lib/features/profile/presentation (to be added)"
    },
    {
      "id": "deleteAcct",
      "title": "Delete Account",
      "x": 302,
      "y": 764,
      "role": "buyer",
      "lane": "shell",
      "status": "planned",
      "icon": "DA",
      "route": "/delete-account (planned)",
      "description": "In-app account deletion, expected by Apple and Google for apps that allow account creation.",
      "actions": [
        "Confirm identity",
        "Delete account and personal data",
        "Return to onboarding"
      ],
      "note": "Decide what happens to an agent's listings, chats, and active subscription when the account is deleted.",
      "source": "lib/features/profile/presentation and a Supabase edge function (to be added)"
    },
    {
      "id": "report",
      "title": "Report Listing",
      "x": 636,
      "y": 652,
      "role": "buyer",
      "lane": "journey",
      "status": "planned",
      "icon": "RP",
      "route": "Property details action (planned)",
      "description": "Lets a buyer report a listing, feeding the admin moderation queue that already handles reported content.",
      "actions": [
        "Pick a reason",
        "Submit report",
        "Show confirmation"
      ],
      "note": "Prevent duplicate reports and confirm the report appears in the moderation queue with context.",
      "source": "lib/features/properties/presentation (to be added)"
    },
    {
      "id": "billingChoice",
      "title": "Billing Route Decision",
      "x": 970,
      "y": 316,
      "role": "buyer",
      "lane": "upgrade",
      "status": "planned",
      "icon": "BR",
      "route": "Internal decision (no route)",
      "description": "Decides whether a purchase uses native store billing or PayMongo, so the two paths never overlap for the same unlock.",
      "actions": [
        "Select store billing by platform",
        "Offer PayMongo only where allowed",
        "Fall back with a clear message"
      ],
      "note": "Check Apple and Google billing policy for digital unlocks before enabling PayMongo in the mobile app.",
      "source": "lib/features/subscription/data/services"
    },
    {
      "id": "admin",
      "title": "Admin Dashboard",
      "x": 1572,
      "y": 92,
      "role": "admin",
      "lane": "admin",
      "status": "guarded",
      "icon": "AU",
      "route": "/admin-dashboard",
      "description": "Admin-only control surface for platform review and moderation activity.",
      "actions": [
        "Open moderation queue",
        "Inspect platform content"
      ],
      "note": "Enforce admin guard server-side and confirm non-admin deep-link denial.",
      "source": "lib/features/admin/presentation"
    },
    {
      "id": "moderation",
      "title": "Moderation Queue",
      "x": 1572,
      "y": 204,
      "role": "admin",
      "lane": "admin",
      "status": "guarded",
      "icon": "MQ",
      "route": "/moderation",
      "description": "Admin-only queue for listing submissions, edits awaiting review, buyer reports, and previously rejected content.",
      "actions": [
        "Filter pending cases",
        "Open a listing review",
        "Open a buyer report"
      ],
      "note": "Verify queue counts, permissions, stale cases, and priority ordering.",
      "source": "lib/features/admin/presentation"
    },
    {
      "id": "listingReview",
      "title": "Listing Review",
      "x": 1572,
      "y": 316,
      "role": "admin",
      "lane": "admin",
      "status": "guarded",
      "icon": "LR",
      "route": "Moderation detail state (admin only)",
      "description": "Review workspace for the submitted listing, property images, agent identity, and edit history.",
      "actions": [
        "Inspect listing content",
        "Compare previous version",
        "Open decision panel"
      ],
      "note": "Confirm the original submission is preserved and unavailable images do not block review.",
      "source": "lib/features/admin/presentation"
    },
    {
      "id": "reportDetails",
      "title": "Report Details",
      "x": 1572,
      "y": 428,
      "role": "admin",
      "lane": "admin",
      "status": "guarded",
      "icon": "RD",
      "route": "Moderation report detail (admin only)",
      "description": "Displays the buyer report reason, evidence, duplicate reports, listing context, and resolution state.",
      "actions": [
        "Inspect report evidence",
        "Open reported listing",
        "Continue to decision"
      ],
      "note": "Prevent duplicate reports from creating duplicate cases and protect reporter identity appropriately.",
      "source": "lib/features/admin/presentation"
    },
    {
      "id": "moderationDecision",
      "title": "Decision & Reason",
      "x": 1572,
      "y": 540,
      "role": "admin",
      "lane": "admin",
      "status": "guarded",
      "icon": "MD",
      "route": "Moderation action panel (admin only)",
      "description": "Captures the admin decision and required reason for approval, rejection, requested changes, temporary hiding, or escalation.",
      "actions": [
        "Approve or publish",
        "Reject with reason",
        "Request changes",
        "Hide or escalate"
      ],
      "note": "Require a reason for adverse actions and keep decisions idempotent when requests are retried.",
      "source": "lib/features/admin/presentation"
    },
    {
      "id": "moderationNotify",
      "title": "Notify Agent / Reporter",
      "x": 1572,
      "y": 652,
      "role": "admin",
      "lane": "admin",
      "status": "integration",
      "icon": "NT",
      "route": "Backend notifications (no app route)",
      "description": "Sends the decision to the agent and resolves the buyer report when applicable.",
      "actions": [
        "Notify listing agent",
        "Notify reporter",
        "Refresh listing status"
      ],
      "note": "Verify delivery, retries, notification preferences, and no sensitive report details are exposed.",
      "source": "lib/features/notifications and Supabase integration"
    },
    {
      "id": "moderationAudit",
      "title": "Moderation Audit Log",
      "x": 1572,
      "y": 764,
      "role": "admin",
      "lane": "admin",
      "status": "guarded",
      "icon": "AL",
      "route": "Moderation review audit section",
      "description": "Immutable history of reviewer, previous status, decision, reason, and timestamp displayed inside the admin review screen.",
      "actions": [
        "Inspect review history",
        "Return to the queue"
      ],
      "note": "The UI is connected to the audit table; audit visibility and writes are protected by database RLS and the admin-only RPC.",
      "source": "lib/features/admin/presentation and Supabase backend"
    }
  ],
  "edges": [
    [
      "splash",
      "onboarding",
      "first run",
      "straight"
    ],
    [
      "splash",
      "home",
      "session restored",
      "branch"
    ],
    [
      "splash",
      "agent",
      "agent session",
      "guard"
    ],
    [
      "splash",
      "admin",
      "admin session",
      "guard"
    ],
    [
      "onboarding",
      "auth",
      "sign in",
      "straight"
    ],
    [
      "auth",
      "recovery",
      "forgot",
      "branch"
    ],
    [
      "recovery",
      "auth",
      "back to login",
      "branch"
    ],
    [
      "onboarding",
      "home",
      "continue guest",
      "branch"
    ],
    [
      "auth",
      "home",
      "buyer",
      "branch"
    ],
    [
      "home",
      "map",
      "tab",
      "straight"
    ],
    [
      "home",
      "saved",
      "tab",
      "straight"
    ],
    [
      "home",
      "inbox",
      "tab",
      "straight"
    ],
    [
      "home",
      "profile",
      "tab",
      "straight"
    ],
    [
      "home",
      "search",
      "discover",
      "branch"
    ],
    [
      "search",
      "details",
      "select",
      "straight"
    ],
    [
      "map",
      "details",
      "marker",
      "branch"
    ],
    [
      "saved",
      "details",
      "open",
      "branch"
    ],
    [
      "details",
      "saved",
      "save",
      "branch"
    ],
    [
      "details",
      "gallery",
      "media",
      "straight"
    ],
    [
      "details",
      "contact",
      "inquire",
      "branch"
    ],
    [
      "details",
      "limit",
      "at limit",
      "needs"
    ],
    [
      "details",
      "guestGate",
      "guest action",
      "planned"
    ],
    [
      "guestGate",
      "auth",
      "sign in",
      "planned"
    ],
    [
      "auth",
      "details",
      "resume action",
      "branch"
    ],
    [
      "details",
      "report",
      "report",
      "planned"
    ],
    [
      "report",
      "reportDetails",
      "submitted",
      "guard"
    ],
    [
      "contact",
      "chat",
      "thread",
      "straight"
    ],
    [
      "inbox",
      "chat",
      "open",
      "branch"
    ],
    [
      "saved",
      "limit",
      "at limit",
      "needs"
    ],
    [
      "limit",
      "plans",
      "upgrade",
      "straight"
    ],
    [
      "plans",
      "billingChoice",
      "choose plan",
      "planned"
    ],
    [
      "billingChoice",
      "purchase",
      "store billing",
      "planned"
    ],
    [
      "billingChoice",
      "paymongoMethods",
      "PayMongo",
      "blocked"
    ],
    [
      "plans",
      "restore",
      "existing buyer",
      "needs"
    ],
    [
      "purchase",
      "saved",
      "unlocked",
      "branch"
    ],
    [
      "restore",
      "profile",
      "restored",
      "branch"
    ],
    [
      "profile",
      "plans",
      "manage plan",
      "branch"
    ],
    [
      "profile",
      "signout",
      "sign out",
      "planned"
    ],
    [
      "signout",
      "onboarding",
      "signed out",
      "planned"
    ],
    [
      "profile",
      "deleteAcct",
      "delete",
      "planned"
    ],
    [
      "deleteAcct",
      "onboarding",
      "confirmed",
      "planned"
    ],
    [
      "purchase",
      "plans",
      "failed / cancelled",
      "branch"
    ],
    [
      "paymongoMethods",
      "paymongoCheckout",
      "not connected",
      "blocked"
    ],
    [
      "paymongoCheckout",
      "paymongoVerify",
      "not connected",
      "blocked"
    ],
    [
      "paymongoVerify",
      "saved",
      "verified",
      "blocked"
    ],
    [
      "paymongoVerify",
      "plans",
      "failed / pending",
      "blocked"
    ],
    [
      "auth",
      "agent",
      "agent",
      "guard"
    ],
    [
      "auth",
      "admin",
      "admin",
      "guard"
    ],
    [
      "agent",
      "create",
      "new",
      "guard"
    ],
    [
      "agent",
      "manage",
      "manage",
      "guard"
    ],
    [
      "agent",
      "agentInbox",
      "messages",
      "guard"
    ],
    [
      "agentInbox",
      "chat",
      "open",
      "branch"
    ],
    [
      "agent",
      "teams",
      "team",
      "guard"
    ],
    [
      "create",
      "moderation",
      "submit",
      "guard"
    ],
    [
      "admin",
      "moderation",
      "review",
      "guard"
    ],
    [
      "moderation",
      "listingReview",
      "open submission",
      "guard"
    ],
    [
      "moderation",
      "reportDetails",
      "open report",
      "guard"
    ],
    [
      "listingReview",
      "moderationDecision",
      "inspect evidence",
      "guard"
    ],
    [
      "reportDetails",
      "moderationDecision",
      "review report",
      "guard"
    ],
    [
      "moderationDecision",
      "moderationNotify",
      "approve / reject",
      "branch"
    ],
    [
      "moderationDecision",
      "manage",
      "changes required",
      "guard"
    ],
    [
      "moderationDecision",
      "moderationAudit",
      "record",
      "guard"
    ],
    [
      "moderationAudit",
      "moderation",
      "back to queue",
      "guard"
    ],
    [
      "moderationNotify",
      "manage",
      "status update",
      "guard"
    ],
    [
      "moderationNotify",
      "reportDetails",
      "report resolved",
      "guard"
    ]
  ],
  "journeys": [
    {
      "title": "Guest discovers a property",
      "short": "Guest → home → search → details",
      "nodes": [
        "splash",
        "onboarding",
        "home",
        "search",
        "details"
      ],
      "edges": [
        [
          "splash",
          "onboarding"
        ],
        [
          "onboarding",
          "home"
        ],
        [
          "home",
          "search"
        ],
        [
          "search",
          "details"
        ]
      ]
    },
    {
      "title": "Buyer saves a property",
      "short": "Details → saved → optional limit",
      "nodes": [
        "home",
        "search",
        "details",
        "saved",
        "limit"
      ],
      "edges": [
        [
          "home",
          "search"
        ],
        [
          "search",
          "details"
        ],
        [
          "details",
          "saved"
        ],
        [
          "saved",
          "limit"
        ]
      ]
    },
    {
      "title": "Buyer messages an agent",
      "short": "Listing → inquiry → chat",
      "nodes": [
        "home",
        "search",
        "details",
        "contact",
        "chat"
      ],
      "edges": [
        [
          "home",
          "search"
        ],
        [
          "search",
          "details"
        ],
        [
          "details",
          "contact"
        ],
        [
          "contact",
          "chat"
        ]
      ]
    },
    {
      "title": "Buyer upgrades",
      "short": "Limit → plans → decision → purchase",
      "nodes": [
        "saved",
        "limit",
        "plans",
        "billingChoice",
        "purchase"
      ],
      "edges": [
        [
          "saved",
          "limit"
        ],
        [
          "limit",
          "plans"
        ],
        [
          "plans",
          "billingChoice"
        ],
        [
          "billingChoice",
          "purchase"
        ]
      ]
    },
    {
      "title": "PayMongo checkout",
      "short": "Decision → methods → checkout → verification (blocked)",
      "nodes": [
        "plans",
        "billingChoice",
        "paymongoMethods",
        "paymongoCheckout",
        "paymongoVerify",
        "saved"
      ],
      "edges": [
        [
          "plans",
          "billingChoice"
        ],
        [
          "billingChoice",
          "paymongoMethods"
        ],
        [
          "paymongoMethods",
          "paymongoCheckout"
        ],
        [
          "paymongoCheckout",
          "paymongoVerify"
        ],
        [
          "paymongoVerify",
          "saved"
        ]
      ]
    },
    {
      "title": "Agent creates a listing",
      "short": "Login → agent → create → moderation",
      "nodes": [
        "auth",
        "agent",
        "create",
        "moderation"
      ],
      "edges": [
        [
          "auth",
          "agent"
        ],
        [
          "agent",
          "create"
        ],
        [
          "create",
          "moderation"
        ]
      ]
    },
    {
      "title": "Admin reviews content",
      "short": "Login → admin → moderation",
      "nodes": [
        "auth",
        "admin",
        "moderation"
      ],
      "edges": [
        [
          "auth",
          "admin"
        ],
        [
          "admin",
          "moderation"
        ]
      ]
    },
    {
      "title": "Returning user resumes",
      "short": "Splash → restored session → home",
      "nodes": [
        "splash",
        "home"
      ],
      "edges": [
        [
          "splash",
          "home"
        ]
      ]
    },
    {
      "title": "Guest hits a login gate",
      "short": "Details → gate → login",
      "nodes": [
        "details",
        "guestGate",
        "auth"
      ],
      "edges": [
        [
          "details",
          "guestGate"
        ],
        [
          "guestGate",
          "auth"
        ]
      ]
    },
    {
      "title": "Password recovery",
      "short": "Onboarding → login → recovery",
      "nodes": [
        "onboarding",
        "auth",
        "recovery"
      ],
      "edges": [
        [
          "onboarding",
          "auth"
        ],
        [
          "auth",
          "recovery"
        ]
      ]
    },
    {
      "title": "Buyer reports a listing",
      "short": "Details → report → report review → decision",
      "nodes": [
        "details",
        "report",
        "reportDetails",
        "moderationDecision"
      ],
      "edges": [
        [
          "details",
          "report"
        ],
        [
          "report",
          "reportDetails"
        ],
        [
          "reportDetails",
          "moderationDecision"
        ]
      ]
    },
    {
      "title": "Listing submission review",
      "short": "Create → queue → listing review → decision",
      "nodes": [
        "create",
        "moderation",
        "listingReview",
        "moderationDecision"
      ],
      "edges": [
        [
          "create",
          "moderation"
        ],
        [
          "moderation",
          "listingReview"
        ],
        [
          "listingReview",
          "moderationDecision"
        ]
      ]
    },
    {
      "title": "Moderation result",
      "short": "Decision → notify → manage",
      "nodes": [
        "moderationDecision",
        "moderationNotify",
        "manage"
      ],
      "edges": [
        [
          "moderationDecision",
          "moderationNotify"
        ],
        [
          "moderationNotify",
          "manage"
        ]
      ]
    },
    {
      "title": "Moderation audit",
      "short": "Decision → audit log → queue",
      "nodes": [
        "moderationDecision",
        "moderationAudit",
        "moderation"
      ],
      "edges": [
        [
          "moderationDecision",
          "moderationAudit"
        ],
        [
          "moderationAudit",
          "moderation"
        ]
      ]
    },
    {
      "title": "Sign out",
      "short": "Profile → sign out → onboarding",
      "nodes": [
        "profile",
        "signout",
        "onboarding"
      ],
      "edges": [
        [
          "profile",
          "signout"
        ],
        [
          "signout",
          "onboarding"
        ]
      ]
    },
    {
      "title": "Delete account",
      "short": "Profile → delete → onboarding",
      "nodes": [
        "profile",
        "deleteAcct",
        "onboarding"
      ],
      "edges": [
        [
          "profile",
          "deleteAcct"
        ],
        [
          "deleteAcct",
          "onboarding"
        ]
      ]
    }
  ],
  "statusLabels": {
    "complete": "Completed UI",
    "integration": "Needs integration",
    "guarded": "Guarded route",
    "planned": "Planned",
    "blocked": "Blocked"
  }
};
