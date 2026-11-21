# Kogihan sa Negros user flow

This is the editable source for `mockups/app_user_flow/index.html`.

## Update the flow

1. Add or edit a node and arrow below.
2. Run **Tasks: Run Task → Update app user-flow preview**.
3. Refresh the browser.

Preview this file on GitHub or in VS Code with `Ctrl+Shift+V`.

```mermaid
flowchart LR
    splash["Splash / Bootstrap"]:::complete
    onboarding["Guest onboarding"]:::complete
    auth["Login / Register"]:::complete
    recovery["Password recovery"]:::integration

    home["Buyer Home"]:::complete
    map["Map"]:::integration
    saved["Saved"]:::integration
    inbox["Inbox"]:::integration
    profile["Profile"]:::integration

    search["Search & Filter"]:::complete
    details["Property Details"]:::complete
    gallery["Gallery"]:::complete
    contact["Contact Agent"]:::integration
    chat["Buyer Chat"]:::integration

    limit["Saved Limit"]:::integration
    plans["Subscription Plans"]:::integration
    purchase["Purchase / Verify"]:::integration
    restore["Restore / Manage"]:::integration
    paymongoMethods["PayMongo Methods"]:::blocked
    paymongoCheckout["PayMongo Checkout"]:::blocked
    paymongoVerify["Order / Webhook Verify"]:::blocked

    agent["Agent Dashboard"]:::guarded
    create["Create Listing"]:::guarded
    manage["Manage Listings"]:::guarded
    agentInbox["Buyer Inbox"]:::guarded
    teams["Teams"]:::guarded

    guestGate["Login Required Gate"]:::planned
    signout["Sign Out"]:::planned
    deleteAcct["Delete Account"]:::planned
    report["Report Listing"]:::planned
    billingChoice["Billing Route Decision"]:::planned

    admin["Admin Dashboard"]:::guarded
    moderation["Moderation Queue"]:::guarded
    listingReview["Listing Review"]:::guarded
    reportDetails["Report Details"]:::guarded
    moderationDecision["Decision & Reason"]:::guarded
    moderationNotify["Notify Agent / Reporter"]:::integration
    moderationAudit["Moderation Audit Log"]:::guarded

    splash -->|"first run"| onboarding
    splash -->|"session restored"| home
    splash -->|"agent session"| agent
    splash -->|"admin session"| admin
    onboarding -->|"sign in"| auth
    auth -->|"forgot"| recovery
    recovery -->|"back to login"| auth
    onboarding -->|"continue guest"| home
    auth -->|"buyer"| home
    home -->|"tab"| map
    home -->|"tab"| saved
    home -->|"tab"| inbox
    home -->|"tab"| profile
    home -->|"discover"| search
    search -->|"select"| details
    map -->|"marker"| details
    saved -->|"open"| details
    details -->|"save"| saved
    details -->|"media"| gallery
    details -->|"inquire"| contact
    details -->|"at limit"| limit
    details -->|"guest action"| guestGate
    guestGate -->|"sign in"| auth
    auth -->|"resume action"| details
    details -->|"report"| report
    report -->|"submitted"| reportDetails
    contact -->|"thread"| chat
    inbox -->|"open"| chat
    saved -->|"at limit"| limit
    limit -->|"upgrade"| plans
    plans -->|"choose plan"| billingChoice
    billingChoice -->|"store billing"| purchase
    billingChoice -->|"PayMongo"| paymongoMethods
    plans -->|"existing buyer"| restore
    purchase -->|"unlocked"| saved
    restore -->|"restored"| profile
    profile -->|"manage plan"| plans
    profile -->|"sign out"| signout
    signout -->|"signed out"| onboarding
    profile -->|"delete"| deleteAcct
    deleteAcct -->|"confirmed"| onboarding
    purchase -->|"failed / cancelled"| plans
    paymongoMethods -->|"not connected"| paymongoCheckout
    paymongoCheckout -->|"not connected"| paymongoVerify
    paymongoVerify -->|"verified"| saved
    paymongoVerify -->|"failed / pending"| plans
    auth -->|"agent"| agent
    auth -->|"admin"| admin
    agent -->|"new"| create
    agent -->|"manage"| manage
    agent -->|"messages"| agentInbox
    agentInbox -->|"open"| chat
    agent -->|"team"| teams
    create -->|"submit"| moderation
    admin -->|"review"| moderation
    moderation -->|"open submission"| listingReview
    moderation -->|"open report"| reportDetails
    listingReview -->|"inspect evidence"| moderationDecision
    reportDetails -->|"review report"| moderationDecision
    moderationDecision -->|"approve / reject"| moderationNotify
    moderationDecision -->|"changes required"| manage
    moderationDecision -->|"record"| moderationAudit
    moderationAudit -->|"back to queue"| moderation
    moderationNotify -->|"status update"| manage
    moderationNotify -->|"report resolved"| reportDetails

    classDef complete fill:#123d31,stroke:#6ee7b7,color:#fff
    classDef integration fill:#4d391c,stroke:#f5b85c,color:#fff
    classDef guarded fill:#292e52,stroke:#9ca8ff,color:#fff
    classDef blocked fill:#45201e,stroke:#ef8d72,color:#fff
    classDef planned fill:#1b2228,stroke:#8e9ca5,color:#c7d0d5,stroke-dasharray:4 3
```

## Interactive preview details

The lines below are Mermaid-safe metadata comments. Copy an `@node` line
when adding a screen. Use the same ID as the Mermaid node. Separate multiple
actions with semicolons.

<!--
@node splash | lane=entry | slot=0 | role=entry | status=complete | icon=KB | route=/ | description=Initializes app state, restores the session, and selects the correct entry route. | actions=Resolve role and auth state;Route to onboarding or a workspace;Fallback unknown routes here | note=Verify cold start, deep link, stale-session, and offline behavior. | source=lib/app/bootstrap and route redirect
@node onboarding | lane=entry | slot=1 | role=entry | status=complete | icon=GO | route=/onboarding | description=Introduces the marketplace and lets a guest begin without an account. | actions=Continue to guest buyer view;Open login or registration | note=Confirm copy, permissions, skip behavior, and returning-user state. | source=lib/features/onboarding/presentation
@node auth | lane=entry | slot=2 | role=entry | status=complete | icon=ID | route=/login /register | description=Email authentication branch for buyer, agent, and administrator accounts. | actions=Choose login or create account;Recover a password;Resolve role-aware destination | note=Test invalid credentials, duplicate accounts, confirmation, and expired sessions. | source=lib/features/auth/presentation
@node recovery | lane=entry | slot=3 | role=entry | status=integration | icon=PW | route=/forgot-password | description=Requests an account recovery email and guides the user back to sign-in. | actions=Submit account email;Open reset link;Return to login | note=Verify email delivery, callback/deep-link setup, and reset expiration. | source=lib/features/auth/presentation

@node home | lane=shell | slot=0 | role=buyer | status=complete | icon=H | route=/home (Home tab) | description=Primary buyer-shell tab with featured properties, recent discovery, and entry points into search. | actions=Search and filter properties;Switch to Map, Saved, Inbox, or Profile | note=Check startup data, empty feed, pagination, and navigation-bar persistence. | source=lib/features/home/presentation
@node map | lane=shell | slot=1 | role=buyer | status=integration | icon=M | route=/home Map tab /map | description=Map-led property discovery shown as a buyer-shell tab. /map is also a direct route. | actions=Pan and inspect markers;Open property details | note=Test Mapbox token, network loss, permissions, marker density, and camera restoration. | source=lib/features/map/presentation
@node saved | lane=shell | slot=2 | role=buyer | status=integration | icon=♥ | route=/home Saved tab /favorites | description=Favorite-property screen shown as a buyer-shell tab. /favorites is also a direct route. | actions=Open a saved property;Remove favorite;Upgrade at limit | note=Validate backend sync, optimistic updates, guest restrictions, and limit messaging. | source=lib/features/favorites/presentation
@node inbox | lane=shell | slot=3 | role=buyer | status=integration | icon=IN | route=/home Inbox tab /inbox | description=Buyer conversation index shown as a tab. /inbox is also a direct named route. | actions=Open a conversation;Message the listing agent | note=Verify real-time delivery, unread counts, push notifications, and reconnect behavior. | source=lib/features/messaging/presentation
@node profile | lane=shell | slot=4 | role=buyer | status=integration | icon=P | route=/home Profile tab /profile | description=Account screen shown as a tab. /profile and /edit-profile are direct routes. | actions=Edit profile information;Manage subscription;Sign out | note=Check profile persistence, avatar upload, and authenticated account state. | source=lib/features/profile/presentation

@node search | lane=journey | slot=0 | role=buyer | status=complete | icon=⌕ | route=/search /property-search /property-filter | description=Searchable property inventory with registered search and filter screens. | actions=Apply filters;Open matching property;Reset search criteria | note=Exercise keyboard, empty results, clear/reset, and filter restoration. | source=lib/features/search and lib/features/properties/presentation
@node details | lane=journey | slot=1 | role=buyer | status=complete | icon=PD | route=/property-details + args | description=Focused listing view with land facts, media, asking price, location, and agent identity. | actions=View gallery;Save property;Contact the agent | note=Verify required PropertyDetailsArgs, stale inventory, long copy, and unavailable media. | source=lib/features/properties/presentation
@node gallery | lane=journey | slot=2 | role=buyer | status=complete | icon=▧ | route=/property-gallery + args | description=Full-screen media viewer opened with required PropertyGalleryArgs. | actions=Swipe through images;Return to details | note=Confirm caching, zoom, image failures, and swipe direction on actual devices. | source=lib/features/properties/presentation
@node contact | lane=journey | slot=3 | role=buyer | status=integration | icon=CA | route=/inquiries (internal inquiry action) | description=Inquiry screen plus inquiry creation from the property flow. | actions=Compose inquiry;Open buyer chat | note=Validate guest-to-login redirect, message creation, ownership, and offline submission. | source=lib/features/inquiries/presentation
@node chat | lane=journey | slot=4 | role=buyer | status=integration | icon=CH | route=/chat + ChatScreenArgs | description=One-to-one buyer and agent conversation with conversation context passed as arguments. | actions=Send and receive messages;Return to buyer inbox | note=Check delivery state, timestamps, long threads, attachment scope, and push deep links. | source=lib/features/messaging/presentation

@node limit | lane=upgrade | slot=0 | role=buyer | status=integration | icon=! | route=Internal entitlement gate (no route) | description=A conceptual gate within the saved-property and subscription experience. | actions=Review limit;View plans;Restore purchases | note=Verify entitlements, guest behavior, server truth, and no-billing bypass paths. | source=lib/features/subscription/presentation
@node plans | lane=upgrade | slot=1 | role=buyer | status=integration | icon=$ | route=/subscription /plans | description=Registered subscription and plans screens for store-managed purchase options. | actions=Select plan;Start purchase;Restore prior purchase | note=Test store availability, localized pricing, rejected products, and slow network responses. | source=lib/features/subscription/presentation
@node purchase | lane=upgrade | slot=3 | role=buyer | status=integration | icon=$✓ | route=In-screen step (native store) | description=Purchase controls and verification inside the subscription flow. | actions=Complete native purchase;Verify receipt;Unlock saved capacity | note=Use sandbox products and verify cancellation, duplicate receipts, refunds, and retry. | source=lib/features/subscription/data/services
@node restore | lane=upgrade | slot=4 | role=buyer | status=integration | icon=↺ | route=In-screen actions (no route) | description=Restore and store-management actions belonging to the subscription UI. | actions=Restore purchases;Open store management;Re-check entitlement | note=Confirm same-account restoration and behavior when the store has no transactions. | source=lib/features/subscription/presentation
@node paymongoMethods | lane=upgrade | slot=5 | role=buyer | status=blocked | icon=PM | route=Internal provider (Supabase function) | description=Loads available PayMongo methods through the get_billing_availability edge function. This branch is implemented but not verified as connected or deployed. | actions=Load enabled methods;Handle unavailable or disabled checkout | note=Verify the deployed function, authentication, secret configuration, and enabled-method flags. | source=lib/features/subscription/data/services/paymongo_billing_provider.dart
@node paymongoCheckout | lane=upgrade | slot=6 | role=buyer | status=blocked | icon=P$ | route=External PayMongo checkout (no app route) | description=Creates a billing checkout through Supabase and opens the PayMongo URL outside the app. | actions=Create checkout session;Open external browser;Return to app | note=Verify create_billing_checkout deployment, amount mapping, deep return, cancellations, and real sandbox payment. | source=lib/features/subscription/presentation/screens/purchase_flow_screen.dart
@node paymongoVerify | lane=upgrade | slot=7 | role=buyer | status=blocked | icon=✓? | route=Edge functions / webhook (no app route) | description=Polls billing order state and relies on webhook verification to update entitlement. End-to-end connection is not yet verified. | actions=Poll billing order;Receive webhook;Confirm entitlement | note=Verify get_billing_order, paymongo_webhook, signature validation, idempotency, and entitlement update. | source=supabase/functions and lib/features/subscription/data/services/paymongo_billing_provider.dart

@node agent | lane=agent | slot=0 | role=agent | status=guarded | icon=AD | route=/agent-dashboard | description=Agent-role-protected overview with listing, message, and team shortcuts. | actions=Create or manage listing;Open buyer inbox;Open teams | note=Test role guard, account switching, suspended agent state, and session expiry. | source=lib/features/agent/presentation
@node create | lane=agent | slot=1 | role=agent | status=guarded | icon=+L | route=/create-listing | description=Role-protected listing authoring flow for land details, pricing, and media. | actions=Draft listing;Upload media;Submit for moderation | note=Validate draft recovery, upload limits, required fields, and permission errors. | source=lib/features/agent/presentation
@node manage | lane=agent | slot=2 | role=agent | status=guarded | icon=ML | route=/manage-listings /edit-listing | description=Role-protected screens for owned listings and editing an existing property. | actions=Edit listing;Review moderation status;Pause or publish | note=Check ownership isolation, stale records, empty state, and destructive confirmations. | source=lib/features/agent/presentation
@node agentInbox | lane=agent | slot=3 | role=agent | status=guarded | icon=BI | route=/inbox /chat + args | description=Registered inbox and chat routes opened from the role-protected agent workspace. | actions=Open buyer conversation;Reply and mark read | note=Verify real-time updates, unread counts, role authorization, and push deep links. | source=lib/features/messaging/presentation
@node teams | lane=agent | slot=4 | role=agent | status=guarded | icon=TM | route=/agent-teams | description=Authenticated agent-team workspace. | actions=Review team access;Open team-specific tools | note=Validate membership changes, invitation state, and cross-team data boundaries. | source=lib/features/agent_teams/presentation

@node guestGate | lane=entry | slot=4 | role=buyer | status=planned | icon=LG | route=Internal gate (no route) | description=Stops a guest who tries a protected action (save, inquire, subscribe), sends them to login, then resumes the original action. | actions=Explain why login is needed;Open login or registration;Resume the interrupted action | note=Verify the intended action survives login, registration, and password recovery. | source=lib/features/auth/presentation (to be added)
@node signout | lane=shell | slot=5 | role=buyer | status=planned | icon=SO | route=Profile action (no route) | description=Ends the session, clears cached account state, and returns the user to onboarding. | actions=Confirm sign out;Clear local session and push token;Return to onboarding | note=Check agent and admin sign-out, token cleanup, and back-button behavior after logout. | source=lib/features/profile/presentation (to be added)
@node deleteAcct | lane=shell | slot=6 | role=buyer | status=planned | icon=DA | route=/delete-account (planned) | description=In-app account deletion, expected by Apple and Google for apps that allow account creation. | actions=Confirm identity;Delete account and personal data;Return to onboarding | note=Decide what happens to an agent's listings, chats, and active subscription when the account is deleted. | source=lib/features/profile/presentation and a Supabase edge function (to be added)
@node report | lane=journey | slot=5 | role=buyer | status=planned | icon=RP | route=Property details action (planned) | description=Lets a buyer report a listing, feeding the admin moderation queue that already handles reported content. | actions=Pick a reason;Submit report;Show confirmation | note=Prevent duplicate reports and confirm the report appears in the moderation queue with context. | source=lib/features/properties/presentation (to be added)
@node billingChoice | lane=upgrade | slot=2 | role=buyer | status=planned | icon=BR | route=Internal decision (no route) | description=Decides whether a purchase uses native store billing or PayMongo, so the two paths never overlap for the same unlock. | actions=Select store billing by platform;Offer PayMongo only where allowed;Fall back with a clear message | note=Check Apple and Google billing policy for digital unlocks before enabling PayMongo in the mobile app. | source=lib/features/subscription/data/services

@node admin | lane=admin | slot=0 | role=admin | status=guarded | icon=AU | route=/admin-dashboard | description=Admin-only control surface for platform review and moderation activity. | actions=Open moderation queue;Inspect platform content | note=Enforce admin guard server-side and confirm non-admin deep-link denial. | source=lib/features/admin/presentation
@node moderation | lane=admin | slot=1 | role=admin | status=guarded | icon=MQ | route=/moderation | description=Admin-only queue for listing submissions, edits awaiting review, buyer reports, and previously rejected content. | actions=Filter pending cases;Open a listing review;Open a buyer report | note=Verify queue counts, permissions, stale cases, and priority ordering. | source=lib/features/admin/presentation
@node listingReview | lane=admin | slot=2 | role=admin | status=guarded | icon=LR | route=Moderation detail state (admin only) | description=Review workspace for the submitted listing, property images, agent identity, and edit history. | actions=Inspect listing content;Compare previous version;Open decision panel | note=Confirm the original submission is preserved and unavailable images do not block review. | source=lib/features/admin/presentation
@node reportDetails | lane=admin | slot=3 | role=admin | status=guarded | icon=RD | route=Moderation report detail (admin only) | description=Displays the buyer report reason, evidence, duplicate reports, listing context, and resolution state. | actions=Inspect report evidence;Open reported listing;Continue to decision | note=Prevent duplicate reports from creating duplicate cases and protect reporter identity appropriately. | source=lib/features/admin/presentation
@node moderationDecision | lane=admin | slot=4 | role=admin | status=guarded | icon=MD | route=Moderation action panel (admin only) | description=Captures the admin decision and required reason for approval, rejection, requested changes, temporary hiding, or escalation. | actions=Approve or publish;Reject with reason;Request changes;Hide or escalate | note=Require a reason for adverse actions and keep decisions idempotent when requests are retried. | source=lib/features/admin/presentation
@node moderationNotify | lane=admin | slot=5 | role=admin | status=integration | icon=NT | route=Backend notifications (no app route) | description=Sends the decision to the agent and resolves the buyer report when applicable. | actions=Notify listing agent;Notify reporter;Refresh listing status | note=Verify delivery, retries, notification preferences, and no sensitive report details are exposed. | source=lib/features/notifications and Supabase integration
@node moderationAudit | lane=admin | slot=6 | role=admin | status=guarded | icon=AL | route=Moderation review audit section | description=Immutable history of reviewer, previous status, decision, reason, and timestamp displayed inside the admin review screen. | actions=Inspect review history;Return to the queue | note=The UI is connected to the audit table; audit visibility and writes are protected by database RLS and the admin-only RPC. | source=lib/features/admin/presentation and Supabase backend

@journey | title=Guest discovers a property | short=Guest → home → search → details | nodes=splash,onboarding,home,search,details
@journey | title=Buyer saves a property | short=Details → saved → optional limit | nodes=home,search,details,saved,limit
@journey | title=Buyer messages an agent | short=Listing → inquiry → chat | nodes=home,search,details,contact,chat
@journey | title=Buyer upgrades | short=Limit → plans → decision → purchase | nodes=saved,limit,plans,billingChoice,purchase
@journey | title=PayMongo checkout | short=Decision → methods → checkout → verification (blocked) | nodes=plans,billingChoice,paymongoMethods,paymongoCheckout,paymongoVerify,saved
@journey | title=Agent creates a listing | short=Login → agent → create → moderation | nodes=auth,agent,create,moderation
@journey | title=Admin reviews content | short=Login → admin → moderation | nodes=auth,admin,moderation
@journey | title=Returning user resumes | short=Splash → restored session → home | nodes=splash,home
@journey | title=Guest hits a login gate | short=Details → gate → login | nodes=details,guestGate,auth
@journey | title=Password recovery | short=Onboarding → login → recovery | nodes=onboarding,auth,recovery
@journey | title=Buyer reports a listing | short=Details → report → report review → decision | nodes=details,report,reportDetails,moderationDecision
@journey | title=Listing submission review | short=Create → queue → listing review → decision | nodes=create,moderation,listingReview,moderationDecision
@journey | title=Moderation result | short=Decision → notify → manage | nodes=moderationDecision,moderationNotify,manage
@journey | title=Moderation audit | short=Decision → audit log → queue | nodes=moderationDecision,moderationAudit,moderation
@journey | title=Sign out | short=Profile → sign out → onboarding | nodes=profile,signout,onboarding
@journey | title=Delete account | short=Profile → delete → onboarding | nodes=profile,deleteAcct,onboarding
-->

## Status and role values

- Status: `complete`, `integration`, `guarded`, `planned`, or `blocked` (`planned` = on the map but not built yet)
- Role: `entry`, `buyer`, `agent`, or `admin`
- Lane: `entry`, `shell`, `journey`, `upgrade`, `agent`, or `admin`

## Command-line update

```powershell
dart run tool\update_user_flow.dart
```
