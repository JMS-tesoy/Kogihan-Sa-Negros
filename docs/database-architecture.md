# Supabase Database Architecture

This document tracks the Supabase database structure, migration purpose, and schema history for this Flutter app.

## Current Migration Files

### 20260430000100_create_properties_table.sql

Purpose:

Creates the main property/listing database structure used by the real estate marketplace app.

Expected coverage:

- Property listings
- Property details
- Location data
- Price data
- Ownership/agent reference if included
- Listing timestamps

---

### 20260430000200_create_messaging_tables.sql

Purpose:

Creates the messaging-related tables for buyer, agent, and user communication.

Expected coverage:

- Conversations
- Messages
- Message participants
- Message timestamps
- User-to-user communication records

---

### 20260430000300_create_profile_avatars_storage.sql

Purpose:

Creates the Supabase Storage setup for user profile avatars.

Expected coverage:

- Avatar bucket setup
- Avatar access policy
- Upload/read rules
- User profile image storage

---

### 20260430000400_seed_negros_places.sql

Purpose:

Adds Negros place reference data used by the app for location filtering, search, maps, or dropdown selections.

Expected coverage:

- Cities
- Municipalities
- Barangay/place references if included
- Latitude/longitude data if included

---

## Database Change Rules

Any Supabase architecture change must be tracked through a migration file.

Track these changes:

- Tables
- Columns
- Indexes
- Foreign keys
- Row Level Security policies
- Storage policies
- Functions
- Triggers
- Views
- Enums
- Required reference data

Do not track:

- Real user data
- Passwords
- API keys
- Private tokens
- Temporary test records

---

## Workflow

When adding a new database change:

1. Create a new migration file inside `supabase/migrations/`.
2. Use a timestamped filename.
3. Write the SQL change.
4. Test carefully.
5. Commit the migration file to Git.

Example filename:

```text
20260501000100_create_chat_attachments_table.sql

