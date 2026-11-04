"""İsim sadeleştirme ve ses benzerliği anahtarı.

Aynı kurallar sunucudaki SQL fonksiyonunda (`supabase/three21.sql` → `t21_norm`,
`t21_key`) birebir uygulanır; `test_names.py` iki tarafın aynı sonucu verdiğini
örneklerle doğrular. Kural eklerken iki yeri birlikte güncelle.
"""

import re
import unicodedata

_SPECIAL = str.maketrans({
    "ß": "ss", "ø": "o", "æ": "ae", "œ": "oe", "đ": "d", "ł": "l", "ı": "i",
    "ð": "d", "þ": "th", "'": "", "’": "", "`": "", "´": "",
})


def norm(s: str) -> str:
    """Küçük harf, aksansız, yalnızca harf/rakam ve tek boşluk.

    Özil -> ozil, Kurányi -> kuranyi, Şükür -> sukur, İlhan -> ilhan
    """
    s = s.replace("İ", "i").replace("I", "ı").lower().translate(_SPECIAL)
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


# Türkçe konuşma tanımanın yabancı isimleri "duyduğu gibi" yazmasını tolere eden
# ses anahtarı. Sıra önemlidir (uzun kalıplar önce).
_KEY_RULES = [
    (r"tsch", "c"), (r"sch", "s"), (r"sh", "s"), (r"ch", "s"),
    (r"ph", "f"), (r"th", "t"), (r"ck", "k"), (r"qu", "k"), (r"q", "k"),
    (r"gn", "ny"), (r"nh", "ny"), (r"lh", "ly"), (r"ll", "l"),
    (r"x", "ks"), (r"w", "v"), (r"c", "k"), (r"j", "y"), (r"y", "i"),
    (r"z", "s"), (r"ou", "u"), (r"ei", "ai"), (r"ie", "i"), (r"ee", "i"),
    (r"oo", "u"), (r"h", ""),
    (r"(.)\1+", r"\1"),  # çift harfler: tt -> t
]


def key(s: str) -> str:
    """Ses anahtarı: Schweinsteiger ~ Şvaynştayger, Ronaldinho ~ Ronaldinyo."""
    k = norm(s)
    for pat, rep in _KEY_RULES:
        k = re.sub(pat, rep, k)
    return k


def ratio(a: str, b: str) -> float:
    """Levenshtein benzerlik oranı (0..1). 1 = birebir aynı."""
    if a == b:
        return 1.0
    if not a or not b:
        return 0.0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return 1 - prev[-1] / max(len(a), len(b))


def name_variants(name: str, aliases: list[str]) -> set[str]:
    """Bir futbolcunun kabul edilen yazımları: tam ad, takma adlar, soyadı."""
    out = set()
    for n in [name, *aliases]:
        if not n:
            continue
        nn = norm(n)
        if nn:
            out.add(nn)
            parts = nn.split()
            if len(parts) > 1:
                out.add(parts[-1])  # soyadı (ör. ozil)
    return out
