# Development Timeline

This file tracks planned improvements that should be implemented later.

## Later: App Preload and Cache Improvements

Goal:

Improve app speed and offline resilience without changing the current UI.

Planned items:

- Add persistent offline cache for property list data.
- Add preload coverage for more important screens, not only startup/home flows.
- Add a fuller image predownload strategy beyond the current targeted image
  precache/warmup.

Notes:

- Current preload/precache already exists for properties, places, property
  images, avatars, and messaging cache.
- Implement later only if real app testing shows slow loading or offline needs.
- Keep the future implementation small and avoid heavy startup work.

## Later: Offline Messaging and Chat Cache

Goal:

Allow users to reopen recent conversations and messages even with weak or no
internet connection.

Planned items:

- Add persistent local cache for conversation summaries.
- Add persistent local cache for recent messages per conversation.
- Show cached messages first, then refresh from Supabase when online.
- Add clear offline/error state for failed refreshes.
- Consider an offline send queue later, but only after read-only offline cache
  works reliably.

Notes:

- Current messaging cache is memory-only.
- Do not cache sensitive data longer than needed.
- Keep attachment caching separate from message text caching.

## Later: Security and Reliability Review

Goal:

Improve database safety, app reliability, and long-term maintainability after
the current core flows are stable.

Planned items:

- Review RLS admin checks and replace unsafe `user_metadata` authorization
  checks with safer `app_metadata` or profile-role checks.
- Run Supabase database advisors and document warnings before adding more SQL
  changes.
- Review notification reliability, duplicate prevention, and read/unread sync.
- Add attachment cleanup so deleted chat attachments are also removed from
  storage safely.

Notes:

- Do this carefully because it touches security-sensitive behavior.
- Prefer one small migration or fix at a time.

## Later: Large List and Search Performance

Goal:

Keep the app responsive as property, user, notification, and message data grows.

Planned items:

- Confirm all large lists use pagination, including properties, messages,
  notifications, admin users, and team requests.
- If search moves to the database later, add proper database-side search indexes
  instead of relying only on Flutter-side filtering.
- Add friendly weak-internet states: show cached data, offer retry, and avoid
  blank screens.

Notes:

- Prioritize real slow screens first.
- Avoid adding extra indexes until a matching query pattern is confirmed.
