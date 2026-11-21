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
      "y": 316,
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
      "y": 428,
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
      "y": 540,
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
      "y": 652,
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
      "y": 92,
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
      "y": 204,
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
      "y": 764,
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
      "title": "Moderation",
      "x": 1572,
      "y": 204,
      "role": "admin",
      "lane": "admin",
      "status": "guarded",
      "icon": "RV",
      "route": "/moderation",
      "description": "Admin-role-protected review queue for submitted or reported property content.",
      "actions": [
        "Approve or reject listing",
        "Request changes",
        "Return to admin dashboard"
      ],
      "note": "Test duplicate review, audit history, reason requirements, and author notification.",
      "source": "lib/features/admin/presentation"
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
      "purchase",
      "choose plan",
      "straight"
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
      "purchase",
      "paymongoMethods",
      "not connected",
      "blocked"
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
      "not verified",
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
      "short": "Limit → plans → purchase",
      "nodes": [
        "saved",
        "limit",
        "plans",
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
          "purchase"
        ]
      ]
    },
    {
      "title": "PayMongo checkout",
      "short": "Purchase → methods → checkout → verification (blocked)",
      "nodes": [
        "plans",
        "purchase",
        "paymongoMethods",
        "paymongoCheckout",
        "paymongoVerify",
        "saved"
      ],
      "edges": [
        [
          "plans",
          "purchase"
        ],
        [
          "purchase",
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
