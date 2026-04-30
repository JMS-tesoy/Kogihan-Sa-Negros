You are working inside my Flutter + Supabase project.

Project context:
- This is a Flutter app using Supabase.
- Active branch: Clean-architecture-KSN
- Supabase migration history is already synced.
- Active migration folder: supabase/migrations/
- Old manual SQL backups are stored in supabase/manual_sql_backup/
- Do not modify old migrations.
- Do not modify files inside supabase/manual_sql_backup/.
- Do not run supabase db push.
- Do not run supabase migration repair.
- Do not run supabase db reset.

Goal:
Create a Supabase schema migration for this database change:

[DESCRIBE THE SUPABASE CHANGE HERE]

Examples of possible changes:
- Add a new table
- Add a new column
- Add RLS policies
- Add a storage policy
- Add a database function
- Add a trigger
- Add an index
- Add required reference data

Rules:
1. Create exactly one new timestamped SQL migration file inside:
   supabase/migrations/

2. The filename must follow this pattern:
   yyyymmddhhmmss_descriptive_name.sql

3. Use safe SQL where possible:
   - create table if not exists
   - alter table if exists
   - add column if not exists
   - create index if not exists
   - drop policy if exists before create policy when needed

4. Enable Row Level Security for new app tables:
   alter table public.table_name enable row level security;

5. Add RLS policies only when they are safe and clearly needed.

6. Do not create unsafe public write policies.

7. Do not change unrelated Flutter files yet.

8. Do not touch:
   - supabase/manual_sql_backup/
   - old migration files
   - .env
   - build/
   - .dart_tool/

9. After creating the migration, summarize:
   - The migration file created
   - The tables changed
   - The columns added/changed
   - The policies added/changed
   - Whether Flutter code needs to be updated next
   - The exact command I should run next

Expected next command for me:
supabase db push --dry-run

Important:
Only create the migration file. Do not apply it to Supabase.