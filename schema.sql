-- Nova Wallet starter schema for Supabase.
-- Review carefully before public use. No payment processor is connected.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'customer' check (role in ('customer','owner')),
  created_at timestamptz not null default now()
);
create table if not exists public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);
create table if not exists public.deposit_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount bigint not null check (amount > 0 and amount <= 10000000),
  method text not null check (method in ('Bank transfer','JazzCash','Easypaisa','Other')),
  reference text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id)
);
create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount bigint not null,
  kind text not null,
  note text,
  deposit_request_id uuid references public.deposit_requests(id),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id,email,role) values(new.id,new.email,'customer')
  on conflict (id) do nothing;
  insert into public.wallets(user_id,balance) values(new.id,0)
  on conflict (user_id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created_nova on auth.users;
create trigger on_auth_user_created_nova after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.deposit_requests enable row level security;
alter table public.wallet_transactions enable row level security;

-- SECURITY DEFINER helper avoids recursive profile-policy checks.
create or replace function public.is_wallet_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='owner');
$$;
revoke all on function public.is_wallet_owner() from public;
grant execute on function public.is_wallet_owner() to authenticated;

drop policy if exists "profiles own or owner read" on public.profiles;
create policy "profiles own or owner read" on public.profiles for select to authenticated
using (id = auth.uid() or public.is_wallet_owner());
-- Users cannot update their role from the browser; no client insert/update/delete policies for profiles.
drop policy if exists "wallet own or owner read" on public.wallets;
create policy "wallet own or owner read" on public.wallets for select to authenticated
using (user_id = auth.uid() or public.is_wallet_owner());
-- No client write policy for wallets. Balance changes only through the review function below.
drop policy if exists "deposit own or owner read" on public.deposit_requests;
create policy "deposit own or owner read" on public.deposit_requests for select to authenticated
using (user_id = auth.uid() or public.is_wallet_owner());
drop policy if exists "customer creates own deposit" on public.deposit_requests;
create policy "customer creates own deposit" on public.deposit_requests for insert to authenticated
with check (user_id = auth.uid() and status='pending' and reviewed_at is null and reviewed_by is null);
-- No client update/delete policy on deposit requests.
drop policy if exists "transactions own or owner read" on public.wallet_transactions;
create policy "transactions own or owner read" on public.wallet_transactions for select to authenticated
using (user_id = auth.uid() or public.is_wallet_owner());
-- No client insert/update/delete policy on transactions.

create or replace function public.review_deposit_request(p_request_id uuid, p_action text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.deposit_requests%rowtype;
begin
  if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and role='owner') then
    raise exception 'Owner access required';
  end if;
  if p_action not in ('approve','reject') then raise exception 'Invalid action'; end if;
  select * into r from public.deposit_requests where id=p_request_id for update;
  if not found then raise exception 'Request not found'; end if;
  if r.status <> 'pending' then raise exception 'Request already reviewed'; end if;
  update public.deposit_requests set status=case when p_action='approve' then 'approved' else 'rejected' end,
    reviewed_at=now(), reviewed_by=auth.uid() where id=r.id;
  if p_action='approve' then
    update public.wallets set balance=balance+r.amount, updated_at=now() where user_id=r.user_id;
    insert into public.wallet_transactions(user_id,amount,kind,note,deposit_request_id)
      values(r.user_id,r.amount,'deposit_approved','Owner-approved request',r.id);
  else
    insert into public.wallet_transactions(user_id,amount,kind,note,deposit_request_id)
      values(r.user_id,0,'deposit_rejected','Owner rejected request',r.id);
  end if;
  return jsonb_build_object('message','Request reviewed','status',case when p_action='approve' then 'approved' else 'rejected' end);
end; $$;
revoke all on function public.review_deposit_request(uuid,text) from public;
grant execute on function public.review_deposit_request(uuid,text) to authenticated;

-- IMPORTANT: assign the owner role only after creating your own account.
-- Replace YOUR_AUTH_USER_UUID with your own auth.users id; run in Supabase SQL Editor:
-- update public.profiles set role='owner' where id='YOUR_AUTH_USER_UUID';
