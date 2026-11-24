-- =====================================================================
-- PHASE 2 - run this later, when you start on transactions.
-- Designed now so SMS parsing, statement import and manual entry all
-- fit the same table, and so duplicates can be detected.
-- =====================================================================

create table if not exists public.transactions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  occurred_at   timestamptz not null,
  amount        numeric(14,2) not null check (amount > 0),
  direction     text not null default 'debit' check (direction in ('debit','credit')),
  category      text not null default 'Other',
  merchant      text not null default '',          -- cleaned name, e.g. "Swiggy"
  merchant_raw  text,                              -- what the SMS/statement said
  source        text not null default 'manual'
                check (source in ('manual','sms','import','aa')),
  status        text not null default 'confirmed'
                check (status in ('confirmed','needs_review')),
  dedupe_key    text,                              -- hash of amount+time+bank ref
  account_last4 varchar(4),
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create index if not exists ix_transactions_user_time
  on public.transactions (user_id, occurred_at desc);

-- The same payment seen twice (bank SMS + UPI app) is stored once.
create unique index if not exists ux_transactions_dedupe
  on public.transactions (user_id, dedupe_key) where dedupe_key is not null;

drop trigger if exists trg_transactions_updated on public.transactions;
create trigger trg_transactions_updated before update on public.transactions
  for each row execute function public.set_updated_at();

alter table public.transactions enable row level security;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on public.transactions from anon, authenticated;
  end if;
end $$;
