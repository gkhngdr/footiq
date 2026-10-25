-- FootIQ Supabase semasi. Supabase Dashboard > SQL Editor'a yapistirip calistirin.
-- Guvenlik: tum tablolarda RLS acik; kullanici yalnizca kendi satirini yazabilir.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null check (char_length(username) between 3 and 20),
  trophies int not null default 0 check (trophies >= 0 and trophies <= 1000000),
  coins int not null default 500 check (coins >= 0 and coins <= 100000000),
  progress jsonb not null default '{}'::jsonb,
  invite_code text unique not null default substr(md5(random()::text), 1, 8),
  invited_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Siralama icin giris yapmis herkes profilleri okuyabilir.
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Davet alanlari istemciden degistirilemesin.
revoke update on public.profiles from authenticated;
grant update (username, trophies, coins, progress, updated_at) on public.profiles to authenticated;
revoke insert on public.profiles from authenticated;
grant insert (id, username, trophies, coins, progress) on public.profiles to authenticated;

-- Giris yapmamis (anon) kullanicinin tabloya hic erisimi olmasin.
revoke all on public.profiles from anon;

-- Baskalarinin davet kodlari okunamasin (kod toplama / sahte hesapla coin cekme engeli).
-- Kullanici kendi kodunu my_invite_code() ile alir.
revoke select on public.profiles from authenticated;
grant select (id, username, trophies, coins, progress, updated_at) on public.profiles to authenticated;

create or replace function public.my_invite_code()
returns text language sql security definer set search_path = public as $$
  select invite_code from public.profiles where id = auth.uid();
$$;
revoke all on function public.my_invite_code() from public, anon;
grant execute on function public.my_invite_code() to authenticated;

-- Yeni kayit olan kullanicilarin e-postasini aninda onayla (kesintisiz kayit deneyimi).
create or replace function public.auto_confirm_email()
returns trigger language plpgsql security definer set search_path = auth as $$
begin
  if new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_autoconfirm on auth.users;
create trigger on_auth_user_autoconfirm before insert on auth.users
  for each row execute function public.auto_confirm_email();

-- Hile siniri: ilk kayitta (INSERT) ve guncellemede (UPDATE) kupa/coin artisi sinirlanir.
-- Ilk kayitta (misafirden gecis dahil) en fazla 500 kupa ve 50.000 coin kabul edilir.
-- Guncellemede: kupa en fazla 20 + 1/sn, coin en fazla 6000 + 250/sn. updated_at sunucuda yazilir.
create or replace function public.limit_profile_growth()
returns trigger language plpgsql as $$
declare secs numeric;
begin
  if current_user <> 'authenticated' then return new; end if;
  if tg_op = 'INSERT' then
    if new.trophies > 500 then
      raise exception 'initial trophies too high' using errcode = 'P0001';
    end if;
    if new.coins > 50000 then
      raise exception 'initial coins too high' using errcode = 'P0001';
    end if;
    new.updated_at := now();
    return new;
  end if;
  secs := greatest(extract(epoch from (now() - old.updated_at)), 0);
  if new.trophies - old.trophies > 20 + secs * 1 then
    raise exception 'trophy growth too fast' using errcode = 'P0001';
  end if;
  if new.coins - old.coins > 6000 + secs * 250 then
    raise exception 'coin growth too fast' using errcode = 'P0001';
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_limit_growth on public.profiles;
create trigger profiles_limit_growth before insert or update on public.profiles
  for each row execute function public.limit_profile_growth();

-- Kullanicinin sirasi (kupa sayisina gore).
create or replace function public.my_rank()
returns int language sql security definer set search_path = public as $$
  select count(*)::int + 1 from public.profiles
  where trophies > coalesce((select trophies from public.profiles where id = auth.uid()), 0);
$$;

-- Ilk 50 oyuncu (misafir ve hesapli oyuncular gorebilir).
create or replace function public.leaderboard()
returns table(username text, trophies int) language sql security definer set search_path = public as $$
  select username, trophies from public.profiles order by trophies desc limit 50;
$$;

-- Davet kodunu kullan: davet eden ve davet edilen 500 coin kazanir (bir kez, buyuk/kucuk harf duyarsiz).
create or replace function public.redeem_invite(code text)
returns int language plpgsql security definer set search_path = public as $$
declare inviter uuid;
begin
  select id into inviter from public.profiles
  where lower(invite_code) = lower(trim(code)) and id <> auth.uid();
  if inviter is null then return 0; end if;
  update public.profiles set invited_by = inviter, coins = coins + 500
    where id = auth.uid() and invited_by is null;
  if not found then return 0; end if;
  update public.profiles set coins = coins + 500 where id = inviter;
  return 500;
end $$;

-- Hesabi kalici sil (magaza zorunlulugu). profiles satiri cascade ile silinir.
create or replace function public.delete_account()
returns void language plpgsql security definer set search_path = public, auth as $$
begin
  delete from auth.users where id = auth.uid();
end $$;

revoke all on function public.redeem_invite(text) from public, anon;
grant execute on function public.redeem_invite(text) to authenticated;
revoke all on function public.my_rank() from public, anon;
grant execute on function public.my_rank() to authenticated;
revoke all on function public.leaderboard() from public;
grant execute on function public.leaderboard() to anon, authenticated;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

-- ============================================================================
-- ONLINE SENKRON PVP ESLESME TABLOSU VE FONKSIYONLARI
-- Iki oyuncu ayni kategoride eslestiginde ayni 'seed' degerini alir ve
-- birebir ayni 5 soruyu, ayni sik sirasiyla, eszamanli olarak gorur.
-- ============================================================================

create table if not exists public.pvp_rooms (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('benKimim', 'championsLeague', 'hangiTakim')),
  seed int not null,
  host_id text not null check (char_length(host_id) between 8 and 64),
  host_name text not null check (char_length(host_name) between 1 and 24),
  host_score int not null default 0 check (host_score between 0 and 2000),
  host_step int not null default 0 check (host_step between 0 and 5),
  guest_id text check (guest_id is null or char_length(guest_id) between 8 and 64),
  guest_name text check (guest_name is null or char_length(guest_name) between 1 and 24),
  guest_score int not null default 0 check (guest_score between 0 and 2000),
  guest_step int not null default 0 check (guest_step between 0 and 5),
  status text not null default 'open' check (status in ('open', 'playing', 'done')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.pvp_rooms enable row level security;
revoke all on public.pvp_rooms from public, anon, authenticated;

-- Acik bir PVP odasina katil veya yeni oda olustur.
create or replace function public.join_or_create_pvp(
  p_category text,
  p_player_id text,
  p_name text,
  p_seed int
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  r public.pvp_rooms;
  clean_name text := substr(trim(regexp_replace(coalesce(p_name, 'Oyuncu'), '[^A-Za-z0-9_çğıöşüÇĞİÖŞÜ ]', '', 'g')), 1, 20);
begin
  if p_category not in ('benKimim', 'championsLeague', 'hangiTakim') then
    raise exception 'invalid category';
  end if;
  if char_length(p_player_id) < 8 or char_length(p_player_id) > 64 then
    raise exception 'invalid player_id';
  end if;
  if clean_name = '' then clean_name := 'Oyuncu'; end if;

  -- Eski (10 dakikadan eski) acik odalari temizle
  delete from public.pvp_rooms where created_at < now() - interval '10 minutes';

  -- Son 12 saniye icinde acilmis uygun bir oda bul ve esles
  select * into r from public.pvp_rooms
  where category = p_category
    and status = 'open'
    and host_id <> p_player_id
    and created_at > now() - interval '12 seconds'
  order by created_at asc
  limit 1
  for update skip locked;

  if r.id is not null then
    update public.pvp_rooms
    set guest_id = p_player_id,
        guest_name = clean_name,
        status = 'playing',
        updated_at = now()
    where id = r.id
    returning * into r;
  else
    insert into public.pvp_rooms (category, seed, host_id, host_name)
    values (p_category, p_seed, p_player_id, clean_name)
    returning * into r;
  end if;

  return to_jsonb(r);
end $$;

-- Odanin guncel durumunu (rakip katildi mi, skoru ve hangi soruda oldugu) getir.
create or replace function public.poll_pvp_room(p_room_id uuid, p_player_id text)
returns jsonb language sql security definer set search_path = public as $$
  select to_jsonb(r) from public.pvp_rooms r
  where r.id = p_room_id and (r.host_id = p_player_id or r.guest_id = p_player_id);
$$;

-- Oyuncunun soru cevabindan sonra skorunu ve adimini guncelle, odanin son halini dondur.
create or replace function public.update_pvp_progress(
  p_room_id uuid,
  p_player_id text,
  p_score int,
  p_step int
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.pvp_rooms;
begin
  if p_score < 0 or p_score > 2000 or p_step < 0 or p_step > 5 then
    raise exception 'invalid pvp progress';
  end if;

  update public.pvp_rooms
  set host_score = case when host_id = p_player_id then greatest(host_score, p_score) else host_score end,
      host_step = case when host_id = p_player_id then greatest(host_step, p_step) else host_step end,
      guest_score = case when guest_id = p_player_id then greatest(guest_score, p_score) else guest_score end,
      guest_step = case when guest_id = p_player_id then greatest(guest_step, p_step) else guest_step end,
      status = case
        when (case when host_id = p_player_id then greatest(host_step, p_step) else host_step end) >= 5
         and (case when guest_id = p_player_id then greatest(guest_step, p_step) else guest_step end) >= 5
        then 'done'
        else status
      end,
      updated_at = now()
  where id = p_room_id and (host_id = p_player_id or guest_id = p_player_id)
  returning * into r;

  if r.id is null then
    return null;
  end if;
  return to_jsonb(r);
end $$;

revoke all on function public.join_or_create_pvp(text, text, text, int) from public;
grant execute on function public.join_or_create_pvp(text, text, text, int) to anon, authenticated;
revoke all on function public.poll_pvp_room(uuid, text) from public;
grant execute on function public.poll_pvp_room(uuid, text) to anon, authenticated;
revoke all on function public.update_pvp_progress(uuid, text, int, int) from public;
grant execute on function public.update_pvp_progress(uuid, text, int, int) to anon, authenticated;

-- ============================================================================
-- UZAKTAN SORU BANKASI TABLOSU (SALT OKUNUR / RLS KORUMALI)
-- ============================================================================
create table if not exists public.questions (
  id bigint generated always as identity primary key,
  category text not null check (category in ('chapter1', 'chapter2', 'chapter3', 'chapter4', 'benKimim', 'championsLeague', 'hangiTakim')),
  prompt text not null check (char_length(prompt) between 5 and 300),
  options jsonb not null,
  difficulty int not null default 5 check (difficulty between 1 and 10),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.questions enable row level security;
revoke all on public.questions from public, anon, authenticated;
grant select on public.questions to anon, authenticated;

drop policy if exists "questions_select_active" on public.questions;
create policy "questions_select_active" on public.questions
  for select to anon, authenticated using (active = true);
