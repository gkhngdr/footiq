#!/usr/bin/env python3
"""out/*.json -> Supabase t21_* tabloları.

Yükleme, `t21_import` fonksiyonu üzerinden parça parça yapılır. Fonksiyon yalnızca
`t21_import_tokens` tablosundaki tek kullanımlık anahtarı bilen çağrıyı kabul eder
(anahtar sunucuda SQL ile oluşturulur, yükleme bitince silinir).

    T21_IMPORT_TOKEN=... python3 -I tool/three21/import_supabase.py

Futbolcu kimlikleri her yüklemede ünlüden aza sıralanarak yeniden verilir; bu yüzden
tablolar önce boşaltılır (kind=reset).
"""

import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from names import key, norm  # noqa: E402

URL = "https://adxkmacrsylhacxsmktr.supabase.co/rest/v1/rpc/t21_import"
KEY = "sb_publishable_cvBVu2lB5zZdINYGMx2czg_sAo0W5BF"  # herkese açık anahtar

# Soyadı tek başına kabul edilmeyecek kadar yaygın olanlar.
GENERIC_SURNAMES = {
    "junior", "jr", "neto", "filho", "silva", "santos", "souza", "sousa", "oliveira",
    "ferreira", "pereira", "costa", "rodrigues", "rodriguez", "garcia", "fernandez",
    "fernandes", "gonzalez", "lopez", "martinez", "sanchez", "perez", "gomez", "diaz",
    "mohamed", "ali", "yilmaz", "kaya", "demir", "celik", "sahin", "yildiz", "aydin",
    "ozturk", "arslan", "dogan", "kilic", "aslan", "cetin", "kara", "koc", "kurt",
    "ozdemir", "polat", "simsek", "erdogan", "smith", "jones", "williams", "brown",
    "johnson", "taylor", "wilson", "davies", "evans", "thomas", "roberts", "martin",
    "bernard", "dubois", "muller", "schmidt", "schneider", "fischer", "weber", "meyer",
    "rossi", "russo", "ferrari", "esposito", "bianchi", "romano", "ricci", "marino",
}


def call(token: str, kind: str, rows, retries: int = 5) -> int:
    body = json.dumps({"p_token": token, "p_kind": kind, "p_rows": rows}).encode()
    for attempt in range(retries):
        req = urllib.request.Request(URL, data=body, method="POST", headers={
            "apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json",
        })
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:300]
            print(f"  ! {kind} parçası başarısız ({e.code}): {detail}", file=sys.stderr)
            if attempt == retries - 1:
                raise
            time.sleep(5 * (attempt + 1))


def chunks(rows, n):
    for i in range(0, len(rows), n):
        yield rows[i:i + n]


def difficulty(top_fame: int, fame_a: int, fame_b: int) -> int:
    if top_fame >= 60 and min(fame_a, fame_b) >= 60:
        return 1
    if top_fame >= 30:
        return 2
    return 3


def main() -> None:
    token = os.environ.get("T21_IMPORT_TOKEN")
    if not token:
        sys.exit("T21_IMPORT_TOKEN gerekli")
    out = ROOT / "out"
    clubs = json.loads((ROOT / "clubs_resolved.json").read_text(encoding="utf-8"))
    manual = json.loads((ROOT / "colors_manual.json").read_text(encoding="utf-8"))
    players = json.loads((out / "players.json").read_text(encoding="utf-8"))
    stints = json.loads((out / "stints.json").read_text(encoding="utf-8"))
    pairs = json.loads((out / "pairs.json").read_text(encoding="utf-8"))

    players.sort(key=lambda p: (-p["fame"], p["qid"]))
    pid = {p["qid"]: i + 1 for i, p in enumerate(players)}
    club_fame = {c["code"]: c["sitelinks"] for c in clubs}

    print("sıfırlanıyor:", call(token, "reset", []))
    club_rows = [{
        "code": c["code"], "league": c["league"], "name": c["name_tr"], "short": c["short"],
        "color": manual.get(c["code"]) or c.get("color"), "fame": c["sitelinks"],
    } for c in clubs]
    print("kulüp:", call(token, "clubs", club_rows))

    prow = [{"id": pid[p["qid"]], "qid": p["qid"], "name": p["name"], "norm": norm(p["name"]),
             "fame": p["fame"]} for p in players]
    n = 0
    for ch in chunks(prow, 500):
        n += call(token, "players", ch)
    print("futbolcu:", n)

    keys = []
    for p in players:
        seen = set()
        for full in [p["name"], p.get("name_en"), *p["aliases"]]:
            if not full:
                continue
            k = key(full)
            if k and k not in seen:
                seen.add(k)
                keys.append({"player_id": pid[p["qid"]], "key": k, "is_surname": False})
            parts = norm(full).split()
            if len(parts) > 1 and len(parts[-1]) >= 4 and parts[-1] not in GENERIC_SURNAMES:
                sk = key(parts[-1])
                if sk and sk not in seen:
                    seen.add(sk)
                    keys.append({"player_id": pid[p["qid"]], "key": sk, "is_surname": True})
    n = 0
    for ch in chunks(keys, 1000):
        n += call(token, "keys", ch)
    print("ses anahtarı:", n)

    srow = [{"player_id": pid[s["qid"]], "club": s["club"], "from_year": s["from"],
             "to_year": s["to"], "apps": s["apps"] or None, "loan": s["loan"],
             "verified": s["verified"]} for s in stints if s["qid"] in pid]
    n = 0
    for ch in chunks(srow, 1000):
        n += call(token, "stints", ch)
    print("kariyer kaydı:", n)

    pair_rows = [{
        "id": i + 1, "club_a": p["a"], "club_b": p["b"],
        "answers": [pid[q] for q in p["answers"]],
        "alt_answers": [pid[q] for q in p["unverified"] if q in pid],
        "top_fame": p["top_fame"],
        "difficulty": difficulty(p["top_fame"], club_fame[p["a"]], club_fame[p["b"]]),
    } for i, p in enumerate(pairs)]
    n = 0
    for ch in chunks(pair_rows, 300):
        n += call(token, "pairs", ch)
    print("kulüp çifti:", n)
    from collections import Counter
    print("zorluk dağılımı:", dict(Counter(r["difficulty"] for r in pair_rows)))


if __name__ == "__main__":
    main()
