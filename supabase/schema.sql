-- Tempo accounts: one row per user holding their liked songs and playlists.
-- Run this once in your Supabase project's SQL editor.
create table if not exists public.libraries (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.libraries enable row level security;

-- Each person can only read and write their own row.
drop policy if exists "read own library" on public.libraries;
create policy "read own library" on public.libraries
  for select using (auth.uid() = user_id);

drop policy if exists "insert own library" on public.libraries;
create policy "insert own library" on public.libraries
  for insert with check (auth.uid() = user_id);

drop policy if exists "update own library" on public.libraries;
create policy "update own library" on public.libraries
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
