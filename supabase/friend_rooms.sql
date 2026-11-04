-- =====================================================================
-- Arkadaşınla Oyna: kodlu özel PVP odaları (supabase/schema.sql'e ek)
-- Rastgele eşleşme özel odalara asla girmez; özel oda 10 dakika açık kalır.
-- =====================================================================

alter table public.pvp_rooms add column if not exists code text
  check (code is null or code ~ '^[0-9]{4}$');
create unique index if not exists pvp_rooms_open_code
  on public.pvp_rooms (code) where status = 'open' and code is not null;

-- Rastgele eşleşme: özel odaları (code dolu) atla.
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

  delete from public.pvp_rooms where created_at < now() - interval '15 minutes';

  select * into r from public.pvp_rooms
  where category = p_category
    and status = 'open'
    and code is null
    and host_id <> p_player_id
    and created_at > now() - interval '12 seconds'
  order by created_at asc
  limit 1
  for update skip locked;

  if r.id is not null then
    update public.pvp_rooms
    set guest_id = p_player_id, guest_name = clean_name, status = 'playing', updated_at = now()
    where id = r.id
    returning * into r;
  else
    insert into public.pvp_rooms (category, seed, host_id, host_name)
    values (p_category, p_seed, p_player_id, clean_name)
    returning * into r;
  end if;
  return to_jsonb(r);
end $$;

-- Özel oda aç: 4 haneli, o an açık başka odada kullanılmayan bir kod üretir.
create or replace function public.create_private_pvp(
  p_category text,
  p_player_id text,
  p_name text,
  p_seed int
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  r public.pvp_rooms;
  c text;
  clean_name text := substr(trim(regexp_replace(coalesce(p_name, 'Oyuncu'), '[^A-Za-z0-9_çğıöşüÇĞİÖŞÜ ]', '', 'g')), 1, 20);
begin
  if p_category not in ('benKimim', 'championsLeague', 'hangiTakim') then
    raise exception 'invalid category';
  end if;
  if char_length(p_player_id) < 8 or char_length(p_player_id) > 64 then
    raise exception 'invalid player_id';
  end if;
  if clean_name = '' then clean_name := 'Oyuncu'; end if;

  delete from public.pvp_rooms where created_at < now() - interval '15 minutes';
  -- Aynı oyuncunun önceki açık özel odalarını kapat (tek oda kuralı).
  delete from public.pvp_rooms where host_id = p_player_id and status = 'open' and code is not null;

  for i in 1..30 loop
    c := lpad((floor(random() * 9000) + 1000)::int::text, 4, '0');
    begin
      insert into public.pvp_rooms (category, seed, host_id, host_name, code)
      values (p_category, p_seed, p_player_id, clean_name, c)
      returning * into r;
      return to_jsonb(r);
    exception when unique_violation then
      -- kod o an kullanımda, başka kod dene
    end;
  end loop;
  raise exception 'no free code';
end $$;

-- Kodla odaya katıl. Oda yoksa, dolmuşsa veya süresi geçtiyse null döner.
create or replace function public.join_private_pvp(p_code text, p_player_id text, p_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  r public.pvp_rooms;
  clean_code text := regexp_replace(coalesce(p_code, ''), '[^0-9]', '', 'g');
  clean_name text := substr(trim(regexp_replace(coalesce(p_name, 'Oyuncu'), '[^A-Za-z0-9_çğıöşüÇĞİÖŞÜ ]', '', 'g')), 1, 20);
begin
  if char_length(p_player_id) < 8 or char_length(p_player_id) > 64 then
    raise exception 'invalid player_id';
  end if;
  if clean_name = '' then clean_name := 'Oyuncu'; end if;

  select * into r from public.pvp_rooms
  where code = clean_code and status = 'open'
    and created_at > now() - interval '10 minutes'
  limit 1
  for update;

  if r.id is null or r.host_id = p_player_id then
    return null;
  end if;

  update public.pvp_rooms
  set guest_id = p_player_id, guest_name = clean_name, status = 'playing', updated_at = now()
  where id = r.id
  returning * into r;
  return to_jsonb(r);
end $$;

-- Oda sahibi beklerken vazgeçerse odayı kapat.
create or replace function public.cancel_pvp_room(p_room_id uuid, p_player_id text)
returns void language sql security definer set search_path = public as $$
  delete from public.pvp_rooms
  where id = p_room_id and host_id = p_player_id and status = 'open';
$$;

revoke all on function public.create_private_pvp(text, text, text, int) from public;
revoke all on function public.join_private_pvp(text, text, text) from public;
revoke all on function public.cancel_pvp_room(uuid, text) from public;
grant execute on function public.create_private_pvp(text, text, text, int) to anon, authenticated;
grant execute on function public.join_private_pvp(text, text, text) to anon, authenticated;
grant execute on function public.cancel_pvp_room(uuid, text) to anon, authenticated;
