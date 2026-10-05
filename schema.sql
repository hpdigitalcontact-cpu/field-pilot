-- Field Pilot — database schema
-- Paste this whole file in Supabase → SQL Editor → New query → Run.
-- Every table is private to the account that created the row (Row Level Security).

create table if not exists companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade unique,
  name text not null default 'My company',
  team_size text,
  plan text not null default 'solo_free',
  created_at timestamptz not null default now()
);

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  address text,
  city text,
  zip text,
  service text,            -- lawn | landscaping | full
  frequency text,          -- weekly | biweekly | monthly
  price_per_visit numeric(10,2) default 0,
  gate_code text,
  dog_name text,
  access_notes text,
  crew text,
  created_at timestamptz not null default now()
);

create table if not exists visits (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  scheduled_on date not null,
  crew text,
  status text not null default 'planned',   -- planned | done | delayed
  duration_min int,
  photos int default 0,
  created_at timestamptz not null default now()
);

create table if not exists quotes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  customer_name text not null,
  detail text,
  total numeric(10,2) not null default 0,
  status text not null default 'draft',      -- draft | sent | signed
  created_at timestamptz not null default now()
);

create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  customer_name text not null,
  detail text,
  total numeric(10,2) not null default 0,
  status text not null default 'ready',      -- ready | unpaid | paid
  due_on date,
  created_at timestamptz not null default now()
);

alter table companies enable row level security;
alter table customers enable row level security;
alter table visits    enable row level security;
alter table quotes    enable row level security;
alter table invoices  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['companies','customers','visits','quotes','invoices'] loop
    execute format('drop policy if exists "own rows" on %I', t);
    execute format('create policy "own rows" on %I for all using (owner_id = auth.uid()) with check (owner_id = auth.uid())', t);
  end loop;
end $$;

-- create the company row automatically when someone signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.companies (owner_id, name, team_size)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'company', 'My company'),
    new.raw_user_meta_data->>'team_size'
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
