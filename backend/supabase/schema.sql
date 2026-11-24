-- =====================================================================
-- Daily Expense - database schema (phase 1: auth + financial baseline)
--
-- How to run: Supabase dashboard > SQL Editor > New query > paste > Run.
-- Safe to run twice (uses "if not exists").
--
-- Security: every table has Row Level Security ON and NO policies. That
-- means the public anon key can read/write nothing. Only your own backend,
-- which connects with the database password, can touch these tables.
-- =====================================================================

create table if not exists public.users (
  id                  uuid primary key default gen_random_uuid(),
  phone_e164          varchar(20) not null unique,
  country_iso         varchar(2)  not null default 'IN',
  pin_hash            text        not null,
  failed_pin_attempts integer     not null default 0,
  locked_until        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table if not exists public.user_profiles (
  user_id               uuid primary key references public.users(id) on delete cascade,
  currency              varchar(8) not null default '₹',
  monthly_surplus       numeric(14,2),
  daily_limit           numeric(14,2),
  payday                smallint,
  baseline_completed_at timestamptz,
  cycle_completed_at    timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint payday_range check (payday between 1 and 31)
);

create table if not exists public.otp_challenges (
  id          uuid primary key default gen_random_uuid(),
  phone_e164  varchar(20) not null,
  country_iso varchar(2)  not null default 'IN',
  code_hash   text        not null,
  attempts    integer     not null default 0,
  expires_at  timestamptz not null,
  verified_at timestamptz,
  consumed_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists ix_otp_phone_created
  on public.otp_challenges (phone_e164, created_at);

create table if not exists public.refresh_tokens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  token_hash   varchar(64) not null unique,
  device_label varchar(80),
  expires_at   timestamptz not null,
  revoked_at   timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists ix_refresh_tokens_user on public.refresh_tokens (user_id);

create table if not exists public.baseline_categories (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  title      varchar(60) not null default '',
  is_income  boolean not null default false,
  is_custom  boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists ix_baseline_categories_user on public.baseline_categories (user_id);

create table if not exists public.baseline_items (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.baseline_categories(id) on delete cascade,
  user_id     uuid not null references public.users(id) on delete cascade,
  name        varchar(60) not null default '',
  amount      numeric(14,2) not null default 0,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  constraint amount_non_negative check (amount >= 0)
);
create index if not exists ix_baseline_items_category on public.baseline_items (category_id);
create index if not exists ix_baseline_items_user on public.baseline_items (user_id);

-- Keep updated_at fresh on every update (the API also sets it).
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_users_updated on public.users;
create trigger trg_users_updated before update on public.users
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated on public.user_profiles;
create trigger trg_profiles_updated before update on public.user_profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Lock the tables away from Supabase's public API (anon / authenticated).
-- ---------------------------------------------------------------------
alter table public.users               enable row level security;
alter table public.user_profiles       enable row level security;
alter table public.otp_challenges      enable row level security;
alter table public.refresh_tokens      enable row level security;
alter table public.baseline_categories enable row level security;
alter table public.baseline_items      enable row level security;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on public.users, public.user_profiles, public.otp_challenges,
                  public.refresh_tokens, public.baseline_categories,
                  public.baseline_items from anon, authenticated;
  end if;
end $$;
