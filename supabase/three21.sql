-- =====================================================================
-- FootIQ 3-2-1 modu: veri tabloları ve cevap kontrolü
-- Veri kaynağı: Wikidata (CC0) -> tool/three21/build_dataset.py
-- Tablolara doğrudan erişim kapalı; her şey security definer fonksiyonlarla.
-- İsim kuralları tool/three21/names.py ile BİREBİR aynı olmalı (test_names.py).
-- =====================================================================

create extension if not exists fuzzystrmatch with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

create table if not exists public.t21_clubs (
  code text primary key,
  league text not null,
  name text not null,
  short text not null,
  color text,
  fame int not null default 0
);

create table if not exists public.t21_players (
  id int primary key,
  qid text not null unique,
  name text not null,
  norm text not null,              -- t21_norm(name), öneri araması için
  fame int not null default 0
);
create index if not exists t21_players_norm_trgm
  on public.t21_players using gin (norm extensions.gin_trgm_ops);

-- Bir futbolcunun kabul edilen yazımlarının ses anahtarları (tam ad, takma ad, soyadı).
create table if not exists public.t21_player_keys (
  player_id int not null references public.t21_players(id) on delete cascade,
  key text not null,
  is_surname boolean not null default false,
  primary key (player_id, key)
);
create index if not exists t21_player_keys_trgm
  on public.t21_player_keys using gin (key extensions.gin_trgm_ops);

create table if not exists public.t21_stints (
  player_id int not null references public.t21_players(id) on delete cascade,
  club text not null references public.t21_clubs(code),
  from_year int,
  to_year int,
  apps int,
  loan boolean not null default false,
  verified boolean not null default false,
  primary key (player_id, club)
);

-- Soru havuzu: en az bir doğrulanmış ortak futbolcusu olan kulüp çiftleri.
create table if not exists public.t21_pairs (
  id int primary key,
  club_a text not null references public.t21_clubs(code),
  club_b text not null references public.t21_clubs(code),
  -- doğrulanmış cevaplar (ünlüden aza); en az bir ortak futbolcu ZORUNLU:
  -- ortak futbolcusu olmayan çift tabloya hiç giremez.
  answers int[] not null check (cardinality(answers) >= 1),
  -- maç sayısı doğrulanmamış ama Wikidata'da iki kulüpte de görünen futbolcular:
  -- söylenirse doğru sayılır, sonuç ekranında gösterilmez.
  alt_answers int[] not null default '{}',
  top_fame int not null,
  difficulty int not null check (difficulty between 1 and 3),
  unique (club_a, club_b)
);

-- Oyuncuların "cevap hatalı" bildirimleri.
create table if not exists public.t21_reports (
  id bigint generated always as identity primary key,
  pair_id int,                     -- veri yeniden yüklenince bildirimler kaybolmasın diye FK yok
  said text not null check (char_length(said) <= 80),
  note text check (note is null or char_length(note) <= 200),
  reporter uuid,
  created_at timestamptz not null default now()
);

-- Sınırda kalıp reddedilen cevaplar (takma ad listesini iyileştirmek için).
create table if not exists public.t21_near_misses (
  id bigint generated always as identity primary key,
  pair_id int,
  said text not null,
  best_player int,
  score real,
  created_at timestamptz not null default now()
);

alter table public.t21_clubs enable row level security;
alter table public.t21_players enable row level security;
alter table public.t21_player_keys enable row level security;
alter table public.t21_stints enable row level security;
alter table public.t21_pairs enable row level security;
alter table public.t21_reports enable row level security;
alter table public.t21_near_misses enable row level security;
revoke all on public.t21_clubs, public.t21_players, public.t21_player_keys,
  public.t21_stints, public.t21_pairs, public.t21_reports, public.t21_near_misses
  from public, anon, authenticated;

-- ------------------------------------------------------------ isim kuralları

-- names.py norm(): küçük harf, aksansız, yalnızca harf/rakam, tek boşluk.
create or replace function public.t21_norm(s text)
returns text language sql immutable parallel safe set search_path = public, extensions as $$
  select trim(regexp_replace(regexp_replace(
    extensions.unaccent(
      replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
      replace(replace(replace(
        lower(replace(replace(coalesce(s, ''), 'İ', 'i'), 'I', 'ı')),
      'ß', 'ss'), 'ø', 'o'), 'æ', 'ae'), 'œ', 'oe'), 'đ', 'd'), 'ł', 'l'), 'ı', 'i'),
      'ð', 'd'), 'þ', 'th'), '''', ''), '’', ''), '`', ''), '´', '')
    ),
    '[^a-z0-9]+', ' ', 'g'), '\s+', ' ', 'g'))
$$;

-- names.py key(): ses anahtarı (sıra önemli).
create or replace function public.t21_key(s text)
returns text language plpgsql immutable parallel safe set search_path = public as $$
declare
  k text := public.t21_norm(s);
begin
  k := replace(k, 'tsch', 'c');
  k := replace(k, 'sch', 's');
  k := replace(k, 'sh', 's');
  k := replace(k, 'ch', 's');
  k := replace(k, 'ph', 'f');
  k := replace(k, 'th', 't');
  k := replace(k, 'ck', 'k');
  k := replace(k, 'qu', 'k');
  k := replace(k, 'q', 'k');
  k := replace(k, 'gn', 'ny');
  k := replace(k, 'nh', 'ny');
  k := replace(k, 'lh', 'ly');
  k := replace(k, 'll', 'l');
  k := replace(k, 'x', 'ks');
  k := replace(k, 'w', 'v');
  k := replace(k, 'c', 'k');
  k := replace(k, 'j', 'y');
  k := replace(k, 'y', 'i');
  k := replace(k, 'z', 's');
  k := replace(k, 'ou', 'u');
  k := replace(k, 'ei', 'ai');
  k := replace(k, 'ie', 'i');
  k := replace(k, 'ee', 'i');
  k := replace(k, 'oo', 'u');
  k := replace(k, 'h', '');
  k := regexp_replace(k, '(.)\1+', '\1', 'g');
  return k;
end $$;

-- Levenshtein benzerlik oranı (0..1).
create or replace function public.t21_ratio(a text, b text)
returns real language sql immutable parallel safe set search_path = public, extensions as $$
  select case
    when a = b then 1::real
    when coalesce(a, '') = '' or coalesce(b, '') = '' then 0::real
    else (1 - extensions.levenshtein(left(a, 255), left(b, 255))::real
              / greatest(char_length(a), char_length(b)))::real
  end
$$;

-- Söylenen/yazılan metne en çok benzeyen futbolcular (en iyi 5).
create or replace function public.t21_candidates(p_said text)
returns table (player_id int, score real)
language sql stable set search_path = public, extensions as $$
  with q as (select public.t21_key(p_said) as k)
  select pk.player_id, max(public.t21_ratio(q.k, pk.key)) as score
  from q, public.t21_player_keys pk
  where pk.key operator(extensions.%) q.k or pk.key = q.k
  group by pk.player_id
  order by score desc, max(pk.player_id) asc
  limit 5
$$;

-- ------------------------------------------------------------ cevap kontrolü
-- Sonuç:
--   correct  : söylenen isim bu çiftin doğru cevaplarından birine >= %85 benziyor
--              ve ondan belirgin şekilde daha çok benzeyen başka bir futbolcu yok
--   repeat   : doğru ama bu maçta zaten söylendi
--   wrong    : tanınan gerçek bir futbolcu ama bu iki kulüpte birlikte oynamamış
--   unknown  : hiçbir futbolcuya yeterince benzemiyor (oyuncu kilitlenmez)
create or replace function public.t21_judge(p_pair int, p_said text[], p_used int[] default '{}')
returns jsonb language plpgsql volatile security definer set search_path = public, extensions as $$
declare
  answers int[];
  s text;
  c record;
  best_id int; best_score real := 0;
  ans_id int; ans_score real := 0;
  accept constant real := 0.85;
begin
  select t.answers || t.alt_answers into answers from public.t21_pairs t where t.id = p_pair;
  if answers is null then
    return jsonb_build_object('result', 'unknown');
  end if;
  foreach s in array coalesce(p_said[1:5], '{}') loop
    s := left(s, 80);
    for c in select * from public.t21_candidates(s) loop
      if c.score > best_score then best_score := c.score; best_id := c.player_id; end if;
      if c.player_id = any(answers) and c.score > ans_score then
        ans_score := c.score; ans_id := c.player_id;
      end if;
    end loop;
  end loop;

  if ans_id is not null and ans_score >= accept and ans_score >= best_score - 0.02 then
    return jsonb_build_object(
      'result', case when ans_id = any(coalesce(p_used, '{}')) then 'repeat' else 'correct' end,
      'player_id', ans_id,
      'player', (select name from public.t21_players where id = ans_id),
      'score', round(ans_score::numeric, 2));
  end if;
  -- Sınırda kalan cevapları sonra incelemek üzere kaydet (takma ad listesini büyütmek için).
  if greatest(best_score, ans_score) between 0.6 and accept then
    insert into public.t21_near_misses (pair_id, said, best_player, score)
    values (p_pair, left(coalesce(p_said[1], ''), 80), coalesce(ans_id, best_id),
            greatest(best_score, ans_score));
  end if;
  if best_score >= accept then
    return jsonb_build_object('result', 'wrong', 'player_id', best_id,
      'player', (select name from public.t21_players where id = best_id),
      'score', round(best_score::numeric, 2));
  end if;
  return jsonb_build_object('result', 'unknown', 'score', round(best_score::numeric, 2));
end $$;

-- Bir maç için, hiçbir kulübün iki kez görünmediği N kulüp çifti seçer.
create or replace function public.t21_pick_pairs(p_count int default 6, p_max_difficulty int default 3)
returns table (pair_id int, club_a text, club_b text, name_a text, name_b text,
               short_a text, short_b text, color_a text, color_b text, league_a text, league_b text)
language plpgsql volatile security definer set search_path = public as $$
declare
  used text[];
  picked int[];
  r record;
  attempt int := 0;
begin
  p_count := least(greatest(p_count, 1), 10);
  loop
    attempt := attempt + 1;
    used := '{}'; picked := '{}';
    for i in 1..p_count loop
      select t.id, t.club_a, t.club_b into r from public.t21_pairs t
       where t.difficulty <= p_max_difficulty
         and not (t.club_a = any(used)) and not (t.club_b = any(used))
       order by random() limit 1;
      exit when not found;
      used := used || r.club_a || r.club_b;
      picked := picked || r.id;
    end loop;
    exit when cardinality(picked) = p_count or attempt >= 20;
  end loop;
  return query
    select t.id, t.club_a, t.club_b, ca.name, cb.name, ca.short, cb.short,
           ca.color, cb.color, ca.league, cb.league
    from unnest(picked) with ordinality u(id, ord)
    join public.t21_pairs t on t.id = u.id
    join public.t21_clubs ca on ca.code = t.club_a
    join public.t21_clubs cb on cb.code = t.club_b
    order by u.ord;
end $$;

-- Soru bitince gösterilen diğer doğru cevaplar (en bilinen 5).
create or replace function public.t21_reveal(p_pair int, p_limit int default 5)
returns table (player_id int, name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.name
  from public.t21_pairs t, unnest(t.answers) with ordinality a(id, ord)
  join public.t21_players p on p.id = a.id
  where t.id = p_pair
  order by a.ord
  limit least(greatest(p_limit, 1), 20)
$$;

-- Yazarak cevapta öneri listesi (3+ harf). Bütün futbolculardan arar; doğru
-- cevapları ayrıca öne çıkarmaz, bu yüzden cevabı ele vermez.
create or replace function public.t21_suggest(p_prefix text)
returns table (player_id int, name text)
language sql stable security definer set search_path = public, extensions as $$
  with q as (select public.t21_norm(p_prefix) as n)
  select p.id, p.name from public.t21_players p, q
  where char_length(q.n) >= 3 and p.norm like '%' || q.n || '%'
  order by (p.norm like q.n || '%') desc, p.fame desc
  limit 8
$$;

grant execute on function public.t21_judge(int, text[], int[]),
  public.t21_pick_pairs(int, int), public.t21_reveal(int, int), public.t21_suggest(text)
  to anon, authenticated;

-- ------------------------------------------------------------ veri yükleme
-- Yalnızca tek kullanımlık anahtarla çalışır. Anahtar SQL ile eklenir:
--   insert into public.t21_import_tokens(token) values ('<rastgele>');
-- Yükleme bitince silinir: delete from public.t21_import_tokens;
create table if not exists public.t21_import_tokens (
  token text primary key,
  created_at timestamptz not null default now()
);
alter table public.t21_import_tokens enable row level security;
revoke all on public.t21_import_tokens from public, anon, authenticated;

create or replace function public.t21_import(p_token text, p_kind text, p_rows jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare n int := 0;
begin
  if not exists (select 1 from public.t21_import_tokens
                 where token = p_token and created_at > now() - interval '2 hours') then
    raise exception 'yetkisiz';
  end if;
  if p_kind = 'reset' then
    truncate public.t21_pairs, public.t21_stints, public.t21_player_keys,
             public.t21_players, public.t21_clubs cascade;
    return 0;
  elsif p_kind = 'clubs' then
    insert into public.t21_clubs select * from jsonb_populate_recordset(null::public.t21_clubs, p_rows);
  elsif p_kind = 'players' then
    insert into public.t21_players select * from jsonb_populate_recordset(null::public.t21_players, p_rows);
  elsif p_kind = 'keys' then
    insert into public.t21_player_keys select * from jsonb_populate_recordset(null::public.t21_player_keys, p_rows)
    on conflict do nothing;
  elsif p_kind = 'stints' then
    insert into public.t21_stints select * from jsonb_populate_recordset(null::public.t21_stints, p_rows);
  elsif p_kind = 'pairs' then
    insert into public.t21_pairs select * from jsonb_populate_recordset(null::public.t21_pairs, p_rows);
  else
    raise exception 'bilinmeyen tür';
  end if;
  get diagnostics n = row_count;
  return n;
end $$;
grant execute on function public.t21_import(text, text, jsonb) to anon;
