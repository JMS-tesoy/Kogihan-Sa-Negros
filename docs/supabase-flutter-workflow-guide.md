# Supabase + Flutter Workflow Guide

This guide explains the correct workflow for making Flutter code changes and Supabase schema/database changes safely in this project.

Current working branch:

```text
Clean-architecture-KSN
```

---

# Current Project Status

This project already has:

```text
✅ Git branch cleaned
✅ main and Clean-architecture-KSN aligned before
✅ Supabase project linked locally
✅ Supabase migration history synced
✅ Old manual SQL files moved to supabase/manual_sql_backup/
✅ supabase/.temp/ ignored in .gitignore
✅ Active Supabase migration folder clean
```

Current active migration baseline:

```text
supabase/migrations/20260430053551_initial_remote_schema.sql
```

Important:

```text
Do not edit old migration files.
Do not modify files inside supabase/manual_sql_backup/.
Do not run supabase db push without running supabase db push --dry-run first.
```

---

# Workflow A: Flutter Code Changes Only

Use this workflow when Codex changes only Flutter/Dart files.

Examples:

- UI changes
- Widget layout changes
- Navigation changes
- Styling changes
- Text or label changes
- Bug fixes that do not need database changes
- Refactoring Flutter files only
- Updating screens, cards, dialogs, themes, or app state logic

Do not use this workflow if you are adding Supabase tables, columns, policies, buckets, triggers, functions, enums, or indexes.

---

## Step 1: Check your branch

Run:

```powershell
git branch
```

Make sure you are on:

```text
Clean-architecture-KSN
```

If not, switch to it:

```powershell
git switch Clean-architecture-KSN
```

---

## Step 2: Make sure your working tree is clean

Run:

```powershell
git status
```

Good result:

```text
nothing to commit, working tree clean
```

If there are unfinished changes, commit them first or decide what to do before asking Codex to edit more files.

---

## Step 3: Ask Codex to change Flutter code only

Use this prompt:

```text
You are working inside my Flutter project.

Goal:
[DESCRIBE THE FLUTTER CHANGE HERE]

Rules:
- Do not touch Supabase migrations.
- Do not create or modify SQL files.
- Do not change database schema.
- Do not modify files inside supabase/manual_sql_backup/.
- Make the smallest safe Flutter code changes only.
- Keep widgets extracted into separate widget classes where possible.
- Do not create widgets inside methods unless absolutely necessary.
- Preserve the existing project structure.
- After changes, summarize the files changed and what each file does.
```

Example:

```text
Improve the property card UI only.

Rules:
- Do not touch Supabase migrations.
- Do not create or modify SQL files.
- Do not change database schema.
- Make the smallest safe Flutter code changes only.
```

---

## Step 4: Check what Codex changed

Run:

```powershell
git status
```

Expected changes are usually inside:

```text
lib/
```

Possible additional changed files:

```text
pubspec.yaml
pubspec.lock
assets/
```

Only accept `pubspec.yaml` changes if Codex intentionally added a package.

Be careful if you see changes inside:

```text
supabase/
```

For Workflow A, Codex should not touch Supabase files.

---

## Step 5: Test the app

Run:

```powershell
flutter run
```

Test the exact screen or feature Codex changed.

Examples:

```text
Open the changed screen
Tap buttons
Navigate back and forward
Check if layout overflows
Check if data still loads
Check if no red error screen appears
```

---

## Step 6: Commit and push

Run:

```powershell
git add .
git commit -m "describe Flutter change"
git push origin Clean-architecture-KSN
```

Example:

```powershell
git add .
git commit -m "improve property card UI"
git push origin Clean-architecture-KSN
```

---

# Workflow B: Supabase Schema / Database Changes

Use this workflow when the app needs a database architecture change.

Examples:

- Add table
- Add column
- Add index
- Add foreign key
- Add RLS policy
- Add storage bucket policy
- Add trigger
- Add function
- Add enum
- Add required reference data
- Add relationship between tables
- Modify Supabase Storage rules

---

## Step 1: Start clean

Run:

```powershell
git status
```

Good result:

```text
nothing to commit, working tree clean
```

If there are unfinished Flutter changes, commit them first before touching Supabase schema.

---

## Step 2: Ask Codex to create a migration

Use this prompt:

```text
You are working inside my Flutter + Supabase project.

Goal:
Create a Supabase schema migration for the following change:

[DESCRIBE THE DATABASE CHANGE HERE]

Rules:
- Do not modify old migration files.
- Do not modify files inside supabase/manual_sql_backup/.
- Create exactly one new timestamped SQL migration file inside supabase/migrations/.
- Use safe SQL with IF NOT EXISTS where possible.
- Enable RLS when creating new app tables.
- Add safe policies only when needed.
- Do not run supabase db push.
- Do not edit Flutter UI yet unless I specifically ask.
- Do not modify unrelated Flutter files.
- After creating the migration, summarize:
  1. The migration file created
  2. The tables/columns/policies/functions changed
  3. The command I should run next
```

Example database change:

```text
Create a table called public.property_images for property listing photos.

Requirements:
- id uuid primary key default gen_random_uuid()
- property_id uuid not null references public.properties(id) on delete cascade
- image_url text not null
- sort_order integer not null default 0
- is_primary boolean not null default false
- created_at timestamptz not null default now()
- Enable row level security
- Add safe read policy if property listings are public
```

Codex should create a new file like:

```text
supabase/migrations/20260430124500_create_property_images_table.sql
```

---

## Step 3: Check what Codex changed

Run:

```powershell
git status
```

Expected result:

```text
new file: supabase/migrations/xxxxxxxxxxxxxx_your_change_name.sql
```

Make sure Codex did not modify old migration files.

Do not modify this folder:

```text
supabase/manual_sql_backup/
```

Also check the migration folder:

```powershell
Get-ChildItem supabase\migrations
```

---

## Step 4: Review the migration file

Open the new migration file in VS Code.

Check for dangerous SQL.

Usually safe:

```sql
create table if not exists
alter table if exists
add column if not exists
create index if not exists
alter table enable row level security
```

Be careful with:

```sql
drop table
drop column
delete from
truncate
alter column type
rename column
disable row level security
```

If Codex created risky SQL, stop and ask Codex to rewrite it safely.

---

## Step 5: Preview Supabase push

Always run dry-run first:

```powershell
supabase db push --dry-run
```

Safe result should show only the new migration.

Stop if you see:

```text
unexpected old migrations
duplicate table errors
dangerous changes
migration history mismatch
remote migration versions not found
```

If dry-run looks wrong, do not run real push.

---

## Step 6: Push schema change to Supabase

Only after dry-run looks safe, run:

```powershell
supabase db push
```

This applies the new migration to the linked Supabase project.

---

## Step 7: Update Flutter code

After the schema exists in Supabase, ask Codex to update Flutter code.

Use this prompt:

```text
Now update the Flutter app to use the new Supabase schema.

Rules:
- Use the new table/column from the latest migration.
- Do not create another migration.
- Do not modify old migration files.
- Do not modify files inside supabase/manual_sql_backup/.
- Make the smallest safe Flutter code changes only.
- Keep widgets extracted into separate widget classes where possible.
- Do not create widgets inside methods unless absolutely necessary.
- Preserve existing app structure and naming conventions.
- After changes, summarize the files changed and how to test the feature.
```

---

## Step 8: Test the app

Run:

```powershell
flutter run
```

Test the affected feature.

Examples:

```text
Create record
Edit record
Delete record
Load list
Open detail screen
Upload file if storage was changed
Check Supabase table data
Check RLS behavior if authentication is involved
```

---

## Step 9: Commit schema and Flutter code together

Run:

```powershell
git status
git add .
git commit -m "describe schema feature"
git push origin Clean-architecture-KSN
```

Example:

```powershell
git add .
git commit -m "add property images feature"
git push origin Clean-architecture-KSN
```

---

# Golden Rule for Supabase Changes

Use this order:

```text
1. git status
2. Codex creates migration
3. git status
4. review new migration file
5. supabase db push --dry-run
6. supabase db push
7. Codex updates Flutter code
8. flutter run
9. git add .
10. git commit
11. git push
```

---

# Dashboard Change Rule

Avoid changing Supabase Dashboard manually when possible.

But if you manually change Supabase Dashboard, the change is not complete until it is captured in Git.

Use:

```powershell
supabase db pull dashboard_change_name
git add supabase
git commit -m "capture Supabase dashboard schema change"
git push origin Clean-architecture-KSN
```

Example:

```powershell
supabase db pull add_property_images_from_dashboard
git add supabase
git commit -m "capture property images dashboard schema"
git push origin Clean-architecture-KSN
```

---

# Commands to Memorize

```powershell
git status
git branch
supabase migration list
supabase db push --dry-run
supabase db push
git add .
git commit -m "message here"
git push origin Clean-architecture-KSN
```

---

# Commands to Be Careful With

Do not run these casually:

```powershell
supabase db reset
supabase migration repair
supabase db push
```

Only run:

```powershell
supabase db push
```

after:

```powershell
supabase db push --dry-run
```

shows a safe result.

---

# When to Use Workflow A

Use Workflow A when the change is only app code.

Examples:

```text
Change card design
Fix button layout
Improve navigation
Fix Flutter bug
Refactor widgets
Update text labels
Improve theme
Add UI validation only
```

Command flow:

```powershell
git status
# Codex edits Flutter files
git status
flutter run
git add .
git commit -m "describe Flutter change"
git push origin Clean-architecture-KSN
```

---

# When to Use Workflow B

Use Workflow B when the change needs Supabase structure.

Examples:

```text
New table
New column
New relationship
New policy
New storage bucket
New storage policy
New trigger
New function
New required reference data
```

Command flow:

```powershell
git status
# Codex creates migration
git status
supabase db push --dry-run
supabase db push
# Codex updates Flutter files
flutter run
git add .
git commit -m "describe schema feature"
git push origin Clean-architecture-KSN
```

---

# Beginner Safety Checklist Before Pushing Supabase

Before running:

```powershell
supabase db push
```

Make sure:

```text
✅ I am in the correct folder
✅ I am on Clean-architecture-KSN
✅ git status does not show random unrelated changes
✅ Codex created only one new migration file
✅ Old migrations were not modified
✅ supabase/manual_sql_backup/ was not modified
✅ supabase db push --dry-run looked safe
```

Check current folder:

```powershell
pwd
```

Expected folder:

```text
D:\Documents\Website Project\flutter_application_1
```

Check branch:

```powershell
git branch
```

Expected branch:

```text
Clean-architecture-KSN
```

---

# If Something Looks Wrong

If dry-run shows unexpected migration problems, stop.

Do not run:

```powershell
supabase db push
```

Instead, check:

```powershell
git status
supabase migration list
```

Then review what changed.

---

# Final Rule

For this project:

```text
Codex writes the migration.
I review the migration.
I dry-run first.
I push Supabase only when safe.
I test Flutter.
I commit everything to Git.
```