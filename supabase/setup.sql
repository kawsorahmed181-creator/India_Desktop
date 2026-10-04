-- India 2027 Squad Lab – server setup. Paste ALL of this into Supabase > SQL Editor > Run.
-- Accounts and squads live on the server, so they survive uninstall, cleared storage and new phones.
-- The tables are locked (nobody can read them directly). The app can only call the functions below.

create table if not exists accounts (
  id         uuid primary key default gen_random_uuid(),
  token      uuid not null default gen_random_uuid(),
  name       text not null,
  email      text not null,
  phone      text not null unique check (phone ~ '^[0-9]{10}$'),
  created_at timestamptz not null default now()
);

create table if not exists squads (
  account_id uuid primary key references accounts(id) on delete cascade,
  selected   jsonb not null,
  cap        text not null,
  vc         text not null,
  wk         text not null,
  updated_at timestamptz not null default now()
);

alter table accounts enable row level security;
alter table squads   enable row level security;
revoke all on accounts, squads from anon, authenticated;

-- lower-case and collapse spaces: "  Saani   ALAM " -> "saani alam"
create or replace function norm_name(t text) returns text
language sql immutable as $$ select lower(regexp_replace(btrim(coalesce(t,'')), '\s+', ' ', 'g')) $$;

-- CREATE ACCOUNT ---------------------------------------------------------
create or replace function create_account(p_name text, p_email text, p_phone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n text := btrim(coalesce(p_name,'')); e text := btrim(coalesce(p_email,'')); ph text := coalesce(p_phone,'');
begin
  if length(n) < 2 or length(n) > 60 then return jsonb_build_object('ok', false, 'reason', 'bad_name'); end if;
  if e !~ '^\S+@\S+\.\S+$' or length(e) > 120 then return jsonb_build_object('ok', false, 'reason', 'bad_email'); end if;
  if ph !~ '^[0-9]{10}$' then return jsonb_build_object('ok', false, 'reason', 'bad_phone'); end if;
  if exists (select 1 from accounts where phone = ph) then return jsonb_build_object('ok', false, 'reason', 'phone_exists'); end if;
  insert into accounts(name, email, phone) values (n, e, ph);
  return jsonb_build_object('ok', true);
end $$;

-- LOGIN ------------------------------------------------------------------
-- Phone must match exactly. Name is case/space-insensitive and may be the first word(s) of the
-- registered name: registered "Saani Alam Choudhury" -> "saani", "Saani Alam", "saani alam choudhury" pass;
-- "alam", "alam choudhury" fail.
create or replace function login_account(p_name text, p_phone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare a accounts; given text := norm_name(p_name); reg text; s squads;
begin
  if p_phone !~ '^[0-9]{10}$' or given = '' then return jsonb_build_object('ok', false); end if;
  select * into a from accounts where phone = p_phone;
  if not found then return jsonb_build_object('ok', false); end if;
  reg := norm_name(a.name);
  if not (reg = given or left(reg, length(given) + 1) = given || ' ') then return jsonb_build_object('ok', false); end if;
  select * into s from squads where account_id = a.id;
  return jsonb_build_object('ok', true, 'token', a.token, 'name', a.name, 'email', a.email, 'phone', a.phone,
    'squad', case when s.account_id is null then null else jsonb_build_object('selected', s.selected, 'cap', s.cap, 'vc', s.vc, 'wk', s.wk) end);
end $$;

-- SAVE / UPDATE MY SQUAD (one squad per account) ---------------------------
create or replace function submit_squad(p_token uuid, p_selected jsonb, p_cap text, p_vc text, p_wk text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare a accounts;
begin
  select * into a from accounts where token = p_token;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_logged_in'); end if;
  if jsonb_typeof(p_selected) <> 'array' or jsonb_array_length(p_selected) <> 15
     or (select count(distinct v) from jsonb_array_elements_text(p_selected) v) <> 15
     or not (p_selected ? p_cap) or not (p_selected ? p_vc) or not (p_selected ? p_wk) or p_cap = p_vc
  then return jsonb_build_object('ok', false, 'reason', 'bad_squad'); end if;
  insert into squads(account_id, selected, cap, vc, wk) values (a.id, p_selected, p_cap, p_vc, p_wk)
  on conflict (account_id) do update set selected = excluded.selected, cap = excluded.cap, vc = excluded.vc, wk = excluded.wk, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;

-- COMMUNITY NUMBERS (no names, emails or phones) ---------------------------
create or replace function get_stats()
returns jsonb language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('selected', selected, 'cap', cap, 'vc', vc, 'wk', wk)), '[]'::jsonb)
  from (select * from squads order by updated_at desc limit 5000) t
$$;

revoke all on function create_account(text,text,text), login_account(text,text), submit_squad(uuid,jsonb,text,text,text), get_stats() from public;
grant execute on function create_account(text,text,text), login_account(text,text), submit_squad(uuid,jsonb,text,text,text), get_stats() to anon, authenticated;
