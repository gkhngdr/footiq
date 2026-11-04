#!/usr/bin/env python3
"""cache/*.json (Wikidata ham verisi) -> 3-2-1 soru havuzu.

Kurallar:
- Yalnızca futbolcunun o kulübün A takımında oynadığı dönemler (Wikidata'da altyapı,
  B takımı ve milli takımlar ayrı kayıt olduğundan zaten listede yok).
- Maç sayısı 0 olan dönem sayılmaz. Maç sayısı yoksa dönem "doğrulanmamış" sayılır.
- Kiralık dönemler sayılır.
- 1990 öncesi biten dönemler alınmaz.
- Bir kulüp çifti, en az bir "iki kulüpte de doğrulanmış" ortak futbolcusu varsa
  havuza girer.

Çıktı: out/players.json, out/stints.json, out/pairs.json, out/report.txt
Kullanım: python3 -I tool/three21/build_dataset.py
"""

import itertools
import json
import pathlib
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from names import key, norm  # noqa: E402

MIN_END_YEAR = 1990


def year(d):
    return int(d[:4]) if d and d[:4].isdigit() else None


def main() -> None:
    clubs = json.loads((ROOT / "clubs_resolved.json").read_text(encoding="utf-8"))
    players: dict[str, dict] = {}
    # (qid, club) -> {"verified": bool, "years": [..], "loan": bool, "apps": int|None}
    stints: dict[tuple[str, str], dict] = {}

    for c in clubs:
        path = ROOT / "cache" / f"{c['code']}.json"
        if not path.exists():
            print("eksik önbellek:", c["code"])
            continue
        for r in json.loads(path.read_text(encoding="utf-8")):
            name = r["name_tr"] or r["name_en"]
            if not name or name.startswith("Q"):
                continue
            end_y, start_y = year(r["end"]), year(r["start"])
            if end_y is not None and end_y < MIN_END_YEAR:
                continue
            if not isinstance(r["apps"], int):
                r["apps"] = None
            if r["apps"] == 0:
                continue
            p = players.setdefault(r["qid"], {
                "qid": r["qid"], "name": name, "name_en": r["name_en"],
                "aliases": set(), "birth": r["birth"], "fame": r["sitelinks"],
            })
            p["aliases"].update(a for a in r["aliases"] if len(a) <= 40)
            if r["name_en"] and r["name_en"] != name:
                p["aliases"].add(r["name_en"])
            s = stints.setdefault((r["qid"], c["code"]), {
                "verified": False, "from": start_y, "to": end_y, "loan": False, "apps": 0,
            })
            if r["apps"]:
                s["verified"] = True
                s["apps"] += r["apps"]
            s["loan"] = s["loan"] or r["loan"]
            if start_y and (s["from"] is None or start_y < s["from"]):
                s["from"] = start_y
            if end_y and (s["to"] is None or end_y > s["to"]):
                s["to"] = end_y

    by_player: dict[str, dict[str, dict]] = defaultdict(dict)
    for (q, club), s in stints.items():
        by_player[q][club] = s

    pairs = {}
    for q, cl in by_player.items():
        if len(cl) < 2:
            continue
        for a, b in itertools.combinations(sorted(cl), 2):
            entry = pairs.setdefault((a, b), {"verified": [], "unverified": []})
            both = cl[a]["verified"] and cl[b]["verified"]
            entry["verified" if both else "unverified"].append(q)

    out = ROOT / "out"
    out.mkdir(exist_ok=True)
    pool = {k: v for k, v in pairs.items() if v["verified"]}

    def fame_sorted(qs):
        return sorted(qs, key=lambda q: -players[q]["fame"])

    pair_rows = []
    for (a, b), v in sorted(pool.items()):
        answers = fame_sorted(v["verified"])
        top = players[answers[0]]["fame"]
        pair_rows.append({
            "a": a, "b": b, "answers": answers,
            "unverified": fame_sorted(v["unverified"]),
            "top_fame": top, "count": len(answers),
        })

    player_rows = []
    for q, p in players.items():
        if q not in by_player:
            continue
        player_rows.append({
            "qid": q, "name": p["name"], "name_en": p["name_en"],
            "aliases": sorted(p["aliases"]), "birth": p["birth"], "fame": p["fame"],
            "norm": norm(p["name"]), "key": key(p["name"]),
        })

    (out / "players.json").write_text(json.dumps(player_rows, ensure_ascii=False), encoding="utf-8")
    (out / "stints.json").write_text(json.dumps(
        [{"qid": q, "club": c, **s} for (q, c), s in stints.items()], ensure_ascii=False), encoding="utf-8")
    (out / "pairs.json").write_text(json.dumps(pair_rows, ensure_ascii=False), encoding="utf-8")

    names = {c["code"]: c["name_tr"] for c in clubs}
    total_pairs = len(clubs) * (len(clubs) - 1) // 2
    ver = sum(1 for s in stints.values() if s["verified"])
    lines = [
        f"kulüp: {len(clubs)}",
        f"futbolcu (en az 1 dönem): {len(player_rows)}",
        f"kariyer kaydı: {len(stints)} (maç sayısı doğrulanmış: {ver}, %{100 * ver // max(1, len(stints))})",
        f"olası kulüp çifti: {total_pairs}",
        f"havuza giren çift (>=1 doğrulanmış ortak futbolcu): {len(pair_rows)}",
        f"  >=3 ortak futbolcu: {sum(1 for p in pair_rows if p['count'] >= 3)}",
        f"  en ünlü cevap 50+ dilde Wikipedia: {sum(1 for p in pair_rows if p['top_fame'] >= 50)}",
        "",
        "Örnek çiftler:",
    ]
    samples = [("gs", "fb"), ("fb", "realmadrid"), ("bjk", "gs"), ("bjk", "ts"),
               ("barcelona", "realmadrid"), ("gs", "inter"), ("juventus", "milan")]
    for a, b in samples:
        a, b = sorted((a, b))
        p = pool.get((a, b))
        if not p:
            lines.append(f"  {names[a]} + {names[b]}: havuzda yok")
            continue
        top = ", ".join(players[q]["name"] for q in fame_sorted(p["verified"])[:8])
        lines.append(f"  {names[a]} + {names[b]}: {len(p['verified'])} doğrulanmış "
                     f"(+{len(p['unverified'])} doğrulanmamış) -> {top}")
    (out / "report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
